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
/// - onset：每帧 onsetTriggered 追加一朵花（analyzer 已有 cooldown，避免一次 transient 多朵）
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

    init(
        profile: SoundProfile,
        seed: UInt64,
        name: String,
        maxSteps: Int = 16,
        activationThreshold: Double = 0.06,
        stepEnergyThreshold: Double = 0.55,
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
    mutating func update(frame: SoundFrame, sessionProfile: SoundProfile, dt: TimeInterval) {
        // Result 需要真实会话 summary：每 tick 把会话 profile 同步进植物。
        plant.profile = sessionProfile

        smoothedEnergy = lerp(smoothedEnergy, frame.energy, smoothingFactor)
        if let centroid = frame.spectralCentroidHz {
            smoothedCentroid01 = lerp(smoothedCentroid01, PlantGenerator.normalizedCentroid01(centroid), smoothingFactor)
        }
        smoothedVariation = lerp(smoothedVariation, min(max(sessionProfile.variation, 0), 1), smoothingFactor)

        let isActive = smoothedEnergy >= activationThreshold
        if isActive {
            growthAccumulator += smoothedEnergy * dt
        } else {
            // 静音时缓慢衰减已积累的成长势能，但不会凭空生长。
            growthAccumulator = max(growthAccumulator - dt * 0.4, 0)
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
    }

    private var currentParams: PlantGenerator.LiveGrowthParams {
        PlantGenerator.LiveGrowthParams(
            energy: smoothedEnergy,
            centroid01: smoothedCentroid01,
            variation: smoothedVariation
        )
    }

    private func lerp(_ from: Double, _ to: Double, _ factor: Double) -> Double {
        from + (to - from) * factor
    }
}
