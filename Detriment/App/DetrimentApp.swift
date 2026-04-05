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
            if hasSeenOnboarding {
                MainView()
                    .preferredColorScheme(.dark)
                    .onAppear {
                        BackgroundScanner.shared.scheduleBackgroundScan()
                    }
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
