import Foundation

/// Stage 5 — 实时耦合的纯核心：SoundFrame 序列 → 逐步生长的 PlantModel。
///
/// 与 LiveGrowthController（@MainActor / @Observable 包装）分离，
/// 使“录音回放式”确定性自测可以零依赖编译运行。
///
/// 规则：
/// - 平滑（EMA）：Energy / Centroid / Variation
/// - activity gate：平滑能量低于 activationThreshold 时不推进结构
/// - 生长预算：growthAccumulator 随 energy·dt 累积，跨过 stepEnergyThreshold 才长一步（上限 maxSteps）
/// - energy slope：最近窗口下降向左，最近窗口上升向右
/// - onset：每帧 onsetTriggered 在末梢追加花/花簇（analyzer 已有 cooldown，避免一次 transient 爆量）
struct GrowthSession: Equatable {
    private(set) var plant: PlantModel
    private(set) var growthState: GrowthState
    private(set) var smoothedEnergy: Double
    private(set) var smoothedCentroid01: Double
    private(set) var smoothedVariation: Double

    private let seed: UInt64
    private let maxSteps: Int
    private let activationThreshold: Double
    private let stepEnergyThreshold: Double
    private let smoothingFactor: Double
    private var growthAccumulator: Double = 0
    private var stepIndex = 0
    private var onsetEventCount = 0
    private var recentEnergies: [Double] = []
    private var lengthMultiplierValue: Double = 1
    private var flowerSizeMultiplierValue: Double = 1

    init(
        profile: SoundProfile,
        seed: UInt64,
        name: String,
        maxSteps: Int = PlantGenerator.maxBranchCount,
        activationThreshold: Double = 0.06,
        stepEnergyThreshold: Double = 0.25,
        smoothingFactor: Double = 0.35
    ) {
        self.seed = seed
        self.maxSteps = max(maxSteps, 1)
        self.activationThreshold = activationThreshold
        self.stepEnergyThreshold = max(stepEnergyThreshold, 0.01)
        self.smoothingFactor = min(max(smoothingFactor, 0), 1)
        smoothedEnergy = 0
        smoothedCentroid01 = 0.5
        smoothedVariation = 0.3
        plant = PlantModel(
            id: UUID(),
            name: name,
            profile: profile,
            structure: PlantGenerator.initialStructure(profile: profile, seed: seed)
        )
        growthState = GrowthState(totalSteps: self.maxSteps)
    }

    /// 每 tick 调用一次（生产环境由 LiveGrowthController 以固定 cadence 驱动）。
    mutating func update(
        frame: SoundFrame,
        sessionProfile: SoundProfile,
        dt: TimeInterval,
        growthMultiplier: Double = 1,
        lengthMultiplier: Double = 1,
        flowerSizeMultiplier: Double = 1
    ) {
        // Result 需要真实会话 summary：每 tick 把会话 profile 同步进植物。
        plant.profile = sessionProfile
        lengthMultiplierValue = min(max(lengthMultiplier, 0.5), 2.5)
        flowerSizeMultiplierValue = min(max(flowerSizeMultiplier, 0.5), 3)

        smoothedEnergy = lerp(smoothedEnergy, frame.energy, smoothingFactor)
        recentEnergies.append(frame.energy)
        if recentEnergies.count > 8 {
            recentEnergies.removeFirst(recentEnergies.count - 8)
        }
        if let centroid = frame.spectralCentroidHz {
            smoothedCentroid01 = lerp(smoothedCentroid01, PlantGenerator.normalizedCentroid01(centroid), smoothingFactor)
        }
        // 变化度同时考虑“会话整体变化”与“最近窗口的变化”，
        // 让 Wild 挑战的“让声音变化起来”能对 recent variability 做出响应。
        let targetVariation = min(max(max(sessionProfile.variation, recentVariation), 0), 1)
        smoothedVariation = lerp(smoothedVariation, targetVariation, smoothingFactor)

        let isActive = smoothedEnergy >= activationThreshold
        if isActive {
            let wildBoost = min(max(growthMultiplier, 0.5), 3)
            growthAccumulator += smoothedEnergy * dt * wildBoost
        } else {
            // 静音时缓慢衰减已积累的成长势能，但不会凭空生长。
            growthAccumulator = max(growthAccumulator - dt * 0.4, 0)
        }

        while growthAccumulator >= stepEnergyThreshold && !growthState.isComplete {
            growthAccumulator -= stepEnergyThreshold
            stepIndex += 1
            PlantGenerator.appendGrowthStep(
                to: &plant.structure,
                params: currentParams,
                seed: seed,
                stepIndex: stepIndex
            )
            growthState.advance()
        }

        if frame.onsetTriggered {
            onsetEventCount += 1
            PlantGenerator.appendFlower(
                to: &plant.structure,
                params: currentParams,
                seed: seed,
                eventIndex: onsetEventCount
            )
        }
    }

    /// Wild 挑战识别使用的平滑 recent energy slope（与生长使用同一窗口）。
    var recentEnergySlope: Double {
        energySlope
    }

    /// 最近能量窗口的标准差（约 1.2 秒窗口），用于 Wild 挑战识别与生长弯曲。
    var recentVariation: Double {
        guard recentEnergies.count >= 3 else { return 0 }
        let mean = recentEnergies.reduce(0, +) / Double(recentEnergies.count)
        let variance = recentEnergies.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(recentEnergies.count)
        return min(max(sqrt(variance), 0), 1)
    }

    private var currentParams: PlantGenerator.LiveGrowthParams {
        PlantGenerator.LiveGrowthParams(
            energy: smoothedEnergy,
            centroid01: smoothedCentroid01,
            variation: smoothedVariation,
            energySlope: energySlope,
            lengthMultiplier: lengthMultiplierValue,
            flowerSizeMultiplier: flowerSizeMultiplierValue
        )
    }

    private var energySlope: Double {
        guard let first = recentEnergies.first, let last = recentEnergies.last, recentEnergies.count >= 3 else {
            return 0
        }
        return last - first
    }

    private func lerp(_ from: Double, _ to: Double, _ factor: Double) -> Double {
        from + (to - from) * factor
    }
}
