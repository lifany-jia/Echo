import SwiftUI

struct PlantDetailView: View {
    let record: PlantRecord
    let audioAvailable: Bool
    let isPlaying: Bool
    let onTogglePlayback: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.10, blue: 0.09),
                    Color(red: 0.14, green: 0.22, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Button("返回", action: onBack)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                }

                PlantArtworkView(plant: record.plant, mode: record.growthMode)
                    .frame(width: 270, height: 280)
                    .scaleEffect(isPlaying ? 1.018 : 1)
                    .brightness(isPlaying ? 0.035 : 0)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPlaying)

                Text(record.plant.name)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)

                Text(record.growthMode.displayName + (record.growthMode.isWild ? " ⚡" : ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(record.growthMode.isWild ? Color(red: 0.72, green: 0.42, blue: 0.22).opacity(0.35) : .white.opacity(0.10), in: Capsule())

                if record.growthMode.isWild {
                    Text("你驯服了一棵失控的声音树。")
                        .font(.footnote)
                        .foregroundStyle(Color(red: 0.88, green: 0.66, blue: 0.40))
                }

                Text(createdAtText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.56))

                SoundDNAView(
                    profile: record.soundProfile,
                    personality: SoundPresentation.personality(for: record.soundProfile, isWild: record.growthMode.isWild)
                )

                Button(action: onTogglePlayback) {
                    Text(isPlaying ? "暂停" : "听听它的声音")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.78, green: 0.59, blue: 0.34))
                .disabled(!audioAvailable)
                .opacity(audioAvailable ? 1 : 0.45)

                if !audioAvailable {
                    Text("这株植物没有可播放的本地录音")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private var createdAtText: String {
        guard record.createdAt != .distantPast else { return "创建时间未记录" }
        return Self.dateFormatter.string(from: record.createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
