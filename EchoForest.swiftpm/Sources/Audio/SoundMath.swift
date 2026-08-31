import Foundation

/// 纯 DSP 数学层，独立于 AVFoundation，可被确定性自测直接编译。
enum SoundMath {
    /// 在有限样本上计算 RMS；跳过 NaN / infinity，空或全非法返回 0。
    static func rms(samples: UnsafePointer<Float>, count: Int, stride: Int = 1) -> Double {
        guard count > 0, stride > 0 else { return 0 }
        var sumSquares = 0.0
        var validCount = 0
        for index in 0..<count {
            let value = Double(samples[index * stride])
            guard value.isFinite else { continue }
            sumSquares += value * value
            validCount += 1
        }
        guard validCount > 0 else { return 0 }
        return sqrt(sumSquares / Double(validCount))
    }

    static func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return samples.withUnsafeBufferPointer { buffer in
            rms(samples: buffer.baseAddress!, count: buffer.count)
        }
    }

    /// 把 RMS 映射到 normalized 0...1：
    /// - 低于 noiseFloor 视为 0（静音 / 环境底噪不产生能量）
    /// - 满幅（1.0）映射为 1
    /// - sqrt 塑形，增强弱信号的可感知差异
    static func normalizedEnergy(rms: Double, noiseFloor: Double) -> Double {
        let floor = clamp01(noiseFloor)
        guard rms.isFinite, rms > floor else { return 0 }
        let ratio = (rms - floor) / max(1 - floor, 1e-9)
        return clamp01(sqrt(ratio))
    }

    static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
