import Foundation

/// Wild Mode 的声音挑战。
///
/// 这些不是“答题 / 关卡”：每次挑战只诱导用户尝试一种声音行为；
/// 无论是否达成，树都继续按真实声音生长。不显示 Wrong / Failed。
enum WildChallenge: String, Codable, Equatable, CaseIterable {
    case silence
    case louder
    case softer
    case high
    case chaos
    case bloom
    case rhythm

    /// 挑战出现前的一句话（诱导 / 铺垫）。
    var prompt: String {
        switch self {
        case .silence: return "嘘……"
        case .louder: return "它不服你。"
        case .softer: return "别把它吓跑。"
        case .high: return "让它冲上去！"
        case .chaos: return "它开始学你了。"
        case .bloom: return "它不开花。"
        case .rhythm: return "给它一点节奏。"
        }
    }

    var title: String {
        switch self {
        case .silence: return "🤫 别出声。"
        case .louder: return "凶它。"
        case .softer: return "慢慢小声一点……"
        case .high: return "试试更明亮的声音"
        case .chaos: return "来点奇怪的。"
        case .bloom: return "敲一下桌子催它。"
        case .rhythm: return "啪 · 啪 · 啪 · 啪"
        }
    }

    var hint: String {
        switch self {
        case .silence: return "保持安静，它会冻住"
        case .louder: return "越来越大声"
        case .softer: return "越来越轻，不要吓到它"
        case .high: return "声音越高，它越往上"
        case .chaos: return "呜↗啊↘，怎么怪怎么来"
        case .bloom: return "拍手，或者敲一下桌子"
        case .rhythm: return "跟着节拍来"
        }
    }

    var successText: String {
        switch self {
        case .silence: return "好，它安静下来了"
        case .louder: return "好，它服了"
        case .softer: return "好，它松下来了"
        case .high: return "好，它冲上去了"
        case .chaos: return "好，它疯了"
        case .bloom: return "好，满树都是"
        case .rhythm: return "好，花跟着节拍开了"
        }
    }
}

/// 每个耦合 tick 喂给 WildSession 的平滑声音特征（与 GrowthSession / SoundGestureAnalyzer 同源）。
struct WildSoundSnapshot: Equatable {
    var energySlope: Double     // recent energy slope（下降为负）
    var centroid01: Double      // 0...1，高 = 更亮 / 更高
    var variation: Double       // 0...1，高 = 变化更多
    var onsetTriggered: Bool    // 真实 onset（拍手 / 敲桌）
    var energy: Double = 0      // 平滑能量，用于 silence / louder / softer 判定
    var silenceDuration: TimeInterval = 0
    var rhythm: RhythmKind = .none
    var onsetKind: OnsetKind = .none
}

/// Wild 会话的阶段（UI 只读这个）。
enum WildPhase: Equatable {
    case opening
    case countdown(remaining: Int)
    case jerk
    case challenge(WildChallenge, succeeded: Bool)
    case freeForAll
    case ending
    case done
}

/// Wild Mode 纯核心：确定性时间线 + 挑战识别 + Free For All 高潮。
///
/// 时间线（约 36 秒，6 个挑战）：
/// 开场（别吵醒它）→ 3-2-1 倒计时 → 种子抽动（糟了）→
/// 4–6 个挑战（silence / louder / softer / high / chaos / bloom / rhythm）→
/// Free For All（随便来点什么！！）→ 结尾（确实很像你）→ 结束。
///
/// - 挑战顺序：默认按 seed 确定性洗牌（4–6 个）；测试 / 运行时脚本可显式传入固定序列。
/// - 识别只用现有平滑特征 + SoundGestureAnalyzer 的手势结果，不重新实现 DSP。
/// - 挑战未达成不算失败：只是不显示成功，树仍继续真实生长。
/// - Free For All 只放大生长表现（灵敏度 / 新枝长度 / 花朵），硬上限仍由 PlantGenerator 保证。
struct WildSession: Equatable {
    // MARK: - 时间线常量

