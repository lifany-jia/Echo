import SwiftUI

struct SeedView: View {
    let mode: GrowthMode
    let isStarting: Bool
    let onStartGrowing: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("echo_forest_privacy_notice_ack") private var privacyAcknowledged = false
    @State private var breathing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.11),
                    Color(red: 0.18, green: 0.30, blue: 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Button("返回", action: onCancel)
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                }

                Spacer()

                SeedMark()
                    .frame(width: 168, height: 168)
                    .scaleEffect(breathing ? 1.06 : 1.0)
                    .opacity(breathing ? 1.0 : 0.92)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                            breathing = true
                        }
                    }

                Text(mode.isWild ? "它正在暴走……给它一点声音。" : "给它一点声音。")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)

                Text(mode.isWild ? "这次，看看谁控制谁" : "让声音慢慢长成自己的形状")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

                if !privacyAcknowledged {
                    privacyNotice
                }

                Spacer()

                Button(action: onStartGrowing) {
                    Text(
                        isStarting
                            ? "正在唤醒种子…"
                            : (mode.isWild ? "开始驯服" : "开始创作")
                    )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode.isWild ? Color(red: 0.82, green: 0.52, blue: 0.28) : Color(red: 0.46, green: 0.67, blue: 0.39))
                .disabled(isStarting)
            }
            .padding(28)
        }
    }

    /// 首次创作前的本地录音隐私说明：不上传、不联网、不偷偷录制。
    private var privacyNotice: some View {
        VStack(spacing: 8) {
            Text("声音只会保存在这台设备，用来留下这棵树的声音记忆。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Button("知道了") {
                privacyAcknowledged = true
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 0.86, green: 0.70, blue: 0.40))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(.white.opacity(0.10), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 8)
    }
}
