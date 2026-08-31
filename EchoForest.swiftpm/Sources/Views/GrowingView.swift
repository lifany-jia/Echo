import SwiftUI

struct GrowingView: View {
    let plant: PlantModel
    let growthStep: Int
    let isListening: Bool
    let receivedBufferCount: Int
    let lastFrameLength: Int?
    let energy: Double
    let spectralCentroidHz: Double?
    let onsetCount: Int
    let duration: TimeInterval
    let mode: GrowthMode
    let wild: WildSession?
    let onFinish: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealSteps: Double = 0
    @State private var feedback: FeedbackPhrase = .none
    @State private var lastSeenOnsetCount = 0
    @State private var onsetFlashUntil = Date.distantPast
    @State private var silenceTicks = 0

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.11, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text(mode.isWild ? "驯服失控的树" : "生长中")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(mode.isWild ? "它不听指挥，但你的声音就是缰绳" : "植物随声音实时生长 · 静音时停止")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                }

                ListeningBadge(isListening: isListening)

                PlantRenderer(structure: plant.structure, revealSteps: revealSteps)
                    .frame(width: 260, height: 340)
                    .padding(.vertical, 2)

                if mode.isWild {
                    WildPanel(wild: wild)
                } else {
                    feedbackLine
                }

                CompactMetricsRow(
                    energy: energy,
                    spectralCentroidHz: spectralCentroidHz,
                    onsetCount: onsetCount,
                    duration: duration
                )

                if debugUIEnabled {
                    Text("debug · buffer \(receivedBufferCount) · frame \(lastFrameLength.map(String.init) ?? "-")")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.35))
                }

                Button(action: onFinish) {
                    Text(mode.isWild ? "驯服完成 · 查看结果" : "结束并查看结果")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode.isWild ? Color(red: 0.82, green: 0.52, blue: 0.28) : Color(red: 0.78, green: 0.59, blue: 0.34))

                Button("取消", action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(22)
        }
        .onAppear {
            revealSteps = reduceMotion ? Double(growthStep) : Double(growthStep)
        }
        .onChange(of: growthStep) { _, newValue in
            if reduceMotion {
                revealSteps = Double(newValue)
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    revealSteps = Double(newValue)
                }
            }
        }
        .task(id: "feedback") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                updateFeedback()
            }
        }
        .onChange(of: onsetCount) { _, newValue in
            guard newValue > lastSeenOnsetCount, !reduceMotion else { return }
            revealSteps = max(0, Double(growthStep) - 0.75)
            withAnimation(.easeOut(duration: 0.55)) {
                revealSteps = Double(growthStep)
            }
        }
    }

    private enum FeedbackPhrase: Equatable {
        case none
        case silence
        case power
        case upward
        case flower

        var text: String {
            switch self {
            case .none: return ""
            case .silence: return "再给它一点声音"
            case .power: return "声音让枝干更有力量"
            case .upward: return "声音让它向上生长"
            case .flower: return "它开出了一朵花"
            }
        }
    }

    @ViewBuilder
    private var feedbackLine: some View {
        Text(feedback.text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(red: 0.86, green: 0.78, blue: 0.55))
            .opacity(feedback == .none ? 0 : 1)
            .frame(height: 22)
            .animation(.easeInOut(duration: 0.3), value: feedback)
    }

    private func updateFeedback() {
        let now = Date()

        if onsetCount > lastSeenOnsetCount {
            lastSeenOnsetCount = onsetCount
            onsetFlashUntil = now.addingTimeInterval(2.5)
            feedback = .flower
            silenceTicks = 0
            return
        }

        if now < onsetFlashUntil {
            feedback = .flower
            return
        }

        guard isListening else {
            feedback = .none
            return
        }

        if energy < 0.05 {
            silenceTicks += 1
            feedback = silenceTicks >= 6 ? .silence : .none
        } else {
            silenceTicks = 0
            if energy > 0.45 {
                feedback = .power
            } else if let centroid = spectralCentroidHz, centroid > 1500 {
                feedback = .upward
            } else {
                feedback = .none
            }
        }
    }

    private var debugUIEnabled: Bool {
        ProcessInfo.processInfo.environment["ECHO_FOREST_DEBUG_UI"] == "1"
    }
}

/// Wild Mode 的挑战 / 倒计时 / 暴走 / 冷静提示面板。
/// 没有 Wrong / Failed / ❌ / 分数：挑战未达成只是不显示成功。
private struct WildPanel: View {
    let wild: WildSession?

    var body: some View {
        VStack(spacing: 6) {
            if let wild {
                switch wild.phase {
                case .opening:
                    phaseText("给它一点声音……")
                case .countdown(let remaining):
                    VStack(spacing: 2) {
                        Text("别让它失控！")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.94, green: 0.72, blue: 0.48))
                        Text("\(remaining)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                case .challenge(let challenge, let succeeded):
                    VStack(spacing: 3) {
                        Text(challenge.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(succeeded ? challenge.successText : challenge.hint)
                            .font(.footnote)
                            .foregroundStyle(succeeded ? Color(red: 0.62, green: 0.88, blue: 0.55) : .white.opacity(0.62))
                    }
                case .burst:
                    VStack(spacing: 2) {
                        Text("暴走！")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.30))
                        Text("别让它失控！")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                case .calm, .done:
                    phaseText("呼……它冷静下来了。")
                }

                if !wild.isComplete {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(Color(red: 0.86, green: 0.62, blue: 0.34))
                                .frame(width: geometry.size.width * wild.progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 4)
                }
            } else {
                phaseText("")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 54)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func phaseText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.82))
    }
}

private struct ListeningBadge: View {
    let isListening: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isListening ? Color(red: 0.55, green: 0.88, blue: 0.45) : Color.orange)
                .frame(width: 9, height: 9)

            Text(isListening ? "聆听中" : "正在启动麦克风…")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.07), in: Capsule())
    }
}

/// 次要的紧凑指标：能量条 + 频域（低/中/高）+ 开花数 + 时长。
private struct CompactMetricsRow: View {
    let energy: Double
    let spectralCentroidHz: Double?
    let onsetCount: Int
    let duration: TimeInterval

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("能量")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(Color(red: 0.70, green: 0.76, blue: 0.42))
                            .frame(width: geometry.size.width * min(max(energy, 0), 1))
                    }
                }
                .frame(width: 74, height: 6)
            }

            metricItem("频率", SoundPresentation.frequencyBandShort(spectralCentroidHz))
            metricItem("开花", "\(onsetCount)")
            metricItem("时长", String(format: "%.0f秒", duration))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metricItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
