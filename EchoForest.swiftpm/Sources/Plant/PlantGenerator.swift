import CoreGraphics
import Foundation

/// Stage 4 — 声音 → 植物结构的确定性生成器。
///
/// 映射规则（一句话可解释）：
/// - Energy           → 枝干粗细 / 生命力
/// - Spectral Centroid→ 生长方向 / 高度趋势 / 分支张角
/// - Variation        → 弯曲程度 / 分叉倾向
/// - Onset            → 叶片 / 花事件数量
/// - Duration         → 总体尺度 / 结构深度 / 节点预算
///
/// 随机性只来自可控 seed（SplitMix64），且只作用于角度 / 位置 / 曲线等装饰细节。
enum PlantGenerator {
    /// 实时耦合的增量生长参数（由 GrowthSession 的平滑值驱动）。
    struct LiveGrowthParams: Equatable {
        var energy: Double
        var centroid01: Double
        var variation: Double
    }

    static let maxDepth = 6
    static let maxBranchCount = 40
    static let maxLeaves = 28
    static let maxFlowers = 8
    static let maxOnsetCount = 24
    static let maxDuration: TimeInterval = 120
    static let minCentroidHz = 100.0
    static let maxCentroidHz = 4_000.0
    static let fallbackCentroidHz = 800.0

    /// Stage 4 使用的确定性 mock SoundProfile（非麦克风数据）。
    static let simulatedProfile = SoundProfile(
        duration: 8,
        energy: 0.62,
        peakEnergy: 0.7,
        spectralCentroidHz: 820,
        onsetCount: 3,
        variation: 0.55
    )

    /// 新会话的“幼苗”主干输入（尚未积累真实指标时的中性值）。
    static let seedlingProfile = SoundProfile(
        duration: 2,
        energy: 0.5,
        peakEnergy: 0.5,
        spectralCentroidHz: 800,
        onsetCount: 0,
        variation: 0.4
    )

    static func makeSimulatedPlant(index: Int) -> PlantModel {
        let safeIndex = max(index, 1)
        let seed = UInt64(0xEC0_0000) &+ UInt64(safeIndex)
        return generate(profile: simulatedProfile, seed: seed, name: "模拟植物 \(safeIndex)")
    }

    static func generate(profile: SoundProfile, seed: UInt64, name: String = "模拟植物") -> PlantModel {
        PlantModel(
            id: UUID(),
            name: name,
            profile: profile,
            structure: structure(profile: profile, seed: seed)
        )
    }

