import SwiftUI

struct SeedView: View {
    let onStartGrowing: () -> Void
    let onCancel: () -> Void

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

                Text("给它一点声音。")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)

                Text("首次开始会请求麦克风权限。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))

                Spacer()

                Button(action: onStartGrowing) {
                    Text("开始创作")
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
