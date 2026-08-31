import SwiftUI

struct ResultView: View {
    let plant: PlantModel
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
                Text(plant.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)

                Text("由实时声音耦合生长（Stage 5）")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.64))

                PlantRenderer(structure: plant.structure)
                    .frame(maxHeight: 280)

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
    let profile: SoundProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sound DNA · 会话 SoundProfile")
                .font(.headline)
                .foregroundStyle(.white)

            DNABarRow(label: "Energy", value: profile.energy)
            DNATextRow(
                label: "Spectral Centroid (Frequency)",
                value: profile.spectralCentroidHz.map { String(format: "%.0f Hz", $0) } ?? "—"
            )
            DNATextRow(label: "Onset", value: "\(profile.onsetCount)")
            DNATextRow(label: "Duration", value: String(format: "%.1f s", profile.duration))
            DNABarRow(label: "Variation", value: profile.variation)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct DNABarRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(String(format: "%.2f", min(max(value, 0), 1)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))

                    Capsule()
                        .fill(Color(red: 0.86, green: 0.70, blue: 0.40))
                        .frame(width: geometry.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 7)
        }
    }
}

private struct DNATextRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}