    /// 核心确定性函数：SoundProfile + seed → PlantStructure。
    static func structure(profile: SoundProfile, seed: UInt64) -> PlantStructure {
        let input = normalize(profile)
        let trunk = makeTrunk(input)
        let energy = input.energy
        let variation = input.variation
        let centroid01 = input.centroid01
        let duration01 = input.duration01
        let onsetCount = input.onsetCount
        let scale = input.scale
        let trunkThickness = input.trunkThickness
        let heightFactor = input.heightFactor

        var random = SeededRandom(seed: seed)

        // ---- 分枝 ----
        var branches: [BranchModel] = []
        var totalCurvature = 0.0
        var maxBranchThickness = trunkThickness
        var maxDepthReached = 0

        let upwardBias = 0.35 + 0.40 * centroid01
        let spread = max(1.30 - upwardBias, 0.35)
        let childCountLimit = variation < 0.34 ? 1 : (variation < 0.67 ? 2 : 3)
        // Duration → 生长深度 / 可生成节点数（受全局 maxDepth 硬上限保护）
        let durationDepth = min(2 + Int(duration01 * 4), maxDepth)

        func buildChildren(of parent: BranchModel, parentIndex: Int?, depth: Int) {
            guard depth <= durationDepth, branches.count < maxBranchCount else { return }
            let parentDirection = normalizedDirection(from: parent.start, to: parent.end)
            let parentLength = distance(parent.start, parent.end)
            for index in 0..<childCountLimit {
                guard branches.count < maxBranchCount else { return }
                let slot = Double(index) / Double(childCountLimit) - 0.5
                let jitter = (random.double01() - 0.5) * 2.0 * variation * 0.45
                let angle = slot * spread + jitter
                let childDirection = rotate(parentDirection, by: angle)
                let childLength = parentLength * (0.55 + 0.18 * random.double01())
                let start = parent.end
                let end = CGPoint(
                    x: start.x + childDirection.x * childLength,
                    y: start.y + childDirection.y * childLength
                )
                let thickness = max(parent.thickness * (0.55 + 0.20 * energy), 1.0)
                let curvature = childLength * (0.05 + 0.30 * variation) * (0.6 + 0.4 * random.double01())
                let perpendicular = CGPoint(x: -childDirection.y, y: childDirection.x)
                let curveSign: Double = random.double01() < 0.5 ? -1 : 1
                let child = BranchModel(
                    start: start,
                    end: end,
                    control: CGPoint(
                        x: (start.x + end.x) / 2 + perpendicular.x * curvature * curveSign,
                        y: (start.y + end.y) / 2 + perpendicular.y * curvature * curveSign
                    ),
                    thickness: thickness,
                    depth: depth,
                    parentIndex: parentIndex,
                    curvature: curvature
                )
                branches.append(child)
                totalCurvature += curvature
                maxBranchThickness = max(maxBranchThickness, thickness)
                maxDepthReached = max(maxDepthReached, depth)
                buildChildren(of: child, parentIndex: branches.count - 1, depth: depth + 1)
            }
        }

        buildChildren(of: trunk, parentIndex: nil, depth: 1)

        // ---- 事件节点：叶片 / 花 ----
        var tips: [BranchModel] = []
        for (index, branch) in branches.enumerated() {
            let isParent = branches.contains { $0.parentIndex == index }
            if !isParent {
                tips.append(branch)
            }
        }
        if tips.isEmpty {
            tips = branches.isEmpty ? [trunk] : [branches[branches.count - 1]]
        }

        let baseLeaves = 2 + Int(duration01 * 6)
        let leafCount = min(baseLeaves + onsetCount * 2, maxLeaves)
        let flowerCount = onsetCount == 0 ? 0 : min(1 + (onsetCount - 1) / 2, maxFlowers)

        var events: [PlantEvent] = []
        for index in 0..<leafCount {
            let tip = tips[index % tips.count]
            let position = CGPoint(
                x: tip.end.x + (random.double01() - 0.5) * 0.06,
                y: tip.end.y - 0.02 + (random.double01() - 0.5) * 0.04
            )
            let size = 0.018 + energy * 0.026
            events.append(PlantEvent(type: .leaf, position: position, size: size, depth: tip.depth + 1))
        }
        for index in 0..<flowerCount {
            let tip = tips[index % tips.count]
            let position = CGPoint(
                x: tip.end.x + (random.double01() - 0.5) * 0.04,
                y: tip.end.y - 0.04
            )
            let size = 0.028 + variation * 0.016
            events.append(PlantEvent(type: .flower, position: position, size: size, depth: tip.depth + 1))
        }

        let metadata = GenerationMetadata(
            branchCount: branches.count,
            leafCount: leafCount,
            flowerCount: flowerCount,
            maxDepth: maxDepthReached,
            trunkThickness: trunkThickness,
            height: heightFactor,
            trunkLeanX: input.trunkLeanX,
            scale: scale,
            totalCurvature: totalCurvature,
            maxBranchThickness: maxBranchThickness,
            centroidUsedHz: input.centroidHz
        )

        return PlantStructure(
            scale: scale,
            trunk: trunk,
            branches: branches,
            events: events,
            metadata: metadata
        )
    }

    /// 实时会话的初始结构：只有主干，等待真实指标逐步长出分枝。
    static func initialStructure(profile: SoundProfile, seed: UInt64) -> PlantStructure {
        let input = normalize(profile)
        let trunk = makeTrunk(input)
        let metadata = GenerationMetadata(
            branchCount: 0,
            leafCount: 0,
            flowerCount: 0,
            maxDepth: 0,
            trunkThickness: input.trunkThickness,
            height: input.heightFactor,
            trunkLeanX: input.trunkLeanX,
            scale: input.scale,
            totalCurvature: 0,
            maxBranchThickness: input.trunkThickness,
            centroidUsedHz: input.centroidHz
        )
        return PlantStructure(
            scale: input.scale,
            trunk: trunk,
            branches: [],
            events: [],
            metadata: metadata
        )
    }

