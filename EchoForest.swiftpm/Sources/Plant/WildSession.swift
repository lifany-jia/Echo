import Foundation

/// Wild Mode 的初版五种声音挑战。
///
/// 这些不是“答题”：挑战只用于引导用户尝试某种声音行为；
/// 无论是否达成，树都继续按真实声音生长。
enum WildChallenge: String, Codable, Equatable, CaseIterable {
    case growLeft
    case growRight
    case growUp
    case branch
    case bloom

    var title: String {
        switch self {
        case .growLeft: return "往左！"
        case .growRight: return "往右！"
        case .growUp: return "冲上去！"
        case .branch: return "分叉！"
        case .bloom: return "开花！"
        }
    }

    var hint: String {
        switch self {
        case .growLeft: return "让声音慢慢变小"
        case .growRight: return "让声音越来越响"
        case .growUp: return "试试更明亮 / 更高的声音"
        case .branch: return "让声音变化起来"
        case .bloom: return "拍一下手，或者敲一下桌子"
        }
    }

    var successText: String {
        switch self {
        case .growLeft: return "好，它往左去了"
        case .growRight: return "好，它往右去了"
        case .growUp: return "好，它冲上去了"
        case .branch: return "好，它分叉了"
        case .bloom: return "好，它开花了"
        }
    }
}

/// 每个耦合 tick 喂给 WildSession 的平滑声音特征（与 GrowthSession 同源）。
struct WildSoundSnapshot: Equatable {
    var energySlope: Double     // recent energy slope（下降为负）
    var centroid01: Double      // 0...1，高 = 更亮 / 更高
    var variation: Double       // 0...1，高 = 变化更多
    var onsetTriggered: Bool    // 真实 onset（拍手 / 敲桌）
}

/// Wild 会话的阶段（UI 只读这个）。
enum WildPhase: Equatable {
    case opening
    case countdown(remaining: Int)
    case challenge(WildChallenge, succeeded: Bool)
    case burst
    case calm
    case done
}

/// Wild Mode 纯核心：确定性时间线 + 挑战识别 + 暴走窗口。
///
/// - 时间线固定（约 28 秒）：开场 → 3-2-1 → 5 个挑战（中间插入一次暴走）→ 冷静 → 结束。
/// - 挑战识别只用平滑后的 Energy slope / Spectral Centroid / Variation / Onset，
///   不重新实现 AudioAnalyzer。
/// - 挑战未达成不算失败：只是不显示成功，树仍然继续真实生长。
/// - 暴走窗口只放大生长表现（灵敏度 / 新枝长度 / 花朵），硬上限仍由 PlantGenerator 保证。
struct WildSession: Equatable {
    // MARK: - 时间线常量

    static let openingDuration: TimeInterval = 2
    static let countdownDuration: TimeInterval = 3
    static let challengeDuration: TimeInterval = 3.5
    static let burstDuration: TimeInterval = 4
    static let calmDuration: TimeInterval = 1.5

    static let challengeOrder: [WildChallenge] = [.growLeft, .growRight, .growUp, .branch, .bloom]

    static var totalDuration: TimeInterval {
        openingDuration + countdownDuration
            + challengeDuration * Double(challengeOrder.count)
            + burstDuration + calmDuration
    }

    /// 某个挑战窗口的开始时间（暴走插在第 4 个挑战前，因此后两个挑战被推后）。
    static func challengeStart(_ challenge: WildChallenge) -> TimeInterval {
        guard let index = challengeOrder.firstIndex(of: challenge) else { return 0 }
        let burstIndex = 3
        if index < burstIndex {
            return openingDuration + countdownDuration + challengeDuration * Double(index)
        }
        return openingDuration + countdownDuration
            + challengeDuration * Double(burstIndex)
            + burstDuration
            + challengeDuration * Double(index - burstIndex)
    }

    // MARK: - 识别阈值（平滑特征上做持续判定，避免单帧噪声抖动）

    static let slopeThreshold = 0.018
    static let slopeHoldTicks = 6          // 约 0.9s
    static let centroidThreshold01 = 0.48
    static let centroidHoldTicks = 4       // 约 0.6s
    static let variationThreshold = 0.32
    static let variationHoldTicks = 8      // 约 1.2s

    // MARK: - 暴走耦合乘数（presentation / coupling，不触碰 analyzer 阈值）

    static let burstGrowthMultiplier = 1.35
    static let burstLengthMultiplier = 1.12
    static let burstFlowerSizeMultiplier = 1.25

    // MARK: - 状态

    private(set) var elapsed: TimeInterval = 0
    private(set) var successes: [WildChallenge: Bool] = [:]
    private(set) var isBursting = false
    private(set) var isComplete = false

    private var slopeDownTicks = 0
    private var slopeUpTicks = 0
    private var centroidHighTicks = 0
    private var variationHighTicks = 0
    private var bloomSeen = false

