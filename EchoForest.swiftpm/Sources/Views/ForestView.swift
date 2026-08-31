import SwiftUI

/// 主页（Forest）：深夜森林美学。
/// 与 `Design/figma-design-draft.html` Frame A/B/C 对齐：
/// 墨夜绿渐变 + 月白文字 + 单一琥珀强调色 + 萤火微光。
/// 声音 → 树的表达：音量、音高、拍手、时长、变化。
struct ForestView: View {
    let plantedRecords: [PlantRecord]
    var highlightedPlantID: UUID? = nil
    let onStart: () -> Void
    let onStartWild: () -> Void
    let onSelectRecord: (PlantRecord) -> Void

    var body: some View {
        ZStack {
            ForestBackdrop()

            VStack(spacing: 0) {
                ForestHeader()
                    .padding(.top, 6)

                Spacer(minLength: 14)

                Group {
                    if plantedRecords.isEmpty {
                        EmptyForestStage()
                    } else {
                        PlantedForestStage(
                            records: plantedRecords,
                            highlightedPlantID: highlightedPlantID,
                            onSelectRecord: onSelectRecord
                        )
                        .frame(maxWidth: 430)
                    }
                }

                Spacer(minLength: 14)

                ForestDock(onStart: onStart, onStartWild: onStartWild)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 34)
        }
    }
}

// MARK: - 设计令牌（对齐 Design/figma-design-draft.html）

private enum ForestPalette {
    static let ink = Color(red: 0.043, green: 0.082, blue: 0.071)      // #0B1512
    static let moss = Color(red: 0.063, green: 0.141, blue: 0.114)     // #10241D
    static let forest = Color(red: 0.110, green: 0.227, blue: 0.173)   // #1C3A2C
    static let leaf = Color(red: 0.243, green: 0.420, blue: 0.310)     // #3E6B4F
    static let sage = Color(red: 0.498, green: 0.631, blue: 0.514)     // #7FA183
    static let mist = Color(red: 0.659, green: 0.784, blue: 0.627)     // #A8C8A0
    static let moon = Color(red: 0.929, green: 0.902, blue: 0.816)     // #EDE6D0
    static let amber = Color(red: 0.851, green: 0.643, blue: 0.255)    // #D9A441
    static let fire = Color(red: 0.949, green: 0.722, blue: 0.294)     // #F2B84B
    static let amberDeep = Color(red: 0.725, green: 0.494, blue: 0.180) // #B97E2E
    static let moonChip = Color(red: 0.949, green: 0.808, blue: 0.541) // #F2CE8A
    static let moonBright = Color(red: 1.000, green: 0.902, blue: 0.690) // #FFE6B0
    static let chipBg = Color(red: 0.047, green: 0.086, blue: 0.067)   // #0C1611
    static let horizon = Color(red: 0.227, green: 0.192, blue: 0.125)  // #3A3120
    static let ctaText = Color(red: 0.130, green: 0.080, blue: 0.000)  // #211500
}

// MARK: - 背景：渐变 + 月光 + 雾 + 萤火

private struct ForestBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ForestPalette.ink, ForestPalette.forest, ForestPalette.horizon],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [ForestPalette.moon.opacity(0.16), ForestPalette.moon.opacity(0)],
                center: UnitPoint(x: 0.82, y: 0.10),
                startRadius: 8,
                endRadius: 460
            )

            ForestMist()
            FireflyField()
        }
        .ignoresSafeArea()
    }
}

private struct ForestMist: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(ForestPalette.forest.opacity(0.16))
                .frame(width: 640, height: 110)
                .blur(radius: 44)
                .offset(x: -130, y: 260)
            Ellipse()
                .fill(ForestPalette.leaf.opacity(0.10))
                .frame(width: 720, height: 120)
                .blur(radius: 50)
                .offset(x: 140, y: 340)
            Ellipse()
                .fill(ForestPalette.amber.opacity(0.07))
                .frame(width: 560, height: 90)
                .blur(radius: 46)
                .offset(x: -70, y: 430)
        }
        .allowsHitTesting(false)
    }
}