    /// 把一个归一化频率值映射到 0...1（供实时 smoothing 使用）。
    static func normalizedCentroid01(_ hz: Double) -> Double {
        clamp01((sanitizedCentroid(hz) - minCentroidHz) / (maxCentroidHz - minCentroidHz))
    }

    /// 增量生长一步：在确定性 frontier 尖端追加一条新枝 + 一片叶。
    /// 新枝参数来自实时平滑值（energy→粗细、centroid01→方向、variation→弯曲）。
    static func appendGrowthStep(
        to structure: inout PlantStructure,
        params: LiveGrowthParams,
        seed: UInt64,
        stepIndex: Int
    ) {
        guard structure.branches.count < maxBranchCount else { return }

        let energy = clamp01(finite(params.energy, fallback: 0))
        let centroid01 = clamp01(finite(params.centroid01, fallback: 0.5))
        let variation = clamp01(finite(params.variation, fallback: 0))

        var random = SeededRandom(seed: seed &+ UInt64(stepIndex) &* 0x9E37_79B9_7F4A_7C15)
        let tips = frontierTips(of: structure)
        guard !tips.isEmpty else { return }
        let (parent, parentIndex) = tips[stepIndex % tips.count]

        let parentDirection = normalizedDirection(from: parent.start, to: parent.end)
        let parentLength = distance(parent.start, parent.end)
        let side: Double = random.double01() < 0.5 ? -1 : 1
        let jitter = (random.double01() - 0.5) * 2.0 * variation * 0.35
        // 高 centroid → 更向上（小张角）；低 centroid → 更横向（大张角）
        let angle = side * (0.28 + 0.42 * (1 - centroid01)) + jitter
        let childDirection = rotate(parentDirection, by: angle)
        let childLength = parentLength * (0.55 + 0.18 * random.double01())
        let start = parent.end
        let end = CGPoint(
            x: start.x + childDirection.x * childLength,
            y: start.y + childDirection.y * childLength
        )
        let thickness = max(parent.thickness * (0.55 + 0.20 * energy), 1.0)
        let curvature = childLength * (0.05 + 0.30 * variation) * (0.6 + 0.4 * random.double01())
        let perpendicular = CGPoint(x: -childDirection.y, y: childDirection.x)
        let curveSign: Double = random.double01() < 0.5 ? -1 : 1
        let control = CGPoint(
            x: (start.x + end.x) / 2 + perpendicular.x * curvature * curveSign,
            y: (start.y + end.y) / 2 + perpendicular.y * curvature * curveSign
        )
        let child = BranchModel(
            start: start,
            end: end,
            control: control,
            thickness: thickness,
            depth: stepIndex,
            parentIndex: parentIndex,
            curvature: curvature
        )
        structure.branches.append(child)

        let leafPosition = CGPoint(
            x: end.x + (random.double01() - 0.5) * 0.05,
            y: end.y - 0.02 + (random.double01() - 0.5) * 0.03
        )
        structure.events.append(
            PlantEvent(
                type: .leaf,
                position: leafPosition,
                size: 0.018 + energy * 0.026,
                depth: stepIndex
            )
        )

        structure.metadata.branchCount = structure.branches.count
        structure.metadata.leafCount += 1
        structure.metadata.maxDepth = max(structure.metadata.maxDepth, stepIndex)
        structure.metadata.maxBranchThickness = max(structure.metadata.maxBranchThickness, thickness)
        structure.metadata.totalCurvature += curvature
    }

    /// onset 事件：在确定性 frontier 尖端追加一朵花（每次 onset 一朵，受 flower 上限保护）。
    static func appendFlower(
        to structure: inout PlantStructure,
        params: LiveGrowthParams,
        seed: UInt64,
        eventIndex: Int
    ) {
        guard structure.metadata.flowerCount < maxFlowers else { return }

        let variation = clamp01(finite(params.variation, fallback: 0))
        var random = SeededRandom(seed: seed &+ UInt64(eventIndex) &* 0x517C_C1B7_2722_0A95)
        let tips = frontierTips(of: structure)
        guard let tip = tips.isEmpty ? nil : tips[(eventIndex - 1) % tips.count].0 else { return }

        let position = CGPoint(
            x: tip.end.x + (random.double01() - 0.5) * 0.04,
            y: tip.end.y - 0.04
        )
        structure.events.append(
            PlantEvent(
                type: .flower,
                position: position,
                size: 0.028 + variation * 0.016,
                depth: tip.depth
            )
        )
        structure.metadata.flowerCount += 1
    }

