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
        /// 会话已进行时长，用于主干继续长高、变粗。
        var duration: TimeInterval = 0
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
                    energySlope: slope,
                    duration: max(finite(profile.duration, fallback: 0), 0)
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
        stepIndex: Int,
        forceNewPrimary: Bool = false
    ) {
        guard structure.branches.count < maxBranchCount else { return }

        let energy = clamp01(finite(params.energy, fallback: 0))
        let centroid01 = clamp01(finite(params.centroid01, fallback: 0.5))
        let variation = clamp01(finite(params.variation, fallback: 0))
        let energySlope = finite(params.energySlope, fallback: 0)
        growTrunk(to: &structure, params: params)

        var random = SeededRandom(seed: seed &+ UInt64(stepIndex) &* 0x9E37_79B9_7F4A_7C15)

        let primaryIndices = branchIndices(in: structure, depth: 1)
        let secondaryIndices = branchIndices(in: structure, depth: 2)
        let twigIndices = branchIndices(in: structure, depth: 3)
        let targetPrimaryCount = min(maxPrimaryBranches, 4 + Int(variation * 3.0))

        let tier: Int
        let parent: BranchModel
        let parentIndex: Int?
        let start: CGPoint
        let wantPrimary = primaryIndices.count < targetPrimaryCount
        if (forceNewPrimary || wantPrimary)
            && (primaryIndices.isEmpty || forceNewPrimary || primaryIndices.count < 3 || stepIndex.isMultiple(of: 2)) {
            tier = 1
            parent = structure.trunk
            parentIndex = nil
            let trunkSlot = Double(primaryIndices.count) / Double(max(targetPrimaryCount - 1, 1))
            // 沿主干从较低处铺到接近树冠，避免枝叶只挤在中上段。
            start = structure.trunk.point(at: 0.18 + trunkSlot * 0.70 + (random.double01() - 0.5) * 0.04)
        } else if shouldGrowSecondary(
            primaryCount: primaryIndices.count,
            secondaryCount: secondaryIndices.count,
            stepIndex: stepIndex
        ),
                  let selectedParentIndex = preferredParent(
                    from: primaryIndices,
                    slope: energySlope,
                    in: structure,
                    wrapping: stepIndex + Int(variation * 10)
                  ) {
            tier = 2
            parent = structure.branches[selectedParentIndex]
            parentIndex = selectedParentIndex
            let childCount = childrenCount(of: selectedParentIndex, in: structure)
            start = parent.point(at: 0.48 + min(Double(childCount) * 0.18, 0.42) + (random.double01() - 0.5) * 0.05)
        } else if twigIndices.count < maxTerminalTwigs {
            tier = 3
            let candidates = secondaryIndices.isEmpty ? primaryIndices : secondaryIndices
            guard let selectedParentIndex = preferredParent(
                from: candidates,
                slope: energySlope,
                in: structure,
                wrapping: stepIndex * 2 + Int(variation * 13)
            ) else { return }
            parent = structure.branches[selectedParentIndex]
            parentIndex = selectedParentIndex
            let childCount = childrenCount(of: selectedParentIndex, in: structure)
            start = parent.point(at: 0.58 + min(Double(childCount) * 0.11, 0.34) + (random.double01() - 0.5) * 0.04)
        } else {
            return
        }

        let parentDirection = normalizedDirection(from: parent.start, to: parent.end)
        let parentLength = max(distance(parent.start, parent.end), 1e-4)
        let siblingCount = parentIndex.map { childrenCount(of: $0, in: structure) } ?? primaryIndices.count
        let alternateSide: Double = siblingCount.isMultiple(of: 2) ? -1 : 1
        let slopeSide: Double
        if energySlope > 0.012 {
            slopeSide = 1
        } else if energySlope < -0.012 {
            slopeSide = -1
        } else {
            slopeSide = 0
        }
        // 交替分叉保证左右都有枝；持续的能量升降只做偏向，避免某一根突然横着甩出去。
        let side = alternateSide * 0.35 + slopeSide * 0.65

        let parentPerp = CGPoint(x: -parentDirection.y, y: parentDirection.x)
        var desiredDirection: CGPoint
        if tier == 1 {
            let spread = 0.40 + (1 - centroid01) * 0.22
            let lift = 0.78 + centroid01 * 0.28
            desiredDirection = normalizeVector(CGPoint(x: side * spread, y: -lift))
        } else {
            desiredDirection = normalizeVector(CGPoint(
                x: parentDirection.x * 0.62 + parentPerp.x * side * 0.34,
                y: parentDirection.y * 0.62 + parentPerp.y * side * 0.34 - 0.12
            ))
        }

        let lengthRatio: Double
        switch tier {
        case 1: lengthRatio = 0.50 + energy * 0.08
        case 2: lengthRatio = 0.46 + energy * 0.06
        default: lengthRatio = 0.40 + energy * 0.05
        }
        let childLength = parentLength * lengthRatio
            * (0.94 + random.double01() * 0.10)
            * clamp(finite(params.lengthMultiplier, fallback: 1), 0.5, 2.5)
        let end = CGPoint(
            x: start.x + desiredDirection.x * childLength,
            y: start.y + desiredDirection.y * childLength
        )

        let tierThickness: Double
        switch tier {
        case 1: tierThickness = structure.trunk.thickness * (0.46 + energy * 0.18)
        case 2: tierThickness = parent.thickness * (0.50 + energy * 0.12)
        default: tierThickness = parent.thickness * (0.44 + energy * 0.10)
        }
        // 只设极小的下限（末梢允许比 0.004 更细但不得为 0），
        // 绝不能像旧版那样钳到 0.7-1.0（在渲染缩放后等于画柱子）。
        let thickness = max(tierThickness, tier == 3 ? 0.004 : 0.006)
        let curvature = childLength * (0.04 + 0.16 * variation) * (0.88 + 0.16 * random.double01())
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

        // 一级主枝也会带叶，让树在生长早期就有树冠轮廓（参考 Design/assets/trees）。
        if tier >= 1 && structure.metadata.leafCount < maxLeaves {
            let leafPosition = CGPoint(
                x: end.x + (random.double01() - 0.5) * 0.04,
                y: end.y - 0.018 + (random.double01() - 0.5) * 0.025
            )
            structure.events.append(
                PlantEvent(
                    type: .leaf,
                    position: leafPosition,
                    size: 0.020 + energy * 0.026,
                    depth: tier
                )
            )
            structure.metadata.leafCount += 1
        }
        // 主干附近再补一片叶，避免只有末梢有绿、主干长时间光秃。
        if tier == 1 && structure.metadata.leafCount < maxLeaves {
            let nearTrunk = child.point(at: 0.18 + random.double01() * 0.10)
            structure.events.append(
                PlantEvent(
                    type: .leaf,
                    position: CGPoint(
                        x: nearTrunk.x + (random.double01() - 0.5) * 0.018,
                        y: nearTrunk.y - 0.008
                    ),
                    size: 0.016 + energy * 0.018,
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
                    size: (0.026 + energy * 0.012 + variation * 0.012) * flowerSizeMultiplier,
                    depth: tip.depth
                )
            )
            structure.metadata.flowerCount += 1
        }
    }

    /// 主干随当前声音继续长高、变粗（只增不减），并把已有主枝一起带走，避免脱节。
    private static func growTrunk(to structure: inout PlantStructure, params: LiveGrowthParams) {
        let duration = max(finite(params.duration, fallback: 0), 0)
        let energy = clamp01(finite(params.energy, fallback: 0))
        let centroid01 = clamp01(finite(params.centroid01, fallback: 0.5))
        let variation = clamp01(finite(params.variation, fallback: 0))
        let centroidHz = minCentroidHz + centroid01 * (maxCentroidHz - minCentroidHz)
        let target = makeTrunk(
            normalize(
                SoundProfile(
                    duration: duration,
                    energy: energy,
                    peakEnergy: energy,
                    spectralCentroidHz: centroidHz,
                    onsetCount: 0,
                    variation: variation
                )
            )
        )

        let oldTrunk = structure.trunk
        let currentHeight = max(oldTrunk.start.y - oldTrunk.end.y, 1e-4)
        let desiredHeight = max(target.start.y - target.end.y, currentHeight)
        let grownHeight = currentHeight + min(max(desiredHeight - currentHeight, 0), 0.045)
        let grownThickness = oldTrunk.thickness + min(max(target.thickness - oldTrunk.thickness, 0), 0.008)
        let heightChanged = grownHeight > currentHeight + 1e-4
        let thickChanged = grownThickness > oldTrunk.thickness + 1e-5
        guard heightChanged || thickChanged else { return }

        var newTrunk = oldTrunk
        newTrunk.end = CGPoint(
            x: oldTrunk.start.x + (target.end.x - target.start.x),
            y: oldTrunk.start.y - grownHeight
        )
        newTrunk.thickness = grownThickness
        let trunkLength = distance(newTrunk.start, newTrunk.end)
        let trunkCurvature = trunkLength * (0.05 + 0.32 * variation)
        let trunkMid = midpoint(newTrunk.start, newTrunk.end)
        let trunkDirection = normalizedDirection(from: newTrunk.start, to: newTrunk.end)
        newTrunk.control = CGPoint(
            x: trunkMid.x + (-trunkDirection.y) * trunkCurvature,
            y: trunkMid.y + trunkDirection.x * trunkCurvature
        )
        newTrunk.curvature = trunkCurvature

        var primaryDelta: [Int: CGPoint] = [:]
        for (index, branch) in structure.branches.enumerated() where branch.depth == 1 {
            let t = oldTrunk.parameter(closestTo: branch.start)
            let newStart = newTrunk.point(at: t)
            primaryDelta[index] = CGPoint(x: newStart.x - branch.start.x, y: newStart.y - branch.start.y)
        }

        for eventIndex in structure.events.indices {
            guard let hostIndex = structure.hostBranchIndex(for: structure.events[eventIndex]),
                  let root = primaryRootIndex(hostIndex, in: structure),
                  let delta = primaryDelta[root]
            else { continue }
            structure.events[eventIndex].position = translated(structure.events[eventIndex].position, by: delta)
        }

        let thickRatio = oldTrunk.thickness > 1e-6 ? grownThickness / oldTrunk.thickness : 1
        for index in structure.branches.indices {
            if let root = primaryRootIndex(index, in: structure), let delta = primaryDelta[root] {
                structure.branches[index].start = translated(structure.branches[index].start, by: delta)
                structure.branches[index].end = translated(structure.branches[index].end, by: delta)
                structure.branches[index].control = translated(structure.branches[index].control, by: delta)
            }
            if thickRatio > 1 {
                let boosted = structure.branches[index].thickness * thickRatio
                let parentThick = structure.branches[index].parentIndex.flatMap { structure.branches.indices.contains($0) ? structure.branches[$0].thickness : nil } ?? grownThickness
                structure.branches[index].thickness = min(boosted, parentThick * 0.72)
            }
        }

        structure.trunk = newTrunk
        structure.metadata.height = grownHeight
        structure.metadata.trunkThickness = grownThickness
        structure.metadata.maxBranchThickness = max(structure.metadata.maxBranchThickness, grownThickness)
    }

    private static func primaryRootIndex(_ index: Int, in structure: PlantStructure) -> Int? {
        var current = index
        var hops = 0
        while structure.branches.indices.contains(current), hops < 8 {
            if structure.branches[current].depth == 1 { return current }
            guard let parent = structure.branches[current].parentIndex else { return nil }
            current = parent
            hops += 1
        }
        return nil
    }

    private static func translated(_ point: CGPoint, by delta: CGPoint) -> CGPoint {
        CGPoint(x: point.x + delta.x, y: point.y + delta.y)
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
        // 高度同时吃时长和频率：长会话必须能明显长高，而不是停在幼苗高度。
        let heightFactor = min(1.18, 0.36 + 0.38 * duration01 + 0.42 * centroid01)
        let slimFactor = 1.15 - 0.30 * centroid01
        // 单位空间内的树干粗细：约为主干长度的 5%-10%（0.03-0.11），
        // 渲染器会再乘画布缩放，因此这里必须是小数值；过大=画成柱子。
        let trunkThickness = max((0.030 + 0.055 * energy) * scale * slimFactor, 0.015)
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

    /// 能量下降优先在左侧父枝上长，上升优先右侧，避免整棵树左右乱甩。
    private static func preferredParent(
        from indices: [Int],
        slope: Double,
        in structure: PlantStructure,
        wrapping: Int
    ) -> Int? {
        guard !indices.isEmpty else { return nil }
        let trunkX = structure.trunk.start.x
        let preferred: [Int]
        if slope < -0.012 {
            preferred = indices.filter { structure.branches[$0].end.x <= trunkX }
        } else if slope > 0.012 {
            preferred = indices.filter { structure.branches[$0].end.x >= trunkX }
        } else {
            preferred = indices
        }
        let pool = preferred.isEmpty ? indices : preferred
        return pool[safe: wrapping]
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