private struct FireflyField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private struct Fly: Identifiable {
        let id: Int
        let nx: Double
        let ny: Double
        let size: CGFloat
        let delay: Double
    }

    private let flies: [Fly] = [
        Fly(id: 0, nx: 0.14, ny: 0.24, size: 5, delay: 0.2),
        Fly(id: 1, nx: 0.84, ny: 0.30, size: 4, delay: 1.4),
        Fly(id: 2, nx: 0.20, ny: 0.62, size: 4, delay: 2.6),
        Fly(id: 3, nx: 0.80, ny: 0.70, size: 5, delay: 0.9),
        Fly(id: 4, nx: 0.50, ny: 0.42, size: 3, delay: 3.1)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(flies) { fly in
                Circle()
                    .fill(ForestPalette.fire)
                    .frame(width: fly.size, height: fly.size)
                    .shadow(color: ForestPalette.fire.opacity(0.70), radius: 9)
                    .position(x: geo.size.width * fly.nx, y: geo.size.height * fly.ny)
                    .opacity(reduceMotion ? 0.5 : (pulse ? 0.85 : 0.20))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 3.4).repeatForever(autoreverses: true).delay(fly.delay),
                        value: pulse
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { pulse = true }
    }
}

// MARK: - 顶部品牌行

private struct ForestHeader: View {
    var body: some View {
        HStack(spacing: 9) {
            SeedMark()
                .frame(width: 26, height: 26)

            Text("声音森林")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ForestPalette.moon)

            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 13))
                .foregroundStyle(ForestPalette.mist)
                .frame(width: 30, height: 30)
                .background(ForestPalette.moon.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
        }
    }
}

// MARK: - 空森林：种子 + 声音波纹 + 主题句

private struct EmptyForestStage: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                SoundRipples()
                SeedMark()
                    .frame(width: 150, height: 150)
            }
            .frame(width: 150, height: 150)

            Text("每一种声音，\n都可以生长。")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(ForestPalette.moon)
                .shadow(color: .black.opacity(0.35), radius: 24)

            Text("这里还没有植物 · 用你的声音种下第一棵")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(ForestPalette.moon.opacity(0.62))
        }
        .padding(.top, 10)
    }
}

private struct SoundRipples: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cycle = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(ForestPalette.amber.opacity(0.34), lineWidth: 1)
                    .frame(width: 104, height: 104)
                    .scaleEffect(cycle ? 1.28 : 0.55)
                    .opacity(cycle ? 0 : 0.85)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 3.2).repeatForever(autoreverses: false).delay(Double(index) * 1.07),
                        value: cycle
                    )
            }
        }
        .onAppear { cycle = true }
        .accessibilityHidden(true)
    }
}

// MARK: - 森林：林中空地面板 + 植物网格

private struct PlantedForestStage: View {
    let records: [PlantRecord]
    let highlightedPlantID: UUID?
    let onSelectRecord: (PlantRecord) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var highlightedRecord: PlantRecord? {
        records.first { $0.id == highlightedPlantID }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                ForestCountChip(count: records.count)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        ForEach(records) { record in
                            PlantedPlantTile(
                                plant: record.plant,
                                isWild: record.growthMode.isWild,
                                isHighlighted: highlightedPlantID == record.id,
                                reduceMotion: reduceMotion
                            )
                            .onTapGesture {
                                onSelectRecord(record)
                            }
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 2)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8),
                        value: records.map(\.id)
                    )
                }
                .frame(maxHeight: 400)
            }
            .padding(14)
            .background(ForestPalette.ink.opacity(0.42), in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                if let record = highlightedRecord {
                    NewPlantChip(record: record)
                        .offset(y: -16)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                }
            }

            Text("点开任意一棵，回听它的声音")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(ForestPalette.moon.opacity(0.52))
        }
    }
}

