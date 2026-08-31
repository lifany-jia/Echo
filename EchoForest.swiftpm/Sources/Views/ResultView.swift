import SwiftUI

struct ResultView: View {
    let plant: MockPlantModel
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

            VStack(spacing: 18) {
                Text(plant.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Mock 最终植物")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))

                MockPlantCanvas(plant: plant, progress: 1, showsBloom: true)
                    .frame(maxHeight: 330)

                SoundDNAView(profile: plant.profile)

                Button(action: onPlantInForest) {
                    Text("种进森林")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.46, green: 0.67, blue: 0.39))
            }
            .padding(28)
        }
    }
}

private struct SoundDNAView: View {
    let profile: MockSoundProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mock Sound DNA")
                .font(.headline)
                .foregroundStyle(.white)

            DNAValueRow(label: "Pitch", value: profile.pitch)
            DNAValueRow(label: "Energy", value: profile.energy)
            DNAValueRow(label: "Rhythm", value: profile.rhythm)
            DNAValueRow(label: "Variation", value: profile.variation)
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct DNAValueRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 72, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))

                    Capsule()
                        .fill(Color(red: 0.86, green: 0.70, blue: 0.40))
                        .frame(width: geometry.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 8)

            Text("\(Int(value * 100))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 32, alignment: .trailing)
        }
    }
}
