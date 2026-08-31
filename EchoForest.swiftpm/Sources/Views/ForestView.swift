import SwiftUI

struct ForestView: View {
    let plantedPlants: [PlantModel]
    let onStart: () -> Void

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

                if plantedPlants.isEmpty {
                    EmptyForestPlot()
                        .frame(maxWidth: 360)
                } else {
                    PlantedForestGrid(plants: plantedPlants)
                }

                Spacer(minLength: 8)

                Button(action: onStart) {
                    Text("种下一段声音")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.46, green: 0.67, blue: 0.39))
                .controlSize(.large)
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
    let plants: [PlantModel]

    var body: some View {
        VStack(spacing: 12) {
            Text("已种下 \(plants.count) 棵植物")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.88))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                ForEach(plants) { plant in
                    VStack(spacing: 6) {
                        PlantRenderer(structure: plant.structure)
                            .frame(height: 110)

                        Text(plant.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                }
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
        .accessibilityLabel("静态种子")
    }
}
