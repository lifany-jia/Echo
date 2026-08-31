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
        var energySlope: Double = 0
        /// Wild Burst：适度放大新枝长度（不允许突破 hard limits）。
        var lengthMultiplier: Double = 1
        /// Wild Burst：让开花更明显（只影响表现尺寸，不增加事件数量）。
        var flowerSizeMultiplier: Double = 1
    }

    static let maxDepth = 4
    static let maxPrimaryBranches = 7
    static let maxSecondaryBranches = 20
    static let maxTerminalTwigs = 45
    static let maxBranchCount = maxPrimaryBranches + maxSecondaryBranches + maxTerminalTwigs
    static let maxLeaves = 52
    static let maxFlowers = 64
    static let maxOnsetCount = 24
    static let maxDuration: TimeInterval = 30
    static let minCentroidHz = 100.0
    static let maxCentroidHz = 4_000.0
    static let fallbackCentroidHz = 800.0

    /// 回退路径使用的确定性 SoundProfile（非麦克风数据）。
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
        return generate(profile: simulatedProfile, seed: seed, name: "\(name(for: simulatedProfile)) \(safeIndex)")
    }

    /// 正式命名：完全由 SoundProfile 确定性推导，无 mock / 模拟 / 编号痕迹。
    /// energy → 轻 / 柔 / 亮；centroid → 缓 / 展 / 扬；variation / duration → 藤 / 苗 / 树。
    static func name(for profile: SoundProfile) -> String {
        let energy = clamp01(finite(profile.energy, fallback: 0.5))
        let variation = clamp01(finite(profile.variation, fallback: 0.5))
        let duration = max(finite(profile.duration, fallback: 8), 0)

        let energyWord = energy < 0.33 ? "轻" : energy < 0.66 ? "柔" : "亮"
        let directionWord: String
        if let centroid = profile.spectralCentroidHz, centroid.isFinite {
            directionWord = centroid < 400 ? "缓" : centroid < 1500 ? "展" : "扬"
        } else {
            directionWord = "展"
        }
        let kind: String
        if variation >= 0.7 {
            kind = "藤"
        } else {
            kind = duration < 12 ? "苗" : "树"
        }
        return energyWord + directionWord + kind
    }

    static func generate(profile: SoundProfile, seed: UInt64, name: String = "声音植物") -> PlantModel {
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
        var structure = initialStructure(profile: profile, seed: seed)
        let stepBudget = min(
            maxBranchCount,
            2 + Int(input.duration01 * 42) + Int(input.energy * 3) + Int(input.variation * 4)
        )

        for step in 1...max(stepBudget, 1) {
            let sideCycle = (step + Int(input.variation * 10)) % 4
            let slope = sideCycle < 2 ? -0.18 : 0.18
            appendGrowthStep(
                to: &structure,
                params: LiveGrowthParams(
                    energy: input.energy,
                    centroid01: input.centroid01,
                    variation: input.variation,
                    energySlope: slope
                ),
                seed: seed,
                stepIndex: step
            )
        }

        if input.onsetCount > 0 {
            for index in 1...input.onsetCount {
                appendFlower(
                    to: &structure,
                    params: LiveGrowthParams(
                        energy: input.energy,
                        centroid01: input.centroid01,
                        variation: input.variation,
                        energySlope: index.isMultiple(of: 2) ? 0.16 : -0.16
                    ),
                    seed: seed,
                    eventIndex: index
                )
            }
        }

        return structure
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

    /// 增量生长一步：按 trunk → primary → secondary → terminal twig 的层级追加一条新枝。
    /// energy slope 决定左右，centroid 决定横向/向上，variation 决定弯曲和分叉密度。
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
        let energySlope = finite(params.energySlope, fallback: 0)

        var random = SeededRandom(seed: seed &+ UInt64(stepIndex) &* 0x9E37_79B9_7F4A_7C15)

        let primaryIndices = branchIndices(in: structure, depth: 1)
        let secondaryIndices = branchIndices(in: structure, depth: 2)
        let twigIndices = branchIndices(in: structure, depth: 3)
        let targetPrimaryCount = min(maxPrimaryBranches, 4 + Int(variation * 3.0))

        let tier: Int
        let parent: BranchModel
        let parentIndex: Int?
        let start: CGPoint
        if primaryIndices.count < targetPrimaryCount && (primaryIndices.isEmpty || stepIndex.isMultiple(of: 3)) {
            tier = 1
            parent = structure.trunk
            parentIndex = nil
            let trunkSlot = Double(primaryIndices.count) / Double(max(targetPrimaryCount - 1, 1))
            start = point(on: structure.trunk, t: 0.34 + trunkSlot * 0.48 + (random.double01() - 0.5) * 0.04)
        } else if shouldGrowSecondary(
            primaryCount: primaryIndices.count,
            secondaryCount: secondaryIndices.count,
            stepIndex: stepIndex
        ),
                  let selectedParentIndex = primaryIndices[safe: stepIndex + Int(variation * 10)] {
            tier = 2
            parent = structure.branches[selectedParentIndex]
            parentIndex = selectedParentIndex
            let childCount = childrenCount(of: selectedParentIndex, in: structure)
            start = point(on: parent, t: 0.48 + min(Double(childCount) * 0.18, 0.42) + (random.double01() - 0.5) * 0.05)
        } else if twigIndices.count < maxTerminalTwigs {
            tier = 3
            let candidates = secondaryIndices.isEmpty ? primaryIndices : secondaryIndices
            guard let selectedParentIndex = candidates[safe: stepIndex * 2 + Int(variation * 13)] else { return }
            parent = structure.branches[selectedParentIndex]
            parentIndex = selectedParentIndex
            let childCount = childrenCount(of: selectedParentIndex, in: structure)
            start = point(on: parent, t: 0.58 + min(Double(childCount) * 0.11, 0.34) + (random.double01() - 0.5) * 0.04)
        } else {
            return
        }

        let parentDirection = normalizedDirection(from: parent.start, to: parent.end)
        let slopeSide: Double
        if energySlope < -0.012 {
            slopeSide = -1
        } else if energySlope > 0.012 {
            slopeSide = 1
        } else if tier == 1 {
            slopeSide = primaryIndices.count.isMultiple(of: 2) ? -1 : 1
        } else {
            slopeSide = random.double01() < 0.5 ? -1 : 1
        }

        let lateral = 0.34 + (1 - centroid01) * 0.78
        let vertical = 0.28 + centroid01 * 0.92
        var desiredDirection = normalizeVector(CGPoint(x: slopeSide * lateral, y: -vertical))
        if tier > 1 {
            desiredDirection = normalizeVector(CGPoint(
                x: parentDirection.x * 0.28 + desiredDirection.x * 0.72,
                y: parentDirection.y * 0.28 + desiredDirection.y * 0.72
            ))
        }

        let lengthBase: Double
        switch tier {
        case 1: lengthBase = 0.26
        case 2: lengthBase = 0.17
        default: lengthBase = 0.10
        }
        let childLength = lengthBase
            * (0.82 + energy * 0.45 + random.double01() * 0.16)
            * clamp(finite(params.lengthMultiplier, fallback: 1), 0.5, 2.5)
        let end = CGPoint(
            x: start.x + desiredDirection.x * childLength,
            y: start.y + desiredDirection.y * childLength
        )

        let tierThickness: Double
        switch tier {
        case 1: tierThickness = structure.trunk.thickness * (0.36 + energy * 0.24)
        case 2: tierThickness = parent.thickness * (0.48 + energy * 0.14)
        default: tierThickness = parent.thickness * (0.42 + energy * 0.12)
        }
        let thickness = max(tierThickness, tier == 3 ? 0.7 : 1.0)
        let curvature = childLength * (0.025 + 0.32 * variation) * (0.75 + 0.35 * random.double01())
        let perpendicular = CGPoint(x: -desiredDirection.y, y: desiredDirection.x)
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
            depth: tier,
            parentIndex: parentIndex,
            curvature: curvature
        )
        structure.branches.append(child)

        if tier >= 2 && structure.metadata.leafCount < maxLeaves {
            let leafPosition = CGPoint(
                x: end.x + (random.double01() - 0.5) * 0.04,
                y: end.y - 0.018 + (random.double01() - 0.5) * 0.025
            )
            structure.events.append(
                PlantEvent(
                    type: .leaf,
                    position: leafPosition,
                    size: 0.014 + energy * 0.020,
                    depth: tier
                )
            )
            structure.metadata.leafCount += 1
        }

        structure.metadata.branchCount = structure.branches.count
        structure.metadata.maxDepth = max(structure.metadata.maxDepth, tier)
        structure.metadata.maxBranchThickness = max(structure.metadata.maxBranchThickness, thickness)
        structure.metadata.totalCurvature += curvature
    }

    /// onset 事件：在外围 terminal twig 上追加花芽/花朵；连续 onset 会形成小花簇。
    static func appendFlower(
        to structure: inout PlantStructure,
        params: LiveGrowthParams,
        seed: UInt64,
        eventIndex: Int
    ) {
        guard structure.metadata.flowerCount < maxFlowers else { return }

        let energy = clamp01(finite(params.energy, fallback: 0))
        let variation = clamp01(finite(params.variation, fallback: 0))
        let flowerSizeMultiplier = clamp(finite(params.flowerSizeMultiplier, fallback: 1), 0.5, 3)
        var random = SeededRandom(seed: seed &+ UInt64(eventIndex) &* 0x517C_C1B7_2722_0A95)
        let allTwigs = terminalTwigs(of: structure)
        guard !allTwigs.isEmpty else { return }

        // 花只出现在树冠外围：优先选离主干较远的末梢，避免花长在树干中间。
        let farTwigs = allTwigs.filter { (tip, _) in
            trunkSegmentDistance(tip.end, trunk: structure.trunk) > 0.055
        }
        let twigs = farTwigs.isEmpty ? allTwigs : farTwigs

        let clusterCount = min(
            maxFlowers - structure.metadata.flowerCount,
            eventIndex > 1 ? 2 + min(eventIndex % 2, 1) : 1
        )
        let (tip, _) = twigs[(eventIndex - 1) % twigs.count]

        for _ in 0..<clusterCount {
            let clusterRadius = 0.018 + 0.022 * variation
            let angle = random.double01() * .pi * 2
            let radius = random.double01() * clusterRadius
            let position = CGPoint(
                x: tip.end.x + cos(angle) * radius,
                y: tip.end.y + sin(angle) * radius - 0.02
            )
            structure.events.append(
                PlantEvent(
                    type: .flower,
                    position: position,
                    size: (0.020 + energy * 0.010 + variation * 0.010) * flowerSizeMultiplier,
                    depth: tip.depth
                )
            )
            structure.metadata.flowerCount += 1
        }
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
        let trunkLeanX = (0.5 - centroid01) * 0.06 * heightFactor
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

    private static func terminalTwigs(of structure: PlantStructure) -> [(BranchModel, Int)] {
        structure.branches.enumerated().compactMap { index, branch in
            guard branch.depth == 3, childrenCount(of: index, in: structure) == 0 else { return nil }
            return (branch, index)
        }
    }

    private static func branchIndices(in structure: PlantStructure, depth: Int) -> [Int] {
        structure.branches.enumerated().compactMap { index, branch in
            branch.depth == depth ? index : nil
        }
    }

    private static func shouldGrowSecondary(primaryCount: Int, secondaryCount: Int, stepIndex: Int) -> Bool {
        guard primaryCount > 0 else { return false }
        let target = min(maxSecondaryBranches, max(primaryCount * 3, 10))
        if secondaryCount < min(4, target) {
            return true
        }
        return secondaryCount < target && stepIndex.isMultiple(of: 4)
    }

    private static func childrenCount(of parentIndex: Int, in structure: PlantStructure) -> Int {
        structure.branches.filter { $0.parentIndex == parentIndex }.count
    }

    private static func trunkSegmentDistance(_ point: CGPoint, trunk: BranchModel) -> Double {
        let dx = trunk.end.x - trunk.start.x
        let dy = trunk.end.y - trunk.start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-12 else {
            return distance(point, trunk.start)
        }
        let t = min(max(
            ((point.x - trunk.start.x) * dx + (point.y - trunk.start.y) * dy) / lengthSquared,
            0
        ), 1)
        return distance(point, CGPoint(x: trunk.start.x + t * dx, y: trunk.start.y + t * dy))
    }

    private static func point(on branch: BranchModel, t rawT: Double) -> CGPoint {
        let t = min(max(rawT, 0), 1)
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * branch.start.x
                + 2 * oneMinusT * t * branch.control.x
                + t * t * branch.end.x,
            y: oneMinusT * oneMinusT * branch.start.y
                + 2 * oneMinusT * t * branch.control.y
                + t * t * branch.end.y
        )
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }

    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
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

    private static func normalizeVector(_ vector: CGPoint) -> CGPoint {
        let length = hypot(vector.x, vector.y)
        guard length > 1e-9 else { return CGPoint(x: 0, y: -1) }
        return CGPoint(x: vector.x / length, y: vector.y / length)
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

private extension Array {
    subscript(safe wrappingIndex: Int) -> Element? {
        guard !isEmpty else { return nil }
        let index = ((wrappingIndex % count) + count) % count
        return self[index]
    }
}
