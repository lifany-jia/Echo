import SwiftUI

struct SeedView: View {
    let mode: GrowthMode
    let isStarting: Bool
    let onStartGrowing: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

                Text(mode.isWild ? "用声音驯服它 · 首次开始会请求麦克风权限" : "首次开始会请求麦克风权限。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

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
}
