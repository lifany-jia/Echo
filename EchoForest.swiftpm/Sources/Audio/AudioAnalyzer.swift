@preconcurrency import AVFoundation
import Foundation

/// Stage 3 — 分析层：AVAudioPCMBuffer → SoundFrame（即时指标）+ SoundProfile（会话累计）。
///
/// 职责边界：AudioEngineController 负责麦克风 / engine / buffer；
/// 本类只负责 DSP / metrics，不触碰 UI，也不驱动植物。
/// 只从单一音频线程（tap callback）访问，跨线程传递时由调用方锁保护，因此 @unchecked Sendable。
final class AudioAnalyzer: @unchecked Sendable {
    private let sampleRate: Double
    private let noiseFloor: Double
    private let spectral: SpectralCentroid
    private var onset = OnsetDetector()
    private(set) var profile = SoundProfile()
    private var sessionTime: TimeInterval = 0
    private var scratch: [Float] = []

    init(sampleRate: Double = 44_100, fftSize: Int = 1024, noiseFloor: Double = 0.01) {
        self.sampleRate = sampleRate
        self.noiseFloor = noiseFloor
        self.spectral = SpectralCentroid(fftSize: fftSize)
    }

    /// 处理一帧 buffer（只支持 float32）。
    /// 采样率使用 buffer 的真实 `format.sampleRate`（真机硬件常为 48kHz），
    /// 无法读取时回退到 init 时传入的 sampleRate。
    func process(buffer: AVAudioPCMBuffer) -> SoundFrame {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, buffer.format.commonFormat == .pcmFormatFloat32 else {
            return .zero
        }
        let bufferSampleRate = buffer.format.sampleRate > 0 ? buffer.format.sampleRate : sampleRate

        var samplesPointer: UnsafeMutablePointer<Float>?
        var stride = 1
        if let channel = buffer.floatChannelData?[0] {
            samplesPointer = channel
            stride = buffer.stride
        } else if let data = buffer.audioBufferList.pointee.mBuffers.mData {
            samplesPointer = data.assumingMemoryBound(to: Float.self)
            stride = buffer.stride
        }
        guard let base = samplesPointer else { return .zero }

        if stride == 1 {
            return computeFrame(samples: base, count: frameCount, sampleRate: bufferSampleRate)
        }

        // 交织/多声道：去交织到复用 scratch（一次分配，之后复用）。
        if scratch.count < frameCount {
            scratch = [Float](repeating: 0, count: frameCount)
        }
        for index in 0..<frameCount {
            scratch[index] = base[index * stride]
        }
        return scratch.withUnsafeBufferPointer { buffer in
            computeFrame(samples: buffer.baseAddress!, count: frameCount, sampleRate: bufferSampleRate)
        }
    }

    func resetSession() {
        profile = SoundProfile()
        onset.reset()
        sessionTime = 0
    }

    private func computeFrame(samples: UnsafePointer<Float>, count: Int, sampleRate: Double) -> SoundFrame {
        let rms = SoundMath.rms(samples: samples, count: count)
        let energy = SoundMath.normalizedEnergy(rms: rms, noiseFloor: noiseFloor)
        let centroid = spectral.centroidHz(samples: samples, count: count, sampleRate: sampleRate)
        let frameDuration = TimeInterval(count) / sampleRate
        sessionTime += frameDuration
        let onsetTriggered = onset.process(energy: energy, time: sessionTime)

        let frame = SoundFrame(
            rms: rms,
            energy: energy,
            spectralCentroidHz: centroid,
            onsetTriggered: onsetTriggered,
            sampleCount: count
        )
        profile.accumulate(frame: frame, frameDuration: frameDuration)
        return frame
    }
}