    static let openingDuration: TimeInterval = 2.5
    static let countdownDuration: TimeInterval = 3.0
    static let jerkDuration: TimeInterval = 0.8
    static let challengeDuration: TimeInterval = 3.5
    static let freeForAllDuration: TimeInterval = 8.0
    static let endingDuration: TimeInterval = 1.2
    static let defaultChallengeCount = 6
    static let defaultSeed: UInt64 = 0xEC0_0000_0000_00A7

    static func totalDuration(for challengeCount: Int) -> TimeInterval {
        openingDuration + countdownDuration + jerkDuration
            + challengeDuration * Double(challengeCount)
            + freeForAllDuration + endingDuration
    }

    /// 按 seed 确定性洗牌选出 4–6 个挑战（默认 6 个；每场不要求全部出现）。
    static func challengeSequence(seed: UInt64, count: Int = defaultChallengeCount) -> [WildChallenge] {
        var rng = SeededRandom(seed: seed &+ 0x51C7_0000_0000_0001)
        let count = min(max(count, 4), 6)
        var pool = WildChallenge.allCases
        var result: [WildChallenge] = []
        while result.count < count, !pool.isEmpty {
            let index = Int(rng.double01() * Double(pool.count))
            result.append(pool.remove(at: min(max(index, 0), pool.count - 1)))
        }
        return result
    }

    // MARK: - 识别阈值

    static let slopeThreshold = 0.018
    static let slopeHoldTicks = 5          // ≈0.75s
    static let centroidThreshold01 = 0.48
    static let centroidHoldTicks = 4       // ≈0.6s
    static let variationThreshold = 0.32
    static let variationHoldTicks = 7      // ≈1.05s
    static let silenceHoldDuration: TimeInterval = 1.0
    static let rhythmHoldTicks = 4         // ≈0.6s

    // MARK: - Free For All 耦合乘数

    static let freeForAllGrowthMultiplier = 1.35
    static let freeForAllLengthMultiplier = 1.12
    static let freeForAllFlowerSizeMultiplier = 1.25

    // MARK: - 状态

    let challenges: [WildChallenge]
    private(set) var elapsed: TimeInterval = 0
    private(set) var successes: [WildChallenge: Bool] = [:]
    private(set) var isFreeForAll = false
    private(set) var isComplete = false
    /// silence 挑战中用户没忍住出了声（有趣反馈，不算失败）。
    private(set) var silenceCaught = false
    /// bloom 挑战进度：0 = 未开花，1 = 第一朵（“就这？”），2 = 花簇（成功）。
    private(set) var bloomStage = 0

    private var downTicks = 0
    private var upTicks = 0
    private var centroidHighTicks = 0
    private var variationHighTicks = 0
    private var silenceTicks = 0
    private var rhythmTicks = 0
    private var activeChallengeIndex: Int?

    /// 本次会话实际总时长（取决于挑战数量）。
    var totalDuration: TimeInterval {
        Self.totalDuration(for: challenges.count)
    }

    init(seed: UInt64 = defaultSeed, challenges: [WildChallenge]? = nil) {
        if let challenges {
            self.challenges = Array(challenges.prefix(6))
        } else {
            self.challenges = Self.challengeSequence(seed: seed)
        }
        for challenge in self.challenges {
            successes[challenge] = false
        }
    }

    // MARK: - 推进

    mutating func update(elapsed newElapsed: TimeInterval, snapshot: WildSoundSnapshot) {
        elapsed = min(max(newElapsed, 0), totalDuration)

        let index = currentChallengeIndex
        if index != activeChallengeIndex {
            resetEvidence()
            activeChallengeIndex = index
        }

        if let challenge = currentChallenge, !(successes[challenge] ?? false) {
            evaluate(challenge: challenge, snapshot: snapshot)
        }

        isFreeForAll = elapsed >= freeForAllStart && elapsed < freeForAllStart + Self.freeForAllDuration
        isComplete = elapsed >= totalDuration
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
        let jerkEnd = countdownEnd + Self.jerkDuration
        if t < jerkEnd {
            return .jerk
        }
        let freeAllStart = challengeStart + Self.challengeDuration * Double(challenges.count)
        if t < freeAllStart {
            if let challenge = currentChallenge {
                return .challenge(challenge, succeeded: successes[challenge] ?? false)
            }
            return .jerk
        }
        let endingStart = freeAllStart + Self.freeForAllDuration
        if t < endingStart {
            return .freeForAll
        }
        return .ending
    }

