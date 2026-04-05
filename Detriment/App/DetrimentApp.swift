import SwiftUI
import StoreKit

@main
struct DetrimentApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasPurchased") private var hasPurchased = false

    init() {
        NotificationManager.shared.requestPermission()
        BackgroundScanner.shared.registerBackgroundTask()
        checkExistingPurchase()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                } else if !hasPurchased {
                    PaywallView(hasPurchased: $hasPurchased)
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

    private func checkExistingPurchase() {
        Task {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == "com.detriment.app.unlock" {
                        await MainActor.run { hasPurchased = true }
                    }
                }
            }
        }
    }
}
