import SwiftUI

struct GrowingView: View {
    let plant: MockPlantModel
    let isListening: Bool
    let receivedBufferCount: Int
    let lastFrameLength: Int?
    let energy: Double
    let spectralCentroidHz: Double?
    let onsetCount: Int
    let duration: TimeInterval
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.11, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("生长中")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Plant growth is still mock · 植物生长仍为 mock（Stage 3）")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }

                ListeningBadge(isListening: isListening)

                MockPlantCanvas(plant: plant, progress: 0.72, showsBloom: false)
                    .frame(maxHeight: 300)
                    .padding(.vertical, 6)

                LiveMetricsPanel(
                    energy: energy,
                    spectralCentroidHz: spectralCentroidHz,
                    onsetCount: onsetCount,
                    duration: duration
                )

                Text("Stage 2 链路验证 · 收到 buffer: \(receivedBufferCount) · 最近 frameLength: \(lastFrameLength.map(String.init) ?? "-")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))

                Button(action: onFinish) {
                    Text("结束并查看结果")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.78, green: 0.59, blue: 0.34))

                Button("取消", action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(28)
        }
    }
}

private struct ListeningBadge: View {
    let isListening: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isListening ? Color(red: 0.55, green: 0.88, blue: 0.45) : Color.orange)
                .frame(width: 10, height: 10)

            Text(isListening ? "Listening · 麦克风输入已启动" : "正在启动麦克风…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
    }
}

private struct LiveMetricsPanel: View {
    let energy: Double
    let spectralCentroidHz: Double?
    let onsetCount: Int
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Metrics (Stage 3)")
                .font(.headline)
                .foregroundStyle(.white)

            MetricBarRow(label: "Energy", value: energy)
            MetricTextRow(
                label: "Spectral Centroid",
                value: spectralCentroidHz.map { String(format: "%.0f Hz", $0) } ?? "—"
            )
            MetricTextRow(label: "Onset count", value: "\(onsetCount)")
            MetricTextRow(label: "Duration", value: String(format: "%.1f s", duration))
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

private struct MetricBarRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                        .fill(Color(red: 0.70, green: 0.76, blue: 0.42))
                        .frame(width: geometry.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct MetricTextRow: View {
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
