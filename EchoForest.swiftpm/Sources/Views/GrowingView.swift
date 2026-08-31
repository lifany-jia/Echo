import SwiftUI

struct GrowingView: View {
    let plant: MockPlantModel
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.11, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Mock 生长中")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("这是一段静态模拟，不是真实声音驱动。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                }

                MockPlantCanvas(plant: plant, progress: 0.72, showsBloom: false)
                    .frame(maxHeight: 420)
                    .padding(.vertical, 12)

                MockGrowthMeter(profile: plant.profile)

                Button(action: onFinish) {
                    Text("结束并查看结果")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.78, green: 0.59, blue: 0.34))
            }
            .padding(28)
        }
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