private struct ForestCountChip: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ForestPalette.fire)
                .frame(width: 6, height: 6)
                .shadow(color: ForestPalette.fire, radius: 5)

            Text("森林里有 \(count) 棵植物")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ForestPalette.moonChip)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(ForestPalette.amber.opacity(0.14), in: Capsule())
        .overlay {
            Capsule().stroke(ForestPalette.amber.opacity(0.32), lineWidth: 1)
        }
    }
}

private struct NewPlantChip: View {
    let record: PlantRecord

    var body: some View {
        VStack(spacing: 4) {
            Text("新种下 · \(record.plant.name)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ForestPalette.moonBright)

            Text(dnaSummary(record.plant.profile))
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundStyle(ForestPalette.amber.opacity(0.78))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ForestPalette.chipBg.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(ForestPalette.amber.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }

    private func dnaSummary(_ profile: SoundProfile) -> String {
        let energy = String(format: "Energy %.2f", profile.energy)
        let freq = profile.spectralCentroidHz.map { String(format: "%.0f Hz", $0) } ?? "— Hz"
        let duration = String(format: "%.0fs", profile.duration)
        return "\(energy) · \(freq) · \(duration)"
    }
}

private struct PlantedPlantTile: View {
    let plant: PlantModel
    let isWild: Bool
    let isHighlighted: Bool
    let reduceMotion: Bool
    @State private var entering = true

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if isHighlighted {
                    Circle()
                        .fill(ForestPalette.amber.opacity(entering ? 0.24 : 0.06))
                        .scaleEffect(entering ? 0.72 : 1.15)
                        .blur(radius: 8)
                }

                PlantRenderer(structure: plant.structure)
                    .frame(height: 92)

                if isWild {
                    VStack {
                        HStack {
                            Spacer()
                            Text("⚡")
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.28), in: Capsule())
                        }
                        Spacer()
                    }
                }
            }

            Text(plant.name)
                .font(.footnote)
                .foregroundStyle(ForestPalette.moon.opacity(isHighlighted ? 0.95 : 0.78))
                .lineLimit(1)
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [
                    ForestPalette.amber.opacity(isHighlighted ? 0.14 : 0),
                    Color.white.opacity(0.045)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isHighlighted ? ForestPalette.amber.opacity(0.72) : Color.white.opacity(0.055),
                    lineWidth: isHighlighted ? 1.4 : 1
                )
        }
        .scaleEffect(isHighlighted && entering && !reduceMotion ? 0.92 : 1)
        .onAppear {
            guard isHighlighted, !reduceMotion else {
                entering = false
                return
            }
            withAnimation(.easeOut(duration: 0.75)) {
                entering = false
            }
        }
    }
}

// MARK: - 底部操作区

private struct ForestDock: View {
    let onStart: () -> Void
    let onStartWild: () -> Void

    var body: some View {
        VStack(spacing: 11) {
            Button(action: onStart) {
                VStack(spacing: 4) {
                    Text("种一棵声音树")
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [ForestPalette.fire, ForestPalette.amber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(ForestPalette.ctaText)
                        .shadow(color: ForestPalette.amber.opacity(0.28), radius: 18, y: 8)

                    Text("让声音慢慢长成自己的形状")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(ForestPalette.moon.opacity(0.50))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Echo 模式：用声音慢慢种下一棵树")

            Button(action: onStartWild) {
                VStack(spacing: 4) {
                    Text("⚡ 暴走森林")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(ForestPalette.moon.opacity(0.05), in: Capsule())
                        .overlay {
                            Capsule().stroke(ForestPalette.amber.opacity(0.45), lineWidth: 1)
                        }
                        .foregroundStyle(ForestPalette.moon)

                    Text("这次，看看谁控制谁")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(ForestPalette.amber.opacity(0.62))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Wild 模式：用声音驯服一棵失控的树")
        }
    }
}

// MARK: - 种子

struct SeedMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ForestPalette.moon.opacity(0.08))

            Circle()
                .strokeBorder(ForestPalette.moon.opacity(0.26), lineWidth: 1)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [ForestPalette.amber, ForestPalette.leaf],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .frame(width: 44, height: 68)
                .rotationEffect(.degrees(-18))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
        }
        .accessibilityLabel("种子")
    }
}
