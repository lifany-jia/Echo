import SwiftUI

/// Stage 7 — 纯渲染层：PlantStructure → Canvas。
///
/// `revealSteps` 是连续的生长揭示进度（0...总步数）：
/// - 分支在 depth-1 → depth 之间从父节点连接点向外长（endpoint 插值）
/// - 叶片随分支淡入放大
/// - 花有轻微 bloom（scale 过冲），仍是 model 层的同一个离散事件
///
/// 只做 presentation，不重算声音映射、不修改 PlantModel。
struct PlantRenderer: View {
    let structure: PlantStructure
    /// 连续揭示进度；`.infinity` 表示完整植物。
    var revealSteps: Double = .infinity

    var animatableData: Double {
        get { revealSteps.isFinite ? revealSteps : 10_000 }
        set { revealSteps = newValue >= 9_999 ? .infinity : newValue }
    }

    var body: some View {
        Canvas { context, size in
            let box = Self.stableViewport(for: structure.boundingBox)
            // 以树干基部为锚点：贴底居中、向上生长（与 Design/assets/trees 概念树构图一致），
            // 而不是把整棵树按包围盒居中（那样基部会悬空）。
            let base = structure.trunk.start
            let scale = min(size.width / box.width, size.height / box.height) * 0.92
            let baseTarget = CGPoint(x: size.width * 0.5, y: size.height * 0.965)
            let offsetX = baseTarget.x - base.x * scale
            let offsetY = baseTarget.y - base.y * scale

            func transform(_ point: CGPoint) -> CGPoint {
                CGPoint(
                    x: point.x * scale + offsetX,
                    y: point.y * scale + offsetY
                )
            }

            // 设计语言（深夜森林）：深林绿主干/枝条 + 琥珀花，参考 Design/assets/trees。
            let trunkColor = Color(red: 0.15, green: 0.25, blue: 0.19)    // #263F30
            let branchColor = Color(red: 0.20, green: 0.33, blue: 0.25)   // #335440

            // 基部地面柔光（根部贴地感）。
            let groundCenter = transform(CGPoint(x: base.x, y: base.y + 0.045))
            context.fill(
                Path(ellipseIn: CGRect(
                    x: groundCenter.x - size.width * 0.17,
                    y: groundCenter.y - size.height * 0.011,
                    width: size.width * 0.34,
                    height: size.height * 0.022
                )),
                with: .color(Color(red: 0.10, green: 0.20, blue: 0.14).opacity(0.55))
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: groundCenter.x - size.width * 0.10,
                    y: groundCenter.y - size.height * 0.006,
                    width: size.width * 0.20,
                    height: size.height * 0.012
                )),
                with: .color(Color(red: 0.18, green: 0.31, blue: 0.20).opacity(0.45))
            )

            // 主干从基部向上生长：起始是一株小苗（约 35%），随 revealSteps 拔高到完整。
            // 底部粗、向上收细。
            let trunkFraction = min(max(0.35 + 0.65 * (revealSteps / 3), 0), 1)
            Self.strokeTaperedBranch(
                structure.trunk,
                fraction: trunkFraction,
                transform: transform,
                scale: scale,
                color: trunkColor,
                endThicknessFactor: 0.18,
                in: &context
            )

            for branch in structure.branches {
                let fraction = Self.revealFraction(depth: branch.depth, step: revealSteps)
                guard fraction > 0 else { continue }
                Self.strokeTaperedBranch(
                    branch,
                    fraction: fraction,
                    transform: transform,
                    scale: scale,
                    color: branchColor,
                    endThicknessFactor: 0.42,
                    in: &context
                )
            }

