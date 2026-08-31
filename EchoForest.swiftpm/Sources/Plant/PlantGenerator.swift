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
        // ---- 输入规范化：clamp / normalize / fallback ----
        let energy = clamp01(finite(profile.energy, fallback: 0))
        let variation = clamp01(finite(profile.variation, fallback: 0))
        let duration = max(finite(profile.duration, fallback: 0), 0)
        let duration01 = clamp01(duration / maxDuration)
        let centroidHz = sanitizedCentroid(profile.spectralCentroidHz)
        let centroid01 = clamp01((centroidHz - minCentroidHz) / (maxCentroidHz - minCentroidHz))
        let onsetValue = finite(Double(profile.onsetCount), fallback: 0)
        let onsetCount = Int(min(max(onsetValue, 0), Double(maxOnsetCount)))

        // ---- 主干 ----
        let scale = 0.7 + 0.9 * duration01
        let heightFactor = 0.45 + 0.55 * centroid01
        let slimFactor = 1.15 - 0.30 * centroid01
        let trunkThickness = max((5 + 15 * energy) * scale * slimFactor, 1.0)

        var random = SeededRandom(seed: seed)

        let base = CGPoint(x: 0.5, y: 0.92)
        let leanX = (1 - centroid01) * 0.32 * heightFactor
        let top = CGPoint(x: base.x + leanX, y: base.y - heightFactor)
        let trunkLength = distance(base, top)
        let trunkCurvature = trunkLength * (0.05 + 0.32 * variation)
        let trunkMid = midpoint(base, top)
        let trunkDirection = normalizedDirection(from: base, to: top)
        let trunk = BranchModel(
            start: base,
            end: top,
            control: CGPoint(
                x: trunkMid.x + (-trunkDirection.y) * trunkCurvature,
                y: trunkMid.y + trunkDirection.x * trunkCurvature
            ),
            thickness: trunkThickness,
            depth: 0,
            parentIndex: nil,
            curvature: trunkCurvature
        )

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
            trunkLeanX: abs(leanX),
            scale: scale,
            totalCurvature: totalCurvature,
            maxBranchThickness: maxBranchThickness,
            centroidUsedHz: centroidHz
        )

        return PlantStructure(
            scale: scale,
            trunk: trunk,
            branches: branches,
            events: events,
            metadata: metadata
        )
    }

    // MARK: - 规范化辅助

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
