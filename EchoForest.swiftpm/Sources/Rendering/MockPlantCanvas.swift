import SwiftUI

struct MockPlantCanvas: View {
    let plant: MockPlantModel
    var progress: Double = 1
    var showsBloom: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        Canvas { context, size in
            let base = CGPoint(x: size.width * 0.5, y: size.height * 0.88)
            let height = size.height * (0.46 + plant.profile.pitch * 0.20) * clampedProgress
            let top = CGPoint(x: size.width * (0.47 + plant.profile.variation * 0.08), y: base.y - height)

            var trunk = Path()
            trunk.move(to: base)
            trunk.addCurve(
                to: top,
                control1: CGPoint(x: size.width * 0.40, y: base.y - height * 0.28),
                control2: CGPoint(x: size.width * 0.61, y: base.y - height * 0.68)
            )
            context.stroke(
                trunk,
                with: .color(Color(red: 0.45, green: 0.31, blue: 0.18)),
                style: StrokeStyle(lineWidth: 8 + plant.profile.energy * 9, lineCap: .round)
            )

            drawBranch(
                in: &context,
                from: point(from: base, to: top, amount: 0.44),
                length: size.width * 0.22 * clampedProgress,
                angle: -.pi * (0.18 + plant.profile.variation * 0.10),
                width: 4.5
            )
            drawBranch(
                in: &context,
                from: point(from: base, to: top, amount: 0.62),
                length: size.width * 0.20 * clampedProgress,
                angle: .pi * (0.16 + plant.profile.rhythm * 0.09),
                width: 4
            )
            drawBranch(
                in: &context,
                from: point(from: base, to: top, amount: 0.78),
                length: size.width * 0.14 * clampedProgress,
                angle: -.pi * 0.12,
                width: 3
            )

            if showsBloom {
                drawLeafCluster(in: &context, center: top, size: size.width * 0.13)
                drawLeafCluster(
                    in: &context,
                    center: CGPoint(x: top.x - size.width * 0.12, y: top.y + size.height * 0.14),
                    size: size.width * 0.09
                )
                drawLeafCluster(
                    in: &context,
                    center: CGPoint(x: top.x + size.width * 0.13, y: top.y + size.height * 0.19),
                    size: size.width * 0.08
                )
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
        .accessibilityLabel("Mock plant preview")
    }

    private func drawBranch(
        in context: inout GraphicsContext,
        from start: CGPoint,
        length: Double,
        angle: Double,
        width: Double
    ) {
        let end = CGPoint(
            x: start.x + cos(angle) * length,
            y: start.y - sin(abs(angle)) * length
        )
        var branch = Path()
        branch.move(to: start)
        branch.addQuadCurve(
            to: end,
            control: CGPoint(x: (start.x + end.x) / 2, y: start.y - length * 0.34)
        )
        context.stroke(
            branch,
            with: .color(Color(red: 0.39, green: 0.27, blue: 0.15)),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func drawLeafCluster(in context: inout GraphicsContext, center: CGPoint, size: Double) {
        let colors = [
            Color(red: 0.32, green: 0.64, blue: 0.38),
            Color(red: 0.70, green: 0.74, blue: 0.38),
            Color(red: 0.93, green: 0.67, blue: 0.48)
        ]

        for index in 0..<7 {
            let angle = Double(index) / 7 * .pi * 2
            let leafCenter = CGPoint(
                x: center.x + cos(angle) * size * 0.42,
                y: center.y + sin(angle) * size * 0.30
            )
            let rect = CGRect(
                x: leafCenter.x - size * 0.18,
                y: leafCenter.y - size * 0.28,
                width: size * 0.36,
                height: size * 0.56
            )
            context.fill(Path(ellipseIn: rect), with: .color(colors[index % colors.count].opacity(0.92)))
        }
    }

    private func point(from start: CGPoint, to end: CGPoint, amount: Double) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * amount,
            y: start.y + (end.y - start.y) * amount
        )
    }
}