            for event in structure.events {
                let fraction = Self.revealFraction(depth: event.depth, step: revealSteps)
                guard fraction > 0 else { continue }
                Self.drawEvent(event, fraction: fraction, transform: transform, scale: scale, in: &context)
            }
        }
        .accessibilityLabel("声音长成的植物")
    }

    /// 分支/事件的出现进度：depth 的分支在 step=depth-1 时开始出现，step=depth 时完成。
    static func revealFraction(depth: Int, step: Double) -> Double {
        let raw = step - Double(depth - 1)
        return min(max(raw, 0), 1)
    }

    private static func easeOut(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    /// 把一条二次曲线枝画成“从粗到细”的填充形状：
    /// 沿曲线采样，用法线方向按当前粗细偏移，形成自然的 taper，
    /// 避免“算法线条树”那种统一线宽的机械感。
    private static func strokeTaperedBranch(
        _ branch: BranchModel,
        fraction: Double,
        transform: (CGPoint) -> CGPoint,
        scale: Double,
        color: Color,
        endThicknessFactor: Double,
        in context: inout GraphicsContext
    ) {
        let t = easeOut(fraction)
        let start = branch.start
        let end = CGPoint(
            x: start.x + (branch.end.x - start.x) * t,
            y: start.y + (branch.end.y - start.y) * t
        )
        let control = CGPoint(
            x: start.x + (branch.control.x - start.x) * t,
            y: start.y + (branch.control.y - start.y) * t
        )

        let startWidth = max(branch.thickness * scale, 0.6)
        let endWidth = max(branch.thickness * endThicknessFactor * scale, 0.45)
        let sampleCount = 10

        var leftPoints: [CGPoint] = []
        var rightPoints: [CGPoint] = []
        for sample in 0...sampleCount {
            let s = Double(sample) / Double(sampleCount)
            let point = Self.quadPoint(start: start, control: control, end: end, t: s)
            let tangent = Self.quadTangent(start: start, control: control, end: end, t: s)
            let tangentLength = hypot(tangent.x, tangent.y)
            let normal: CGPoint
            if tangentLength > 1e-9 {
                normal = CGPoint(x: -tangent.y / tangentLength, y: tangent.x / tangentLength)
            } else {
                normal = CGPoint(x: 0, y: -1)
            }
            let width = startWidth + (endWidth - startWidth) * s
            let half = CGPoint(x: normal.x * width * 0.5, y: normal.y * width * 0.5)
            leftPoints.append(CGPoint(x: point.x - half.x, y: point.y - half.y))
            rightPoints.append(CGPoint(x: point.x + half.x, y: point.y + half.y))
        }

        var path = Path()
        path.move(to: transform(leftPoints[0]))
        for point in leftPoints.dropFirst() {
            path.addLine(to: transform(point))
        }
        for point in rightPoints.reversed() {
            path.addLine(to: transform(point))
        }
        path.closeSubpath()
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: 0.5,
                lineCap: .round
            )
        )
        context.fill(path, with: .color(color.opacity(0.96)))
    }

    /// 二次贝塞尔曲线上的点。
    private static func quadPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: Double) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    /// 二次贝塞尔曲线切向量（未归一化；零长曲线由调用方保证不出现）。
    private static func quadTangent(start: CGPoint, control: CGPoint, end: CGPoint, t: Double) -> CGPoint {
        CGPoint(
            x: 2 * (1 - t) * (control.x - start.x) + 2 * t * (end.x - control.x),
            y: 2 * (1 - t) * (control.y - start.y) + 2 * t * (end.y - control.y)
        )
    }

    private static func stableViewport(for box: CGRect) -> CGRect {
        let minimum = CGRect(x: -0.25, y: -0.35, width: 1.5, height: 1.55)
        return box.union(minimum).insetBy(dx: -0.08, dy: -0.08)
    }

    private static func drawEvent(
        _ event: PlantEvent,
        fraction: Double,
        transform: (CGPoint) -> CGPoint,
        scale: Double,
        in context: inout GraphicsContext
    ) {
        let center = transform(event.position)
        switch event.type {
        case .leaf:
            let grow = easeOut(fraction)
            let leafSize = event.size * scale * grow
            let rect = CGRect(
                x: center.x - leafSize,
                y: center.y - leafSize * 1.6,
                width: leafSize * 2,
                height: leafSize * 3.2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.52, green: 0.70, blue: 0.52).opacity(0.90 * grow))
            )

        case .flower:
            let bloom = fraction * (1 + 0.12 * sin(min(fraction, 1) * .pi))
            let flowerSize = event.size * scale * bloom
            let petalColors = [
                Color(red: 0.91, green: 0.64, blue: 0.29),
                Color(red: 0.85, green: 0.48, blue: 0.32)
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
                    with: .color(petalColors[index % petalColors.count].opacity(0.92 * fraction))
                )
            }
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - flowerSize * 0.35,
                    y: center.y - flowerSize * 0.35,
                    width: flowerSize * 0.7,
                    height: flowerSize * 0.7
                )),
                with: .color(Color(red: 0.96, green: 0.89, blue: 0.63).opacity(0.95 * fraction))
            )
        }
    }
}
