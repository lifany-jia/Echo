import Foundation

/// 能量趋势：只有持续一段时间的上升 / 下降才算有效手势，单帧抖动不算。
enum EnergyTrend: String, Equatable {
    case rising
    case falling
    case stable
}

/// Onset 的即时形态：单次 / 短窗内的连续簇。
enum OnsetKind: String, Equatable {
    case none
    case isolated
    case cluster
}

/// 节奏形态：基于 inter-onset interval 的轻量分类，不做 BPM / beat tracking。
enum RhythmKind: String, Equatable {
    case none
    case isolated
    case regular
    case irregular
}

/// 变化度等级（供 UI 与 Wild 挑战使用）。
enum VariationLevel: String, Equatable {
    case low
    case medium
    case high
}

/// 一次耦合 tick 的声音手势汇总（UI 只读这个，不直接读 DSP）。
struct SoundGestures: Equatable {
    var energyTrend: EnergyTrend = .stable
    /// 趋势强度 0...1（用于提示文案的确定性判断）。
    var trendConfidence: Double = 0
    /// 当前是否处于停顿（低于 noise floor 且持续 >= pauseThreshold）。
    var isPaused = false
    var silenceDuration: TimeInterval = 0
    /// 突然的强声（energy 单帧跃升或 onset），区分“渐强”与“突然爆发”。
    var attack = false
    var onsetKind: OnsetKind = .none
    var rhythm: RhythmKind = .none
    var variationLevel: VariationLevel = .low
}

/// 统一声音手势分析器。
///
/// 把底层 metrics（energy / energySlope / centroid01 / variation / onset）
/// 转换成用户能理解、UI 与 Wild 挑战都能消费的声音行为。
///
/// 纯逻辑、确定性、可自测：不触碰 AVAudioEngine / AVAudioRecorder。
struct SoundGestureAnalyzer: Equatable {
    // MARK: - 阈值（与 GrowthSession / AudioAnalyzer 的尺度对齐）

    static let noiseFloor: Double = 0.06
    static let pauseThreshold: TimeInterval = 1.0
    static let trendThreshold = 0.012
    static let trendHoldTicks = 4          // ≈0.6s @ 150ms cadence
    static let attackDelta = 0.30          // 单帧能量跃升
    static let clusterWindow: TimeInterval = 0.9
    static let onsetRetention: TimeInterval = 4.0

    // MARK: - 内部状态

    private(set) var elapsed: TimeInterval = 0
    private(set) var silenceDuration: TimeInterval = 0
    private(set) var onsetTimes: [TimeInterval] = []
    private(set) var latest = SoundGestures()

    private var previousEnergy: Double = 0
    private var downTicks = 0
    private var upTicks = 0
    private var regularTicks = 0

    init() {}

    /// 每个耦合 tick 调用一次；返回本次手势汇总（同时写入 latest）。
    mutating func update(
        energy: Double,
        energySlope: Double,
        centroid01: Double,
        variation: Double,
        onsetTriggered: Bool,
        dt: TimeInterval
    ) -> SoundGestures {
        elapsed += dt
        let safeEnergy = min(max(energy.isFinite ? energy : 0, 0), 1)
        let safeSlope = energySlope.isFinite ? energySlope : 0
        let safeVariation = min(max(variation.isFinite ? variation : 0, 0), 1)

        var gestures = SoundGestures()

        // ---- 停顿 / silence（把 pause 变成一种声音手势）----
        if safeEnergy < Self.noiseFloor {
            silenceDuration += dt
        } else {
            silenceDuration = 0
        }
        gestures.isPaused = silenceDuration >= Self.pauseThreshold
        gestures.silenceDuration = silenceDuration

        // ---- 能量趋势（带持续判定，避免单帧抖动左右横跳）----
        if safeSlope <= -Self.trendThreshold {
            upTicks = 0
            downTicks += 1
        } else if safeSlope >= Self.trendThreshold {
            downTicks = 0
            upTicks += 1
        } else {
            downTicks = 0
            upTicks = 0
        }
        if downTicks >= Self.trendHoldTicks {
            gestures.energyTrend = .falling
        } else if upTicks >= Self.trendHoldTicks {
            gestures.energyTrend = .rising
        } else {
            gestures.energyTrend = .stable
        }
        gestures.trendConfidence = min(max(abs(safeSlope) / 0.08, 0), 1)

        // ---- attack：单帧能量跃升（与 OnsetDetector 互补，覆盖非 onset 的突发强声）----
        gestures.attack = onsetTriggered || (safeEnergy - previousEnergy >= Self.attackDelta)
        previousEnergy = safeEnergy

        // ---- onset 形态与节奏 ----
        if onsetTriggered {
            onsetTimes.append(elapsed)
            onsetTimes.removeAll { elapsed - $0 > Self.onsetRetention }
        }
        let recentOnsets = onsetTimes
        if recentOnsets.isEmpty {
            gestures.onsetKind = .none
            gestures.rhythm = .none
        } else {
            if recentOnsets.count >= 2,
               recentOnsets[recentOnsets.count - 1] - recentOnsets[recentOnsets.count - 2] <= Self.clusterWindow {
                gestures.onsetKind = .cluster
            } else {
                gestures.onsetKind = .isolated
            }

            if recentOnsets.count >= 3 {
                let intervals = (1..<recentOnsets.count).map {
                    recentOnsets[$0] - recentOnsets[$0 - 1]
                }
                let mean = intervals.reduce(0, +) / Double(intervals.count)
                let variance = intervals.reduce(0) { partial, value in
                    let delta = value - mean
                    return partial + delta * delta
                } / Double(intervals.count)
                let cv = mean > 0 ? sqrt(variance) / mean : .infinity
                let plausible = mean >= 0.15 && mean <= 1.5
                if plausible && cv <= 0.35 {
                    gestures.rhythm = .regular
                    regularTicks += 1
                } else {
                    gestures.rhythm = .irregular
                    regularTicks = 0
                }
            } else {
                gestures.rhythm = recentOnsets.count == 1 ? .isolated : .irregular
                regularTicks = 0
            }
        }

        // ---- 变化度等级 ----
        if safeVariation >= 0.45 {
            gestures.variationLevel = .high
        } else if safeVariation >= 0.25 {
            gestures.variationLevel = .medium
        } else {
            gestures.variationLevel = .low
        }

        latest = gestures
        return gestures
    }

    /// 连续被识别为 regular 节奏的 tick 数（供 Wild rhythm 挑战使用）。
    var regularRhythmHoldTicks: Int {
        regularTicks
    }

    mutating func reset() {
        elapsed = 0
        silenceDuration = 0
        onsetTimes = []
        previousEnergy = 0
        downTicks = 0
        upTicks = 0
        regularTicks = 0
        latest = SoundGestures()
    }
}