    // MARK: - 规范化辅助

    private struct NormalizedInput {
        var energy: Double
        var variation: Double
        var duration01: Double
        var centroidHz: Double
        var centroid01: Double
        var onsetCount: Int
        var scale: Double
        var heightFactor: Double
        var slimFactor: Double
        var trunkThickness: Double
        var trunkLeanX: Double
    }

    private static func normalize(_ profile: SoundProfile) -> NormalizedInput {
        let energy = clamp01(finite(profile.energy, fallback: 0))
        let variation = clamp01(finite(profile.variation, fallback: 0))
        let duration = max(finite(profile.duration, fallback: 0), 0)
        let duration01 = clamp01(duration / maxDuration)
        let centroidHz = sanitizedCentroid(profile.spectralCentroidHz)
        let centroid01 = clamp01((centroidHz - minCentroidHz) / (maxCentroidHz - minCentroidHz))
        let onsetValue = finite(Double(profile.onsetCount), fallback: 0)
        let onsetCount = Int(min(max(onsetValue, 0), Double(maxOnsetCount)))
        let scale = 0.7 + 0.9 * duration01
        let heightFactor = 0.45 + 0.55 * centroid01
        let slimFactor = 1.15 - 0.30 * centroid01
        let trunkThickness = max((5 + 15 * energy) * scale * slimFactor, 1.0)
        let trunkLeanX = (1 - centroid01) * 0.32 * heightFactor
        return NormalizedInput(
            energy: energy,
            variation: variation,
            duration01: duration01,
            centroidHz: centroidHz,
            centroid01: centroid01,
            onsetCount: onsetCount,
            scale: scale,
            heightFactor: heightFactor,
            slimFactor: slimFactor,
            trunkThickness: trunkThickness,
            trunkLeanX: trunkLeanX
        )
    }

    private static func makeTrunk(_ input: NormalizedInput) -> BranchModel {
        let base = CGPoint(x: 0.5, y: 0.92)
        let top = CGPoint(x: base.x + input.trunkLeanX, y: base.y - input.heightFactor)
        let trunkLength = distance(base, top)
        let trunkCurvature = trunkLength * (0.05 + 0.32 * input.variation)
        let trunkMid = midpoint(base, top)
        let trunkDirection = normalizedDirection(from: base, to: top)
        return BranchModel(
            start: base,
            end: top,
            control: CGPoint(
                x: trunkMid.x + (-trunkDirection.y) * trunkCurvature,
                y: trunkMid.y + trunkDirection.x * trunkCurvature
            ),
            thickness: input.trunkThickness,
            depth: 0,
            parentIndex: nil,
            curvature: trunkCurvature
        )
    }

    /// 当前可生长的 frontier 尖端（枝 + 其在 branches 中的下标；主干为 nil）。
    private static func frontierTips(of structure: PlantStructure) -> [(BranchModel, Int?)] {
        var tips: [(BranchModel, Int?)] = []
        for (index, branch) in structure.branches.enumerated() {
            let isParent = structure.branches.contains { $0.parentIndex == index }
            if !isParent {
                tips.append((branch, index))
            }
        }
        if tips.isEmpty {
            tips = structure.branches.isEmpty
                ? [(structure.trunk, nil)]
                : [(structure.branches[structure.branches.count - 1], structure.branches.count - 1)]
        }
        return tips
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }

    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func sanitizedCentroid(_ centroid: Double?) -> Double {
        guard let value = centroid, value.isFinite else { return fallbackCentroidHz }
        return min(max(value, minCentroidHz), maxCentroidHz)
    }

    private static func sanitizedCentroid(_ hz: Double) -> Double {
        let value = hz.isFinite ? hz : fallbackCentroidHz
        return min(max(value, minCentroidHz), maxCentroidHz)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(b.x - a.x, b.y - a.y)
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func normalizedDirection(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = hypot(dx, dy)
        guard length > 1e-9 else { return CGPoint(x: 0, y: -1) }
        return CGPoint(x: dx / length, y: dy / length)
    }

    private static func rotate(_ vector: CGPoint, by angle: Double) -> CGPoint {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: vector.x * cosA - vector.y * sinA,
            y: vector.x * sinA + vector.y * cosA
        )
    }
}
