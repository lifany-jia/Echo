import SwiftUI

struct ForestView: View {
    let plantedRecords: [PlantRecord]
    var highlightedPlantID: UUID? = nil
    let onStart: () -> Void
    let onStartWild: () -> Void
    let onSelectRecord: (PlantRecord) -> Void

    var body: some View {
        ZStack {
            ForestBackground()

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("声音森林")
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("每一种声音，都可以生长。")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 8)

                if plantedRecords.isEmpty {
                    EmptyForestPlot()
                        .frame(maxWidth: 360)
                } else {
                    PlantedForestGrid(
                        records: plantedRecords,
                        highlightedPlantID: highlightedPlantID,
                        onSelectRecord: onSelectRecord
                    )
                }

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Button(action: onStart) {
                        Text("种下一段声音")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.46, green: 0.67, blue: 0.39))
                    .controlSize(.large)

                    Button(action: onStartWild) {
                        Text("⚡ 让它暴走")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.86, green: 0.62, blue: 0.34))
                }
            }
            .padding(28)
        }
    }
}

private struct ForestBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.09, blue: 0.08),
                Color(red: 0.09, green: 0.19, blue: 0.15),
                Color(red: 0.78, green: 0.64, blue: 0.38)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct EmptyForestPlot: View {
    var body: some View {
        VStack(spacing: 16) {
            SeedMark()
                .frame(width: 112, height: 112)

            Text("这里还没有植物")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(28)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct PlantedForestGrid: View {
    let records: [PlantRecord]
    let highlightedPlantID: UUID?
    let onSelectRecord: (PlantRecord) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Text("森林里有 \(records.count) 棵植物")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 14) {
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
            .frame(maxHeight: 380)
        }
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
                        .fill(Color(red: 0.78, green: 0.72, blue: 0.42).opacity(entering ? 0.24 : 0.06))
                        .scaleEffect(entering ? 0.72 : 1.15)
                        .blur(radius: 8)
                }

                PlantRenderer(structure: plant.structure)
                    .frame(height: 112)

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
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
        }
        .padding(10)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
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

struct SeedMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.10))

            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.76, blue: 0.43),
                            Color(red: 0.40, green: 0.69, blue: 0.43)
                        ],
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
