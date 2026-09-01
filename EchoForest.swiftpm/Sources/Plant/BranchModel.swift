import CoreGraphics
import Foundation

/// 一段枝条：纯数据，包含二次曲线控制点与生成元信息。
struct BranchModel: Equatable, Codable {
    var start: CGPoint
    var end: CGPoint
    var control: CGPoint
    var thickness: Double
    var depth: Int
    /// 在 PlantStructure.branches 中的父分支下标；主干子分支为 nil。
    var parentIndex: Int?
    var curvature: Double

    /// 二次贝塞尔曲线上的点；`t` 会被钳到 0...1。
    func point(at rawT: Double) -> CGPoint {
        let t = min(max(rawT, 0), 1)
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    /// 用 de Casteljau 截取曲线前缀。这样部分生长的主干仍是原曲线的一段，
    /// 挂在原曲线上的枝叶不会因为端点 lerp 而悬空。
    func prefix(fraction raw: Double) -> BranchModel {
        let t = min(max(raw, 0), 1)
        if t <= 0 {
            return BranchModel(
                start: start,
                end: start,
                control: start,
                thickness: thickness,
                depth: depth,
                parentIndex: parentIndex,
                curvature: curvature
            )
        }
        if t >= 1 { return self }
        let q1 = Self.lerp(start, control, t)
        let r1 = Self.lerp(control, end, t)
        var copy = self
        copy.control = q1
        copy.end = Self.lerp(q1, r1, t)
        return copy
    }

    /// 点到曲线的近似最短距离（粗采样后再局部加密）。
    func distance(to point: CGPoint) -> Double {
        let closest = self.point(at: parameter(closestTo: point))
        return hypot(closest.x - point.x, closest.y - point.y)
    }

    /// 曲线上最接近给定点的参数 t。
    func parameter(closestTo point: CGPoint) -> Double {
        var bestT = 0.0
        var bestDistance = Double.greatestFiniteMagnitude
        let coarse = 40
        for index in 0...coarse {
            let t = Double(index) / Double(coarse)
            let candidate = self.point(at: t)
            let delta = hypot(candidate.x - point.x, candidate.y - point.y)
            if delta < bestDistance {
                bestDistance = delta
                bestT = t
            }
        }
        let span = 1 / Double(coarse)
        let lower = max(0, bestT - span)
        let upper = min(1, bestT + span)
        let fine = 24
        for index in 0...fine {
            let t = lower + (upper - lower) * Double(index) / Double(fine)
            let candidate = self.point(at: t)
            let delta = hypot(candidate.x - point.x, candidate.y - point.y)
            if delta < bestDistance {
                bestDistance = delta
                bestT = t
            }
        }
        return bestT
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

enum PlantEventType: String, Codable, Equatable {
    case leaf
    case flower
}

/// 叶片 / 花等结构事件节点。
struct PlantEvent: Equatable, Codable {
    var type: PlantEventType
    var position: CGPoint
    var size: Double
    /// 出现时对应的生长深度（GrowthState 按此逐步显现）。
    var depth: Int
}

/// 生成元信息（供测试断言与 UI 展示，不参与渲染几何）。
struct GenerationMetadata: Equatable, Codable {
    var branchCount: Int
    var leafCount: Int
    var flowerCount: Int
    var maxDepth: Int
    var trunkThickness: Double
    var height: Double
    var trunkLeanX: Double
    var scale: Double
    var totalCurvature: Double
    var maxBranchThickness: Double
    var centroidUsedHz: Double
}

/// 植物的完整纯数据结构：主干 + 分枝 + 事件 + 元数据。
/// 坐标使用单位空间（约 0...1），Renderer 负责映射到 Canvas 尺寸。
struct PlantStructure: Equatable, Codable {
    var scale: Double
    var trunk: BranchModel
    var branches: [BranchModel]
    var events: [PlantEvent]
    var metadata: GenerationMetadata

    var boundingBox: CGRect {
        var minX = trunk.start.x
        var maxX = trunk.start.x
        var minY = trunk.start.y
        var maxY = trunk.start.y

        func include(_ point: CGPoint) {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        include(trunk.end)
        include(trunk.control)
        for branch in branches {
            include(branch.start)
            include(branch.end)
            include(branch.control)
        }
        for event in events {
            include(event.position)
        }

        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 0.001),
            height: max(maxY - minY, 0.001)
        )
    }
}

/// 某一生长步骤下已显现的结构数量。
struct VisibleCounts: Equatable {
    var branches: Int
    var leaves: Int
    var flowers: Int
}

extension PlantStructure {
    func visibleCounts(upTo step: Int) -> VisibleCounts {
        VisibleCounts(
            branches: branches.filter { $0.depth <= step }.count,
            leaves: events.filter { $0.type == .leaf && $0.depth <= step }.count,
            flowers: events.filter { $0.type == .flower && $0.depth <= step }.count
        )
    }

    /// 分支/事件的出现进度：depth 的分支在 step=depth-1 时开始出现，step=depth 时完成。
    static func revealFraction(depth: Int, step: Double) -> Double {
        let resolved = step.isFinite ? step : 10_000
        let raw = resolved - Double(depth - 1)
        return min(max(raw, 0), 1)
    }

    static func easeOut(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return 1 - pow(1 - t, 3)
    }

    /// 主干拔高进度：小苗约 35%，约 3 步长到完整。
    func revealedTrunkFraction(steps: Double) -> Double {
        if !steps.isFinite { return 1 }
        return min(max(0.35 + 0.65 * (steps / 3), 0), 1)
    }

    /// 当前正在绘制的主干前缀（已套用 easeOut，与渲染器一致）。
    func revealedTrunk(steps: Double) -> BranchModel {
        trunk.prefix(fraction: Self.easeOut(revealedTrunkFraction(steps: steps)))
    }

    func shouldReveal(_ branch: BranchModel, steps: Double) -> Bool {
        guard Self.revealFraction(depth: branch.depth, step: steps) > 0 else { return false }
        let parent: BranchModel
        let parentFraction: Double
        if branch.depth <= 1 {
            parent = trunk
            parentFraction = Self.easeOut(revealedTrunkFraction(steps: steps))
        } else if let parentIndex = branch.parentIndex, branches.indices.contains(parentIndex) {
            parent = branches[parentIndex]
            parentFraction = Self.easeOut(Self.revealFraction(depth: parent.depth, step: steps))
        } else {
            return false
        }
        return parent.parameter(closestTo: branch.start) <= parentFraction + 0.01
    }

    func shouldReveal(_ event: PlantEvent, steps: Double) -> Bool {
        guard Self.revealFraction(depth: event.depth, step: steps) > 0 else { return false }
        guard let host = hostBranch(for: event) else { return false }
        return shouldReveal(host, steps: steps)
    }

    func hostBranch(for event: PlantEvent) -> BranchModel? {
        let candidates = branches.filter { $0.depth == event.depth }
        guard !candidates.isEmpty else { return nil }
        return candidates.min { left, right in
            left.distance(to: event.position) < right.distance(to: event.position)
        }
    }

    /// 事件跟宿主枝条当前已长到的位置：末梢叶跟尖端，靠近主干的叶等枝条长过挂点再展开。
    func revealedPosition(for event: PlantEvent, steps: Double) -> CGPoint {
        guard let host = hostBranch(for: event) else { return event.position }
        let fraction = Self.easeOut(Self.revealFraction(depth: host.depth, step: steps))
        let eventT = host.parameter(closestTo: event.position)
        let drawnT = min(eventT, fraction)
        let along = host.point(at: drawnT)
        let closest = host.point(at: eventT)
        let offsetScale = eventT <= 1e-6 ? fraction : min(fraction / eventT, 1)
        return CGPoint(
            x: along.x + (event.position.x - closest.x) * offsetScale,
            y: along.y + (event.position.y - closest.y) * offsetScale
        )
    }
}
