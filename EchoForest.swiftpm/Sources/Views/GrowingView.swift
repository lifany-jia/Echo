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
    let gestures: SoundGestures
    let justResumedFromPause: Bool
    let onFinish: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealSteps: Double = 0
    @State private var phrase: EchoPhrase = .none
    @State private var phraseUntil = Date.distantPast
    @State private var shownHints: Set<String> = []
    @State private var lastSeenOnsetCount = 0
    @State private var onsetFlashUntil = Date.distantPast
    @State private var silenceTicks = 0
    @State private var appearedAt = Date()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.082, blue: 0.071),
                    Color(red: 0.09, green: 0.18, blue: 0.14),
                    mode.isWild
                        ? Color(red: 0.28, green: 0.18, blue: 0.09)
                        : Color(red: 0.16, green: 0.22, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text(mode.isWild ? "驯服失控的树" : "用声音，种一棵树")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82))

                    Text(mode.isWild ? "它不听指挥，但你的声音就是缰绳" : "声音慢慢长成自己的形状 · 静音时停止")
                        .font(.footnote)
                        .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.55))
                }

                ListeningBadge(isListening: isListening)

                PlantRenderer(structure: plant.structure, revealSteps: revealSteps)
                    .frame(width: 260, height: 340)
                    .padding(.vertical, 2)

                if mode.isWild {
                    WildPanel(wild: wild)
                } else {
                    echoPhraseLine
                }

                CompactMetricsRow(
                    energy: energy,
                    spectralCentroidHz: spectralCentroidHz,
                    onsetCount: onsetCount,
                    duration: duration
                )

                if debugUIEnabled {
                    Text("debug · buffer \(receivedBufferCount) · frame \(lastFrameLength.map(String.init) ?? "-") · trend \(gestures.energyTrend.rawValue) · rhythm \(gestures.rhythm.rawValue)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.35))
                }

                Button(action: onFinish) {
                    Text(mode.isWild ? "提前结束 · 查看结果" : "结束并查看结果")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode.isWild ? Color(red: 0.82, green: 0.52, blue: 0.28) : Color(red: 0.78, green: 0.59, blue: 0.34))

                Button("取消", action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.65))
            }
            .padding(22)
        }
        .onAppear {
            revealSteps = Double(growthStep)
            appearedAt = Date()
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
        .task(id: "echo-feedback") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                updateEchoFeedback()
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

    // MARK: - Echo 提示引擎

    private enum EchoPhrase: Equatable {
        case none
        case silence
        case power
        case upward
        case flower
        case fellLeft
        case roseRight
        case branching
        case pause
        case resume
        case guide

        var text: String {
            switch self {
            case .none: return ""
            case .silence: return "再给它一点声音"
            case .power: return "声音让枝干更有力量"
            case .upward: return "声音越明亮，它越往上"
            case .flower: return "它开出了一朵花"
            case .fellLeft: return "它往左去了。"
            case .roseRight: return "它往右去了。"
            case .branching: return "它开始分叉了。"
            case .pause: return "停顿 = 结束这一笔。"
            case .resume: return "新的一笔开始了。"
            case .guide: return "试着让声音慢慢变小。"
            }
        }
    }

    @ViewBuilder
    private var echoPhraseLine: some View {
        Text(phrase.text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(red: 0.86, green: 0.78, blue: 0.55))
            .opacity(phrase == .none ? 0 : 1)
            .frame(height: 22)
            .animation(.easeInOut(duration: 0.3), value: phrase)
    }

    private func updateEchoFeedback() {
        guard !mode.isWild else { return }
        let now = Date()

        // 一次性短提示过期后自动清空。
        if now >= phraseUntil {
            phrase = .none
        }

        // 拍手 / 敲桌是最明确的动作：闪烁“开花”。
        if onsetCount > lastSeenOnsetCount {
            lastSeenOnsetCount = onsetCount
            onsetFlashUntil = now.addingTimeInterval(2.5)
            show(phrase: .flower, until: now.addingTimeInterval(2.5), key: nil)
            return
        }
        if now < onsetFlashUntil {
            phrase = .flower
            phraseUntil = onsetFlashUntil
            return
        }

        guard isListening else {
            if phrase == .none {
                phrase = .none
            }
            return
        }

        // 停顿 = 结束这一笔；恢复 = 新一笔。
        if justResumedFromPause {
            show(phrase: .resume, until: now.addingTimeInterval(2.2), key: "resume")
            return
        }
        if gestures.isPaused {
            show(phrase: .pause, until: now.addingTimeInterval(2.2), key: "pause")
            return
        }

        // 声音手势反馈（各触发一次后消失）。
        if gestures.energyTrend == .falling, gestures.trendConfidence > 0.45 {
            show(phrase: .fellLeft, until: now.addingTimeInterval(2.2), key: "left")
            return
        }
        if gestures.energyTrend == .rising, gestures.trendConfidence > 0.45 {
            show(phrase: .roseRight, until: now.addingTimeInterval(2.2), key: "right")
            return
        }
        if gestures.variationLevel == .medium || gestures.variationLevel == .high {
            show(phrase: .branching, until: now.addingTimeInterval(2.2), key: "branch")
            return
        }
        if let centroid = spectralCentroidHz, centroid > 1500 {
            show(phrase: .upward, until: now.addingTimeInterval(2.2), key: "up")
            return
        }

        // 静音 / 首次引导。
        if energy < 0.05 {
            silenceTicks += 1
            phrase = silenceTicks >= 6 ? .silence : .none
        } else {
            silenceTicks = 0
            if energy > 0.45 {
                phrase = .power
            } else {
                phrase = .none
            }
        }

        // 开场引导：2.5 秒后如果还没有任何手势，提示第一个动作。
        let noGestureYet = shownHints.isDisjoint(with: ["left", "right", "up", "branch", "pause", "resume"])
        if now.timeIntervalSince(appearedAt) > 2.5, noGestureYet {
            show(phrase: .guide, until: now.addingTimeInterval(2.6), key: "guide")
        }
    }

    private func show(phrase newPhrase: EchoPhrase, until: Date, key: String?) {
        if let key {
            guard !shownHints.contains(key) else { return }
            shownHints.insert(key)
        }
        phrase = newPhrase
        phraseUntil = until
    }

    private var debugUIEnabled: Bool {
        ProcessInfo.processInfo.environment["ECHO_FOREST_DEBUG_UI"] == "1"
    }
}

