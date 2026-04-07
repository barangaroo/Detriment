import SwiftUI

@main
struct DetrimentApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var scanner = NetworkScanner()

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
                    MainView(scanner: scanner)
                        .onAppear {
                            BackgroundScanner.shared.scheduleBackgroundScan()
                        }
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                guard url.scheme == "detriment", url.host == "scan" else { return }
                if hasSeenOnboarding {
                    scanner.startScan()
                }
            }
        }
    }
}
