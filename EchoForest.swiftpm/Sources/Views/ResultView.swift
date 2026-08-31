import SwiftUI

struct ResultView: View {
    let plant: PlantModel
    let mode: GrowthMode
    let onPlantInForest: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.11, blue: 0.10),
                    Color(red: 0.15, green: 0.24, blue: 0.19)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                ScrollView {
                    VStack(spacing: 10) {
                        PlantRenderer(structure: plant.structure)
                            .frame(width: 260, height: 250)
                            .padding(.top, 4)

                        Text(plant.name)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(SoundPresentation.personality(for: plant.profile, isWild: mode.isWild))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(mode.isWild ? Color(red: 0.95, green: 0.72, blue: 0.44) : Color(red: 0.86, green: 0.78, blue: 0.55))

                        Text(mode.isWild ? "你驯服了一棵失控的声音树。" : "这是你的声音长成的植物")
                            .font(.subheadline)
                            .foregroundStyle(mode.isWild ? Color(red: 0.88, green: 0.66, blue: 0.40) : .white.opacity(0.6))

                        Text(mode.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(mode.isWild ? Color(red: 0.72, green: 0.42, blue: 0.22).opacity(0.35) : .white.opacity(0.10), in: Capsule())

                        Text(SoundPresentation.summary(for: plant.profile))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 12)

                        SoundDNAView(profile: plant.profile, personality: nil)
                    }
                    .padding(.top, 18)
                }

                Button(action: onPlantInForest) {
                    Text("种进森林")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.46, green: 0.67, blue: 0.39))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
