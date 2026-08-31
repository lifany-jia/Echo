import SwiftUI

struct ForestView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.08),
                    Color(red: 0.09, green: 0.19, blue: 0.15),
                    Color(red: 0.80, green: 0.64, blue: 0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Text("声音森林")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("每一种声音，都可以生长。")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.82))
                }

                SeedMark()
                    .frame(width: 116, height: 116)
                    .accessibilityHidden(true)

                Spacer()
            }
            .padding(32)
        }
    }
}

private struct SeedMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.10))

            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.76, blue: 0.43),
                            Color(red: 0.40, green: 0.69, blue: 0.43)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .frame(width: 44, height: 68)
                .rotationEffect(.degrees(-18))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
        }
    }
}