    var currentChallenge: WildChallenge? {
        guard let index = currentChallengeIndex, challenges.indices.contains(index) else { return nil }
        return challenges[index]
    }

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
        min(max(elapsed / totalDuration, 0), 1)
    }

    /// 挑战序号（0 基），供 UI 显示“第 2 / 6 个声音动作”。
    var challengeOrdinal: Int {
        (currentChallengeIndex ?? 0) + 1
    }

    var challengeTotal: Int {
        challenges.count
    }

    /// Free For All 已进行时长（用于 UI 分段文案：先“等等……”再“随便来点什么！！”）。
    var freeForAllElapsed: TimeInterval {
        max(elapsed - freeForAllStart, 0)
    }

    var freeForAllProgress01: Double {
        min(max(freeForAllElapsed / Self.freeForAllDuration, 0), 1)
    }

    // MARK: - Free For All 乘数

    var growthMultiplier: Double {
        isFreeForAll ? Self.freeForAllGrowthMultiplier : 1
    }

    var lengthMultiplier: Double {
        isFreeForAll ? Self.freeForAllLengthMultiplier : 1
    }

    var flowerSizeMultiplier: Double {
        isFreeForAll ? Self.freeForAllFlowerSizeMultiplier : 1
    }

    // MARK: - 时间线内部计算

    private var challengeStart: TimeInterval {
        Self.openingDuration + Self.countdownDuration + Self.jerkDuration
    }

    private var freeForAllStart: TimeInterval {
        challengeStart + Self.challengeDuration * Double(challenges.count)
    }

    private var currentChallengeIndex: Int? {
        let t = elapsed
        guard t >= challengeStart, !challenges.isEmpty else { return nil }
        let freeAllStart = challengeStart + Self.challengeDuration * Double(challenges.count)
        guard t < freeAllStart else { return nil }
        return min(Int((t - challengeStart) / Self.challengeDuration), challenges.count - 1)
    }

    // MARK: - 识别

    private mutating func evaluate(challenge: WildChallenge, snapshot: WildSoundSnapshot) {
        switch challenge {
        case .silence:
            if snapshot.energy >= 0.06 {
                silenceCaught = true
                silenceTicks = 0
            } else if snapshot.silenceDuration >= Self.silenceHoldDuration {
                silenceTicks += 1
                if silenceTicks >= 2 {
                    successes[challenge] = true
                }
            } else {
                silenceTicks = 0
            }
        case .louder:
            upTicks = snapshot.energySlope >= Self.slopeThreshold ? upTicks + 1 : 0
            if upTicks >= Self.slopeHoldTicks {
                successes[challenge] = true
            }
        case .softer:
            downTicks = snapshot.energySlope <= -Self.slopeThreshold ? downTicks + 1 : 0
            if downTicks >= Self.slopeHoldTicks {
                successes[challenge] = true
            }
        case .high:
            centroidHighTicks = snapshot.centroid01 >= Self.centroidThreshold01 ? centroidHighTicks + 1 : 0
            if centroidHighTicks >= Self.centroidHoldTicks {
                successes[challenge] = true
            }
        case .chaos:
            variationHighTicks = snapshot.variation >= Self.variationThreshold ? variationHighTicks + 1 : 0
            if variationHighTicks >= Self.variationHoldTicks {
                successes[challenge] = true
            }
        case .bloom:
            if snapshot.onsetTriggered || snapshot.onsetKind != .none {
                // 第一朵：“就这？”，第二次机会形成花簇 → 成功。
                bloomStage = min(bloomStage + 1, 2)
                if bloomStage >= 2 {
                    successes[challenge] = true
                }
            }
        case .rhythm:
            rhythmTicks = snapshot.rhythm == .regular ? rhythmTicks + 1 : 0
            if rhythmTicks >= Self.rhythmHoldTicks {
                successes[challenge] = true
            }
        }
    }

    private mutating func resetEvidence() {
        downTicks = 0
        upTicks = 0
        centroidHighTicks = 0
        variationHighTicks = 0
        silenceTicks = 0
        rhythmTicks = 0
    }
}