/// Wild Mode 的开场 / 倒计时 / 挑战 / Free For All / 结尾面板。
/// 没有 Wrong / Failed / ❌ / 分数：挑战未达成只是不显示成功；失败本身会变成有趣反馈。
private struct WildPanel: View {
    let wild: WildSession?

    var body: some View {
        VStack(spacing: 6) {
            if let wild {
                switch wild.phase {
                case .opening:
                    VStack(spacing: 2) {
                        phaseText("这颗种子有点不对劲。")
                        phaseText("先别吵醒它。", dimmed: true)
                    }
                case .countdown(let remaining):
                    VStack(spacing: 2) {
                        phaseText("它要醒了…")
                        Text("\(remaining)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.66))
                            .contentTransition(.numericText())
                    }
                case .jerk:
                    VStack(spacing: 2) {
                        Text("⚡")
                            .font(.title2)
                        phaseText("糟了。")
                            .fontWeight(.semibold)
                    }
                case .challenge(let challenge, let succeeded):
                    challengeContent(challenge, succeeded: succeeded, wild: wild)
                case .freeForAll:
                    VStack(spacing: 3) {
                        Text(wild.freeForAllProgress01 < 0.22 ? "等等……它好像听上瘾了。" : "⚡ 随便来点什么！！")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.36))
                            .multilineTextAlignment(.center)
                        phaseText("所有声音都在长 · 别停！", dimmed: true)
                    }
                case .ending, .done:
                    VStack(spacing: 2) {
                        phaseText("嗯……")
                        phaseText("确实很像你。")
                            .fontWeight(.semibold)
                    }
                }

                if !wild.isComplete {
                    VStack(spacing: 3) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.12))
                                Capsule()
                                    .fill(Color(red: 0.86, green: 0.62, blue: 0.34))
                                    .frame(width: geometry.size.width * wild.progress)
                            }
                        }
                        .frame(height: 4)

                        if case .challenge = wild.phase {
                            Text("声音动作 \(wild.challengeOrdinal) / \(wild.challengeTotal)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.45))
                        }
                    }
                }
            } else {
                phaseText("")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 62)
        .background(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func challengeContent(_ challenge: WildChallenge, succeeded: Bool, wild: WildSession) -> some View {
        VStack(spacing: 3) {
            Text(challenge.prompt)
                .font(.caption)
                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.55))

            Text(challenge.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82))
                .multilineTextAlignment(.center)

            if challenge == .silence, wild.silenceCaught, !succeeded {
                Text("它听见了。")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.40))
            } else if challenge == .bloom, wild.bloomStage == 1, !succeeded {
                Text("就这？")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.44))
            } else {
                Text(succeeded ? challenge.successText : challenge.hint)
                    .font(.footnote)
                    .foregroundStyle(succeeded ? Color(red: 0.62, green: 0.88, blue: 0.55) : Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.62))
            }
        }
    }

    private func phaseText(_ text: String, dimmed: Bool = false) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(dimmed ? 0.62 : 0.82))
            .multilineTextAlignment(.center)
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
                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.07), in: Capsule())
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
                    .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.55))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.12))
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
        .background(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metricItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.9))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.5))
        }
    }
}
