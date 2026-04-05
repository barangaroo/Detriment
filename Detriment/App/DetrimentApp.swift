import SwiftUI

@main
struct DetrimentApp: App {
    init() {
        NotificationManager.shared.requestPermission()
        BackgroundScanner.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
                .onAppear {
                    BackgroundScanner.shared.scheduleBackgroundScan()
                }
        }
    }
}
