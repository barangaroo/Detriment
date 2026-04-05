import Foundation

/// Persists known devices so we can detect new ones across scans.
final class DeviceStorage {
    static let shared = DeviceStorage()

    private let defaults: UserDefaults
    private let knownDevicesKey = "knownDevices"
    private let lastScanKey = "lastScanDate"

    init() {
        // Use app group for widget access
        if let groupDefaults = UserDefaults(suiteName: "group.com.detriment.app") {
            self.defaults = groupDefaults
        } else {
            self.defaults = .standard
        }
    }

    // MARK: - Known Devices

    var knownDeviceMACs: Set<String> {
        Set(defaults.stringArray(forKey: knownDevicesKey) ?? [])
    }

    func markAsKnown(_ mac: String) {
        var known = knownDeviceMACs
        known.insert(mac)
        defaults.set(Array(known), forKey: knownDevicesKey)
    }

    func markAllAsKnown(_ devices: [StoredDevice]) {
        var known = knownDeviceMACs
        for device in devices {
            if let mac = device.macAddress {
                known.insert(mac)
            }
        }
        defaults.set(Array(known), forKey: knownDevicesKey)
    }

    func isNewDevice(mac: String) -> Bool {
        !knownDeviceMACs.contains(mac)
    }

    func removeKnown(_ mac: String) {
        var known = knownDeviceMACs
        known.remove(mac)
        defaults.set(Array(known), forKey: knownDevicesKey)
    }

    func clearAllKnown() {
        defaults.removeObject(forKey: knownDevicesKey)
    }

    // MARK: - Last Scan Results (for widget)

    var lastScanDate: Date? {
        defaults.object(forKey: lastScanKey) as? Date
    }

    func saveLastScan(devices: [StoredDevice]) {
        defaults.set(Date(), forKey: lastScanKey)
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: "lastScanDevices")
        }
    }

    func loadLastScan() -> [StoredDevice] {
        guard let data = defaults.data(forKey: "lastScanDevices"),
              let devices = try? JSONDecoder().decode([StoredDevice].self, from: data) else {
            return []
        }
        return devices
    }

    // MARK: - New Devices (for widget)

    func saveNewDevices(_ devices: [StoredDevice]) {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: "newDevices")
        }
    }

    func loadNewDevices() -> [StoredDevice] {
        guard let data = defaults.data(forKey: "newDevices"),
              let devices = try? JSONDecoder().decode([StoredDevice].self, from: data) else {
            return []
        }
        return devices
    }

    // MARK: - Score (for widget)

    func saveScore(_ score: Int, grade: String) {
        defaults.set(score, forKey: "detrimentScore")
        defaults.set(grade, forKey: "detrimentGrade")
    }

    var savedScore: Int { defaults.integer(forKey: "detrimentScore") }
    var savedGrade: String { defaults.string(forKey: "detrimentGrade") ?? "?" }
}

/// Codable version of device for persistence
struct StoredDevice: Codable, Identifiable {
    var id: String { macAddress ?? ipAddress }
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let manufacturer: String?
    let deviceType: String
    let riskLevel: Int
    let openPortCount: Int
    let firstSeen: Date
    let isNew: Bool

    var displayName: String {
        if let hostname = hostname, !hostname.isEmpty { return hostname }
        if let manufacturer = manufacturer, !manufacturer.isEmpty { return "\(manufacturer) Device" }
        return "Unknown Device"
    }

    init(from device: NetworkDevice, isNew: Bool) {
        self.ipAddress = device.ipAddress
        self.macAddress = device.macAddress
        self.hostname = device.hostname
        self.manufacturer = device.manufacturer
        self.deviceType = device.deviceType.rawValue
        self.riskLevel = device.riskLevel.rawValue
        self.openPortCount = device.openPorts.count
        self.firstSeen = Date()
        self.isNew = isNew
    }
}
