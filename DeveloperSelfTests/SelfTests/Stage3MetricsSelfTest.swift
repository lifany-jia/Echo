import Foundation

@main
struct Stage3MetricsSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        func close(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
            abs(lhs - rhs) <= tolerance
        }

        let noiseFloor = 0.01

        // ---- Energy / RMS ----
        // 全 0 samples：RMS 与 Energy 都为 0
        let silence = [Float](repeating: 0, count: 1024)
        let silenceRMS = SoundMath.rms(silence)
        expect(close(silenceRMS, 0), "silence RMS should be 0")
        expect(close(SoundMath.normalizedEnergy(rms: silenceRMS, noiseFloor: noiseFloor), 0), "silence energy should be 0")

        // 固定幅值 0.5：RMS 精确等于幅值；Energy 与公式一致
        let half = [Float](repeating: 0.5, count: 1024)
        let halfRMS = SoundMath.rms(half)
        expect(close(halfRMS, 0.5, tolerance: 1e-6), "fixed amplitude 0.5 RMS should be 0.5")
        let halfEnergy = SoundMath.normalizedEnergy(rms: halfRMS, noiseFloor: noiseFloor)
        let expectedHalfEnergy = sqrt((0.5 - noiseFloor) / (1 - noiseFloor))
        expect(close(halfEnergy, expectedHalfEnergy), "fixed amplitude energy should match documented formula")

        // 小幅值（低于 noise floor）：能量为 0
        let low = [Float](repeating: 0.005, count: 1024)
        let lowRMS = SoundMath.rms(low)
        expect(close(lowRMS, 0.005, tolerance: 1e-6), "low amplitude RMS should be 0.005")
        expect(close(SoundMath.normalizedEnergy(rms: lowRMS, noiseFloor: noiseFloor), 0), "below noise floor energy should be 0")

        // 大幅值 0.9：能量 > 中等幅值且保持在 [0,1]
        let high = [Float](repeating: 0.9, count: 1024)
        let highRMS = SoundMath.rms(high)
        expect(close(highRMS, 0.9, tolerance: 1e-6), "high amplitude RMS should be 0.9")
        let highEnergy = SoundMath.normalizedEnergy(rms: highRMS, noiseFloor: noiseFloor)
        expect(highEnergy >= 0 && highEnergy <= 1, "high energy should stay in [0,1]")
        expect(highEnergy > halfEnergy, "energy should increase with amplitude")

        // clamp：超过满幅的样本最终能量仍为 1
        let overRange = [Float](repeating: 2.0, count: 1024)
        let overEnergy = SoundMath.normalizedEnergy(rms: SoundMath.rms(overRange), noiseFloor: noiseFloor)
        expect(close(overEnergy, 1), "over-range amplitude should clamp to 1")

        // 非法样本：NaN / infinity 不传播，RMS 跳过它们
        var invalid = [Float](repeating: 0.3, count: 1024)
        invalid[0] = .nan
        invalid[10] = .infinity
        let invalidRMS = SoundMath.rms(invalid)
        expect(invalidRMS.isFinite, "RMS with invalid samples should stay finite")
        expect(close(invalidRMS, 0.3, tolerance: 1e-6), "RMS should skip invalid samples")

        let allInvalid = [Float](repeating: .nan, count: 64)
        expect(close(SoundMath.rms(allInvalid), 0), "all-invalid RMS should be 0")

        // 空 buffer
        expect(close(SoundMath.rms([]), 0), "empty buffer RMS should be 0")

        // 稳定性：输出有限、energy 合法
        let outputs = [silenceRMS, halfEnergy, lowRMS, highEnergy, overEnergy, invalidRMS]
        expect(outputs.allSatisfy(\.isFinite), "all metric outputs should be finite")

        // ---- Frequency Proxy (Spectral Centroid) ----
        let fftSize = 1024
        let sampleRate = 44_100.0
        let spectral = SpectralCentroid(fftSize: fftSize)

        func makeSine(frequency: Double, amplitude: Float = 0.8) -> [Float] {
            var samples = [Float](repeating: 0, count: fftSize)
            for index in 0..<fftSize {
                let phase = 2 * Double.pi * frequency * Double(index) / sampleRate
                let value = sin(phase)
                samples[index] = Float(amplitude) * Float(value)
            }
            return samples
        }

        // 使用 bin 对齐频率（k * sampleRate / fftSize），DFT 结果集中到单一 bin，重心应精确等于目标频率。
        let lowFrequency = 5.0 * sampleRate / Double(fftSize)   // 215.33 Hz
        let midFrequency = 20.0 * sampleRate / Double(fftSize)  // 861.33 Hz
        let highFrequency = 40.0 * sampleRate / Double(fftSize) // 1722.66 Hz

        func centroid(of samples: [Float]) -> Double? {
            samples.withUnsafeBufferPointer { buffer in
                spectral.centroidHz(samples: buffer.baseAddress!, count: buffer.count, sampleRate: sampleRate)
            }
        }

        let lowCentroid = centroid(of: makeSine(frequency: lowFrequency))
        let midCentroid = centroid(of: makeSine(frequency: midFrequency))
        let highCentroid = centroid(of: makeSine(frequency: highFrequency))

        expect(lowCentroid != nil, "low sine should produce a centroid")
        expect(midCentroid != nil, "mid sine should produce a centroid")
        expect(highCentroid != nil, "high sine should produce a centroid")

        if let value = lowCentroid {
            expect(abs(value - lowFrequency) < 2, "low sine centroid should match target (got \(value))")
        }
        if let value = midCentroid {
            expect(abs(value - midFrequency) < 2, "mid sine centroid should match target (got \(value))")
        }
        if let value = highCentroid {
            expect(abs(value - highFrequency) < 2, "high sine centroid should match target (got \(value))")
        }

        let centroidValues = [lowCentroid, midCentroid, highCentroid].compactMap { $0 }
        if centroidValues.count == 3 {
            expect(centroidValues[1] > centroidValues[0], "mid should be clearly above low")
            expect(centroidValues[2] > centroidValues[1], "high should be clearly above mid")
            expect(centroidValues.allSatisfy(\.isFinite), "centroid values should be finite")
        }

        let silentSamples = [Float](repeating: 0, count: fftSize)
        expect(centroid(of: silentSamples) == nil, "silence should produce no centroid")

        // ---- Onset ----
        // silence -> silence：不触发
        var silenceOnset = OnsetDetector(energyThreshold: 0.35, jumpThreshold: 0.3, cooldown: 0.3)
        var silenceTriggered = false
        var silenceTime = 0.0
        while silenceTime <= 2.0 {
            if silenceOnset.process(energy: 0, time: silenceTime) {
                silenceTriggered = true
            }
            silenceTime += 0.1
        }
        expect(!silenceTriggered, "silence should never trigger onset")

        // steady tone：只在声音开始时触发一次，不持续乱触发
        var steady = OnsetDetector(energyThreshold: 0.35, jumpThreshold: 0.3, cooldown: 0.3)
        let steadyEnergies: [Double] = [0.0, 0.7, 0.7, 0.7, 0.7]
        let steadyTimes: [Double] = [0.0, 0.1, 0.2, 0.3, 0.4]
        var steadyCount = 0
        for (time, energy) in zip(steadyTimes, steadyEnergies) {
            if steady.process(energy: energy, time: time) {
                steadyCount += 1
            }
        }
        expect(steadyCount == 1, "steady tone should trigger once, not repeatedly")

        // silence -> strong transient：触发一次
        var transient = OnsetDetector(energyThreshold: 0.35, jumpThreshold: 0.3, cooldown: 0.3)
        let transientEnergies: [Double] = [0.0, 0.0, 0.9]
        let transientTimes: [Double] = [0.0, 1.0, 2.0]
        var transientCount = 0
        for (time, energy) in zip(transientTimes, transientEnergies) {
            if transient.process(energy: energy, time: time) {
                transientCount += 1
            }
        }
        expect(transientCount == 1, "silence to strong transient should trigger once")

        // cooldown 内重复峰值：不重复触发
        var cooldownDetector = OnsetDetector(energyThreshold: 0.35, jumpThreshold: 0.3, cooldown: 0.3)
        let cooldownEnergies: [Double] = [0.0, 0.9, 0.1, 0.95]
        let cooldownTimes: [Double] = [0.0, 1.0, 1.1, 1.2]
        var cooldownCount = 0
        for (time, energy) in zip(cooldownTimes, cooldownEnergies) {
            if cooldownDetector.process(energy: energy, time: time) {
                cooldownCount += 1
            }
        }
        expect(cooldownCount == 1, "peak inside cooldown should not retrigger")

        // cooldown 结束后新的峰值：可再次触发
        var cooldownPassed = OnsetDetector(energyThreshold: 0.35, jumpThreshold: 0.3, cooldown: 0.3)
        let passedEnergies: [Double] = [0.0, 0.9, 0.1, 0.95]
        let passedTimes: [Double] = [0.0, 1.0, 1.1, 1.6]
        var passedCount = 0
        for (time, energy) in zip(passedTimes, passedEnergies) {
            if cooldownPassed.process(energy: energy, time: time) {
                passedCount += 1
            }
        }
        expect(passedCount == 2, "peak after cooldown should trigger again")

        // ---- Session profile 累计 ----
        var profile = SoundProfile()
        profile.accumulate(
            frame: SoundFrame(rms: 0.1, energy: 0.2, spectralCentroidHz: 500, onsetTriggered: true, sampleCount: 1024),
            frameDuration: 0.0232
        )
        profile.accumulate(
            frame: SoundFrame(rms: 0.1, energy: 0.4, spectralCentroidHz: 600, onsetTriggered: false, sampleCount: 1024),
            frameDuration: 0.0232
        )
        expect(close(profile.energy, 0.3), "profile mean energy should average frames")
        expect(close(profile.peakEnergy, 0.4), "profile peak energy should track max")
        expect(profile.onsetCount == 1, "profile should accumulate onset count")
        expect(close(profile.duration, 0.0464), "profile should accumulate duration")
        if let centroid = profile.spectralCentroidHz {
            expect(close(centroid, 550), "profile should average spectral centroid")
        } else {
            expect(false, "profile should keep spectral centroid")
        }
        expect(profile.variation >= 0 && profile.variation <= 1, "profile variation should stay in [0,1]")

        if failures.isEmpty {
            print("Stage 3 metrics self-test PASS")
        } else {
            print("Stage 3 metrics self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
