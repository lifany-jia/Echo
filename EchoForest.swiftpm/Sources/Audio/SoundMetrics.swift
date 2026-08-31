import Foundation

/// 当前一帧（一个 buffer）的即时声音指标。
struct SoundFrame: Equatable {
    var rms: Double
    var energy: Double               // normalized 0...1
    var spectralCentroidHz: Double?  // 频域重心代理指标；无法计算时为 nil
    var onsetTriggered: Bool
    var sampleCount: Int

    static let zero = SoundFrame(
        rms: 0,
        energy: 0,
        spectralCentroidHz: nil,
        onsetTriggered: false,
        sampleCount: 0
    )
}

/// 一次创作会话的累计声音指标（真实 Sound DNA 的数据基础）。
/// 当前 Result 展示的是确定性模拟 SoundProfile（未接真实麦克风 summary）。
struct SoundProfile: Equatable {
    var duration: TimeInterval = 0
    var energy: Double = 0                 // 平均 normalized energy（0...1）
    var peakEnergy: Double = 0
    var spectralCentroidHz: Double? = nil  // 平均频域重心
    var onsetCount: Int = 0
    var variation: Double = 0              // energy 标准差（0...1）
    private(set) var frameCount = 0

    private var energySum = 0.0
    private var energySquaredSum = 0.0
    private var centroidSum = 0.0
    private var centroidCount = 0

    /// 显式构造（供生成器 / 测试构造确定性 mock 输入；累计字段保持初始值）。
    init(
        duration: TimeInterval = 0,
        energy: Double = 0,
        peakEnergy: Double = 0,
        spectralCentroidHz: Double? = nil,
        onsetCount: Int = 0,
        variation: Double = 0
    ) {
        self.duration = duration
        self.energy = energy
        self.peakEnergy = peakEnergy
        self.spectralCentroidHz = spectralCentroidHz
        self.onsetCount = onsetCount
        self.variation = variation
    }

    mutating func accumulate(frame: SoundFrame, frameDuration: TimeInterval) {
        frameCount += 1
        duration += frameDuration
        energySum += frame.energy
        energySquaredSum += frame.energy * frame.energy
        peakEnergy = max(peakEnergy, frame.energy)

        if let centroid = frame.spectralCentroidHz {
            centroidSum += centroid
            centroidCount += 1
        }
        if frame.onsetTriggered {
            onsetCount += 1
        }

        energy = frameCount > 0 ? energySum / Double(frameCount) : 0
        let mean = energy
        let variance = frameCount > 0 ? energySquaredSum / Double(frameCount) - mean * mean : 0
        variation = min(max(sqrt(max(variance, 0)), 0), 1)
        spectralCentroidHz = centroidCount > 0 ? centroidSum / Double(centroidCount) : nil
    }
}

/// 只持久化公开的 summary 字段；私有累计字段不保存，解码后从零开始。
extension SoundProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case duration
        case energy
        case peakEnergy
        case spectralCentroidHz
        case onsetCount
        case variation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            duration: try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0,
            energy: try container.decodeIfPresent(Double.self, forKey: .energy) ?? 0,
            peakEnergy: try container.decodeIfPresent(Double.self, forKey: .peakEnergy) ?? 0,
            spectralCentroidHz: try container.decodeIfPresent(Double.self, forKey: .spectralCentroidHz),
            onsetCount: try container.decodeIfPresent(Int.self, forKey: .onsetCount) ?? 0,
            variation: try container.decodeIfPresent(Double.self, forKey: .variation) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(duration, forKey: .duration)
        try container.encode(energy, forKey: .energy)
        try container.encode(peakEnergy, forKey: .peakEnergy)
        try container.encode(spectralCentroidHz, forKey: .spectralCentroidHz)
        try container.encode(onsetCount, forKey: .onsetCount)
        try container.encode(variation, forKey: .variation)
    }
}