    init() {
        for challenge in Self.challengeOrder {
            successes[challenge] = false
        }
    }

    // MARK: - 推进

    mutating func update(elapsed newElapsed: TimeInterval, snapshot: WildSoundSnapshot) {
        elapsed = min(max(newElapsed, 0), Self.totalDuration)

        let previousChallenge = currentChallenge
        if previousChallenge != currentChallenge {
            resetEvidence()
        }

        if let challenge = currentChallenge, !(successes[challenge] ?? false) {
            evaluate(challenge: challenge, snapshot: snapshot)
        }

        isBursting = elapsed >= burstStart && elapsed < burstStart + Self.burstDuration
        isComplete = elapsed >= Self.totalDuration
    }

    // MARK: - 对外只读状态

    var phase: WildPhase {
        let t = elapsed
        if isComplete {
            return .done
        }
        if t < Self.openingDuration {
            return .opening
        }
        let countdownEnd = Self.openingDuration + Self.countdownDuration
        if t < countdownEnd {
            return .countdown(remaining: max(Int(ceil(countdownEnd - t)), 1))
        }
        if t >= burstStart && t < burstStart + Self.burstDuration {
            return .burst
        }
        let calmStart = burstStart + Self.burstDuration
            + Self.challengeDuration * Double(Self.challengeOrder.count - 3)
        if t >= calmStart {
            return .calm
        }
        if let challenge = currentChallenge {
            return .challenge(challenge, succeeded: successes[challenge] ?? false)
        }
        return .opening
    }

    var currentChallenge: WildChallenge? {
        let t = elapsed
        let countdownEnd = Self.openingDuration + Self.countdownDuration
        guard t >= countdownEnd else { return nil }

        // 前三个挑战 → 暴走 → 后两个挑战 → 冷静
        let burstIndex = 3
        let firstThreeEnd = burstStart
        if t < firstThreeEnd {
            let index = min(Int((t - countdownEnd) / Self.challengeDuration), burstIndex - 1)
            return Self.challengeOrder[index]
        }
        let afterBurst = burstStart + Self.burstDuration
        let calmStart = afterBurst + Self.challengeDuration * Double(Self.challengeOrder.count - burstIndex)
        if t >= afterBurst && t < calmStart {
            let index = burstIndex + min(
                Int((t - afterBurst) / Self.challengeDuration),
                Self.challengeOrder.count - burstIndex - 1
            )
            return Self.challengeOrder[index]
        }
        return nil
    }

    /// 当前挑战是否已成功（仅在挑战窗口内有意义）。
    var currentChallengeSucceeded: Bool {
        guard let challenge = currentChallenge else { return false }
        return successes[challenge] ?? false
    }

    var countdownRemaining: Int {
        if case .countdown(let remaining) = phase {
            return remaining
        }
        return 0
    }

    var progress: Double {
        min(max(elapsed / Self.totalDuration, 0), 1)
    }

    // MARK: - 暴走乘数

    var growthMultiplier: Double {
        isBursting ? Self.burstGrowthMultiplier : 1
    }

    var lengthMultiplier: Double {
        isBursting ? Self.burstLengthMultiplier : 1
    }

    var flowerSizeMultiplier: Double {
        isBursting ? Self.burstFlowerSizeMultiplier : 1
    }

    // MARK: - 时间线内部计算

    private var burstStart: TimeInterval {
        Self.openingDuration + Self.countdownDuration + Self.challengeDuration * 3
    }

    // MARK: - 识别

    private mutating func evaluate(challenge: WildChallenge, snapshot: WildSoundSnapshot) {
        switch challenge {
        case .growLeft:
            slopeDownTicks = snapshot.energySlope <= -Self.slopeThreshold ? slopeDownTicks + 1 : 0
            if slopeDownTicks >= Self.slopeHoldTicks {
                successes[challenge] = true
            }
        case .growRight:
            slopeUpTicks = snapshot.energySlope >= Self.slopeThreshold ? slopeUpTicks + 1 : 0
            if slopeUpTicks >= Self.slopeHoldTicks {
                successes[challenge] = true
            }
        case .growUp:
            centroidHighTicks = snapshot.centroid01 >= Self.centroidThreshold01 ? centroidHighTicks + 1 : 0
            if centroidHighTicks >= Self.centroidHoldTicks {
                successes[challenge] = true
            }
        case .branch:
            variationHighTicks = snapshot.variation >= Self.variationThreshold ? variationHighTicks + 1 : 0
            if variationHighTicks >= Self.variationHoldTicks {
                successes[challenge] = true
            }
        case .bloom:
            if snapshot.onsetTriggered {
                bloomSeen = true
                successes[challenge] = true
            }
        }
    }

    private mutating func resetEvidence() {
        slopeDownTicks = 0
        slopeUpTicks = 0
        centroidHighTicks = 0
        variationHighTicks = 0
        bloomSeen = false
    }
}
