import SwiftUI

/// Mode-aware final plant artwork.
///
/// Echo keeps the generated botanical structure. Wild uses the design-template
/// language from `Design/assets/trees/tree-wild`: angular branches, amber
/// lightning cracks, and sparks, while still being driven by the recorded
/// SoundProfile.
struct PlantArtworkView: View {
    let plant: PlantModel
    let mode: GrowthMode
    var revealSteps: Double = .infinity

    var body: some View {
        if mode.isWild {
            WildTreeRenderer(profile: plant.profile)
        } else {
            PlantRenderer(structure: plant.structure, revealSteps: revealSteps)
        }
    }
}

private struct WildTreeRenderer: View {
    let profile: SoundProfile

    var body: some View {
        Canvas { context, size in
            let energy = Self.clamp01(profile.energy)
            let variation = Self.clamp01(profile.variation)
            let onset = min(max(profile.onsetCount, 0), 24)
            let duration = min(max(profile.duration, 0), PlantGenerator.maxDuration) / PlantGenerator.maxDuration
            let amber = Color(red: 0.95, green: 0.72, blue: 0.29)
            let paleAmber = Color(red: 1.00, green: 0.89, blue: 0.63)
            let trunk = Color(red: 0.09, green: 0.13, blue: 0.10)
            let branch = Color(red: 0.13, green: 0.18, blue: 0.14)
            let glow = Color(red: 0.48, green: 0.36, blue: 0.15)
            let scale = min(size.width / 1200, size.height / 1120)
            let origin = CGPoint(
                x: (size.width - 1200 * scale) / 2,
                y: size.height - 1110 * scale
            )

            func p(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
            }

            func draw(_ points: [CGPoint], width: Double, color: Color, opacity: Double = 1) {
                Self.taperedPolyline(points, startWidth: width * scale, color: color.opacity(opacity), in: &context)
            }

            let pulse = 1 + energy * 0.16
            let rootY = 1070.0
            context.fill(
                Path(ellipseIn: CGRect(
                    x: p(600, rootY + 10).x - 300 * scale,
                    y: p(600, rootY + 10).y - 34 * scale,
                    width: 600 * scale,
                    height: 68 * scale
                )),
                with: .color(glow.opacity(0.18 + 0.16 * energy))
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: p(600, rootY + 12).x - 205 * scale,
                    y: p(600, rootY + 12).y - 20 * scale,
                    width: 410 * scale,
                    height: 40 * scale
                )),
                with: .color(Color(red: 0.06, green: 0.11, blue: 0.07).opacity(0.52))
            )

            let trunkPoints = [
                p(585, rootY), p(572, 1000), p(590, 928), p(562, 850),
                p(604, 770), p(578, 690), p(616, 610), p(590, 526), p(622, 438)
            ]
            draw(trunkPoints, width: 70 * pulse, color: trunk)
            draw(trunkPoints, width: 118 * pulse, color: glow, opacity: 0.15)

            let branchSets: [[CGPoint]] = [
                [p(604, 770), p(720, 682), p(826, 560), p(934, 484), p(1010, 388)],
                [p(578, 690), p(456, 610), p(318, 538), p(156, 574)],
                [p(562, 850), p(456, 930), p(350, 1018), p(250, 1078)],
                [p(590, 526), p(506, 392), p(438, 260), p(356, 120)],
                [p(616, 610), p(750, 560), p(890, 516), p(1010, 470)],
                [p(604, 770), p(680, 878), p(734, 986), p(770, 1090)],
                [p(562, 850), p(506, 932), p(452, 1012), p(398, 1088)]
            ]
            for (index, points) in branchSets.enumerated() {
                let width = (index < 2 ? 38 : 26) * (0.88 + energy * 0.28)
                draw(points, width: width, color: branch, opacity: 0.95)
                draw(points, width: width * 1.65, color: glow, opacity: 0.13 + variation * 0.08)
            }

            var random = SeededRandom(seed: Self.seed(for: profile))
            let crackCount = 5 + Int(variation * 5)
            for _ in 0..<crackCount {
                let startX = 440 + random.double01() * 360
                let startY = 320 + random.double01() * 270
                var points: [CGPoint] = []
                var x = startX
                var y = startY
                for _ in 0..<7 {
                    points.append(p(x, y))
                    x += (random.double01() - 0.5) * (24 + 26 * variation)
                    y += 34 + random.double01() * 32
                }
                Self.strokePolyline(points, width: (1.4 + 2.2 * energy) * scale, color: amber.opacity(0.62), in: &context)
                Self.strokePolyline(points, width: 0.72 * scale, color: paleAmber.opacity(0.92), in: &context)
            }

            let sparkAnchors = branchSets.flatMap { [$0.last].compactMap { $0 } }
            let sparkCount = min(36, 12 + onset + Int(variation * 10))
            for index in 0..<sparkCount {
                let anchor = sparkAnchors[index % sparkAnchors.count]
                Self.drawSpark(
                    from: anchor,
                    radius: (28 + random.double01() * (64 + duration * 42)) * scale,
                    angle: random.double01() * .pi * 2,
                    color: index.isMultiple(of: 3) ? paleAmber : amber,
                    width: (0.7 + random.double01() * 1.4) * scale,
                    opacity: 0.38 + random.double01() * 0.44,
                    in: &context
                )
                if index.isMultiple(of: 4) {
                    let r = (3.2 + random.double01() * 4.6) * scale
                    context.fill(Path(ellipseIn: CGRect(x: anchor.x - r, y: anchor.y - r, width: r * 2, height: r * 2)), with: .color(paleAmber.opacity(0.65)))
                }
            }
        }
        .accessibilityLabel("暴走模式声音树")
    }

    nonisolated private static func taperedPolyline(_ points: [CGPoint], startWidth: Double, color: Color, in context: inout GraphicsContext) {
        guard points.count > 1 else { return }
        for index in 0..<(points.count - 1) {
            let t = Double(index) / Double(max(points.count - 2, 1))
            let width = max(startWidth * (1 - t * 0.72), 1)
            var path = Path()
            path.move(to: points[index])
            path.addLine(to: points[index + 1])
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    nonisolated private static func strokePolyline(_ points: [CGPoint], width: Double, color: Color, in context: inout GraphicsContext) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    nonisolated private static func drawSpark(
        from start: CGPoint,
        radius: Double,
        angle: Double,
        color: Color,
        width: Double,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        let end = CGPoint(x: start.x + cos(angle) * radius, y: start.y + sin(angle) * radius)
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    nonisolated private static func seed(for profile: SoundProfile) -> UInt64 {
        var value = UInt64(bitPattern: Int64(profile.onsetCount)) &* 0x9E37_79B9_7F4A_7C15
        value ^= profile.energy.bitPattern
        value &+= profile.variation.bitPattern.rotateLeft(13)
        value ^= profile.duration.bitPattern.rotateLeft(29)
        return value
    }

    nonisolated private static func clamp01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

private extension UInt64 {
    func rotateLeft(_ amount: Int) -> UInt64 {
        (self << UInt64(amount)) | (self >> UInt64(64 - amount))
    }
}
