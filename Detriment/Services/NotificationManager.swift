import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
    }

    func notifyNewDevice(_ device: NetworkDevice) {
        let content = UNMutableNotificationContent()
        content.title = "Someone new on your WiFi"
        content.body = "\(device.displayName) just connected. Open Detriment to check it out."
        content.sound = .default

        if device.riskLevel >= .medium {
            content.subtitle = "This one looks suspicious"
        }

        // Use MAC or IP as identifier to avoid duplicate notifications
        let identifier = device.macAddress ?? device.ipAddress
        let request = UNNotificationRequest(
            identifier: "new-device-\(identifier)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyMultipleNewDevices(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New devices on your WiFi"
        content.body = "\(count) devices you haven't seen before just showed up"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "new-devices-batch-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
