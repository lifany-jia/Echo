import SwiftUI

/// Stage 4 — 纯渲染层：PlantStructure → Canvas 视觉。
/// 不在这里重新计算声音映射；映射全部集中在 PlantGenerator。
struct PlantRenderer: View {
    let structure: PlantStructure
    /// 只绘制深度 <= visibleSteps 的分支与事件；nil 表示完整植物。
    var visibleSteps: Int? = nil

    var body: some View {
        Canvas { context, size in
            let box = structure.boundingBox
            let scale = min(size.width / box.width, size.height / box.height) * 0.92
            let offsetX = (size.width - box.width * scale) / 2 - box.minX * scale
            let offsetY = (size.height - box.height * scale) / 2 - box.minY * scale

            func transform(_ point: CGPoint) -> CGPoint {
                CGPoint(
                    x: point.x * scale + offsetX,
                    y: point.y * scale + offsetY
                )
            }

            let trunkColor = Color(red: 0.42, green: 0.29, blue: 0.16)
            let branchColor = Color(red: 0.38, green: 0.26, blue: 0.14)

            Self.strokeBranch(
                structure.trunk,
                transform: transform,
                scale: scale,
                color: trunkColor,
                in: &context
            )

            let maxStep = visibleSteps ?? Int.max
            for branch in structure.branches where branch.depth <= maxStep {
                Self.strokeBranch(
                    branch,
                    transform: transform,
                    scale: scale,
                    color: branchColor,
                    in: &context
                )
            }

            for event in structure.events where event.depth <= maxStep {
                Self.drawEvent(event, transform: transform, scale: scale, in: &context)
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
        .accessibilityLabel("程序化植物")
    }

    private static func strokeBranch(
        _ branch: BranchModel,
        transform: (CGPoint) -> CGPoint,
        scale: Double,
        color: Color,
        in context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: transform(branch.start))
        path.addQuadCurve(to: transform(branch.end), control: transform(branch.control))
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: max(branch.thickness * scale, 0.75), lineCap: .round)
        )
    }

    private static func drawEvent(
        _ event: PlantEvent,
        transform: (CGPoint) -> CGPoint,
        scale: Double,
        in context: inout GraphicsContext
    ) {
        let center = transform(event.position)
        switch event.type {
        case .leaf:
            let leafSize = event.size * scale
            let rect = CGRect(
                x: center.x - leafSize,
                y: center.y - leafSize * 1.6,
                width: leafSize * 2,
                height: leafSize * 3.2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.32, green: 0.64, blue: 0.38).opacity(0.92))
            )

        case .flower:
            let flowerSize = event.size * scale
            let petalColors = [
                Color(red: 0.93, green: 0.67, blue: 0.48),
                Color(red: 0.86, green: 0.42, blue: 0.45)
            ]
            let petalCount = 5
            for index in 0..<petalCount {
                let angle = Double(index) / Double(petalCount) * .pi * 2
                let petalCenter = CGPoint(
                    x: center.x + cos(angle) * flowerSize * 0.8,
                    y: center.y + sin(angle) * flowerSize * 0.8
                )
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: petalCenter.x - flowerSize * 0.35,
                        y: petalCenter.y - flowerSize * 0.35,
                        width: flowerSize * 0.7,
                        height: flowerSize * 0.7
                    )),
                    with: .color(petalColors[index % petalColors.count].opacity(0.92))
                )
            }
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - flowerSize * 0.35,
                    y: center.y - flowerSize * 0.35,
                    width: flowerSize * 0.7,
                    height: flowerSize * 0.7
                )),
                with: .color(Color(red: 0.98, green: 0.86, blue: 0.45))
            )
        }
    }
}
