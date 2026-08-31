import Accelerate
import Foundation

/// 频域重心（Spectral Centroid）——Stage 3 选择的频率代理指标。
///
/// 决策：不实现高成本 / 不稳定的 pitch detector，改用频域重心作为
/// “频率代理（Frequency Proxy）”。代码与 UI 中一律叫 Spectral Centroid / 频域重心，
/// 不冒充 Pitch。
///
/// 用 vDSP_DFT 做 forward FFT，对 0...N/2 的幅度谱按频率加权求重心：
/// centroid = Σ(f_k * mag_k) / Σ(mag_k)，跳过 DC 避免低频偏置。
/// 所有工作缓冲在 init 时一次性分配，process 期间零分配。
/// 所有工作缓冲都在 init 分配、process 期间零分配；且只从单一音频线程访问，
/// 因此对 Sendable 使用 @unchecked 是安全且诚实的。
final class SpectralCentroid: @unchecked Sendable {
    /// vDSP 头文件定义 vDSP_DFT_FORWARD = +1，但 Swift 未导入 case 名，用 rawValue 构造。
    private static let forwardDirection = vDSP_DFT_Direction(rawValue: 1)!

    private let fftSize: Int
    private let setup: vDSP_DFT_Setup?
    private var realInput: [Float]
    private var imagInput: [Float]
    private var realOutput: [Float]
    private var imagOutput: [Float]

    init(fftSize: Int) {
        precondition(fftSize >= 8 && fftSize & (fftSize - 1) == 0, "fftSize must be power of two")
        self.fftSize = fftSize
        self.setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), Self.forwardDirection)
        realInput = [Float](repeating: 0, count: fftSize)
        imagInput = [Float](repeating: 0, count: fftSize)
        realOutput = [Float](repeating: 0, count: fftSize)
        imagOutput = [Float](repeating: 0, count: fftSize)
    }

    /// 样本不足 FFT 长度时零填充；静音 / 全零谱 / setup 不可用返回 nil。
    func centroidHz(samples: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Double? {
        guard let setup, fftSize > 0, sampleRate > 0, sampleRate.isFinite else { return nil }

        for index in 0..<fftSize {
            realInput[index] = index < count ? Float(samples[index]) : 0
            imagInput[index] = 0
        }

        vDSP_DFT_Execute(setup, realInput, imagInput, &realOutput, &imagOutput)

        var numerator = 0.0
        var denominator = 0.0
        let binWidth = sampleRate / Double(fftSize)

        // 跳过 DC（bin 0），避免低频偏置；只取 0...N/2 半谱。
        for bin in 1...(fftSize / 2) {
            let real = Double(realOutput[bin])
            let imag = Double(imagOutput[bin])
            let magnitude = real * real + imag * imag
            numerator += Double(bin) * binWidth * magnitude
            denominator += magnitude
        }

        guard denominator > 1e-12 else { return nil }
        let centroid = numerator / denominator
        return centroid.isFinite ? centroid : nil
    }
}
