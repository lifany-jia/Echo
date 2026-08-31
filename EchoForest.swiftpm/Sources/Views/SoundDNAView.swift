import SwiftUI

struct SoundDNAView: View {
    let profile: SoundProfile
    var personality: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let personality {
                Text(personality)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.62))
                    .padding(.bottom, 2)
            }

            Text("Sound DNA")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.9))

            DNABarRow(label: "能量", value: profile.energy)
            DNABandRow(label: "频率特性", band: SoundPresentation.frequencyBandShort(profile.spectralCentroidHz))
            DNAValueRow(label: "节奏", value: profile.onsetCount > 0 ? "开过 \(profile.onsetCount) 次花" : "平稳")
            DNABarRow(label: "变化", value: profile.variation)
            DNAValueRow(label: "时长", value: String(format: "%.0f 秒", profile.duration))
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct DNABarRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(String(format: "%.2f", min(max(value, 0), 1)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(Color(red: 0.86, green: 0.70, blue: 0.40))
                        .frame(width: geometry.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct DNABandRow: View {
    let label: String
    let band: String

    var body: some View {
        HStack {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            HStack(spacing: 4) {
                bandDot("低", active: band == "低")
                bandDot("中", active: band == "中")
                bandDot("高", active: band == "高")
            }
            Text(band == "—" ? "—" : band)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func bandDot(_ name: String, active: Bool) -> some View {
        Text(name)
            .font(.caption2)
            .foregroundStyle(active ? Color.black.opacity(0.8) : .white.opacity(0.4))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(active ? Color(red: 0.86, green: 0.70, blue: 0.40) : .white.opacity(0.08), in: Capsule())
    }
}

private struct DNAValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
