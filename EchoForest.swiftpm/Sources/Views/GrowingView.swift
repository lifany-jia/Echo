import SwiftUI

struct GrowingView: View {
    let plant: MockPlantModel
    let isListening: Bool
    let receivedBufferCount: Int
    let lastFrameLength: Int?
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

                    Text("植物视觉仍为静态模拟，不随声音变化。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }

                ListeningBadge(isListening: isListening)

                MockPlantCanvas(plant: plant, progress: 0.72, showsBloom: false)
                    .frame(maxHeight: 380)
                    .padding(.vertical, 12)

                MockGrowthMeter(profile: plant.profile)

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

private struct MockGrowthMeter: View {
    let profile: MockSoundProfile

    var body: some View {
        VStack(spacing: 10) {
            MockMeterRow(label: "Mock Energy", value: profile.energy)
            MockMeterRow(label: "Mock Variation", value: profile.variation)
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MockMeterRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))

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
