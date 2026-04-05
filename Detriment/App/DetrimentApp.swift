import SwiftUI

@main
struct DetrimentApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        NotificationManager.shared.requestPermission()
        BackgroundScanner.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                } else {
                    MainView()
                        .onAppear {
                            BackgroundScanner.shared.scheduleBackgroundScan()
                        }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
