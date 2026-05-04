import AVFoundation
import Accelerate

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var buffer: [Float] = []
    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 4096

    var onLevelUpdate: ((Float) -> Void)?

    // VAD состояние
    private var vadBuffer: [Float] = []
    private var vadSilenceCount = 0
    private var vadSpeechCount = 0
    private var vadActive = false
    private var vadCallback: (([Float]) -> Void)?

    private let vadSilenceThreshold: Float = 0.01
    private let vadSpeechChunks = 5
    private let vadSilenceChunks = 40
    private let maxRecordSec: Double = 30

    // MARK: - PTT

    func startPTT() {
        buffer = []
        startEngine { [weak self] samples in
            self?.buffer.append(contentsOf: samples)
            let level = self?.rms(samples) ?? 0
            self?.onLevelUpdate?(min(level * 10, 1.0))
        }
    }

    func stopPTT(completion: @escaping ([Float]?) -> Void) {
        stopEngine()
        onLevelUpdate?(0)
        let audio = buffer.isEmpty ? nil : buffer
        buffer = []
        completion(audio)
    }

    // MARK: - VAD

    func startVAD(onAudio: @escaping ([Float]) -> Void) {
        vadBuffer = []
        vadSilenceCount = 0
        vadSpeechCount = 0
        vadActive = false
        vadCallback = onAudio

        startEngine { [weak self] samples in
            self?.processVAD(samples: samples)
        }
    }

    func stopVAD() {
        stopEngine()
        vadBuffer = []
        vadActive = false
        onLevelUpdate?(0)
    }

    private func processVAD(samples: [Float]) {
        let level = rms(samples)
        let isSpeech = level > vadSilenceThreshold

        onLevelUpdate?(min(level * 10, 1.0))

        if !vadActive {
            if isSpeech {
                vadSpeechCount += 1
                if vadSpeechCount >= vadSpeechChunks {
                    vadActive = true
                    vadSilenceCount = 0
                }
            } else {
                vadSpeechCount = 0
            }
        } else {
            vadBuffer.append(contentsOf: samples)

            if !isSpeech {
                vadSilenceCount += 1
                if vadSilenceCount >= vadSilenceChunks {
                    flushVAD()
                }
            } else {
                vadSilenceCount = 0
            }

            let maxSamples = Int(sampleRate * maxRecordSec)
            if vadBuffer.count >= maxSamples {
                flushVAD()
            }
        }
    }

    private func flushVAD() {
        let audio = vadBuffer
        vadBuffer = []
        vadActive = false
        vadSpeechCount = 0
        vadSilenceCount = 0
        onLevelUpdate?(0)

        let minSamples = Int(sampleRate * 0.5)
        if audio.count >= minSamples {
            DispatchQueue.global(qos: .userInitiated).async {
                self.vadCallback?(audio)
            }
        }
    }

    // MARK: - Engine

    private func startEngine(onSamples: @escaping ([Float]) -> Void) {
        let engine = AVAudioEngine()
        audioEngine = engine

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: format, to: targetFormat) else { return }

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            guard let converted = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / format.sampleRate)
            ) else { return }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: converted, error: &error, withInputFrom: inputBlock)

            if error == nil, let data = converted.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
                onSamples(samples)
            }
        }

        try? engine.start()
    }

    private func stopEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    // MARK: - Util

    private func rms(_ samples: [Float]) -> Float {
        var result: Float = 0
        vDSP_rmsqv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }
}
