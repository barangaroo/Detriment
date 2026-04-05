import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    onboardingPage(
                        icon: "wifi.exclamationmark",
                        iconColor: .red,
                        title: "See who's on\nyour WiFi",
                        subtitle: "Discover every device connected to your network — phones, cameras, smart devices, and anything suspicious.",
                        page: 0
                    ).tag(0)

                    onboardingPage(
                        icon: "shield.lefthalf.filled",
                        iconColor: .orange,
                        title: "Know your\nrisk level",
                        subtitle: "Get a clear score showing how secure your network is. Tap any device to see exactly what's wrong and how to fix it.",
                        page: 1
                    ).tag(1)

                    onboardingPage(
                        icon: "bell.badge.fill",
                        iconColor: .yellow,
                        title: "Get alerted\ninstantly",
                        subtitle: "Detriment watches your network and notifies you when a new device connects. Know immediately if someone's on your WiFi.",
                        page: 2
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator + button
                VStack(spacing: 24) {
                    // Custom page dots
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.red : Color.white.opacity(0.2))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }

                    Button(action: {
                        if currentPage < 2 {
                            withAnimation { currentPage += 1 }
                        } else {
                            withAnimation { hasSeenOnboarding = true }
                        }
                    }) {
                        Text(currentPage == 2 ? "Get Started" : "Next")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 30)

                    if currentPage < 2 {
                        Button("Skip") {
                            withAnimation { hasSeenOnboarding = true }
                        }
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    private func onboardingPage(icon: String, iconColor: Color, title: String, subtitle: String, page: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(iconColor.opacity(0.2), lineWidth: 1)
                    .frame(width: 150, height: 150)

                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(subtitle)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
    }
}
