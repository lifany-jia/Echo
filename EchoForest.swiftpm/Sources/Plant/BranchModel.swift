import CoreGraphics
import Foundation

/// 一段枝条：纯数据，包含二次曲线控制点与生成元信息。
struct BranchModel: Equatable {
    var start: CGPoint
    var end: CGPoint
    var control: CGPoint
    var thickness: Double
    var depth: Int
    /// 在 PlantStructure.branches 中的父分支下标；主干子分支为 nil。
    var parentIndex: Int?
    var curvature: Double
}

enum PlantEventType: Equatable {
    case leaf
    case flower
}

/// 叶片 / 花等结构事件节点。
struct PlantEvent: Equatable {
    var type: PlantEventType
    var position: CGPoint
    var size: Double
    /// 出现时对应的生长深度（GrowthState 按此逐步显现）。
    var depth: Int
}

/// 生成元信息（供测试断言与 UI 展示，不参与渲染几何）。
struct GenerationMetadata: Equatable {
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
struct PlantStructure: Equatable {
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
}
