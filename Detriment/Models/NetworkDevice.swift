import Foundation

struct NetworkDevice: Identifiable, Hashable {
    let id = UUID()
    let ipAddress: String
    var macAddress: String?
    var hostname: String?
    var manufacturer: String?
    var deviceType: DeviceType
    var openPorts: [PortInfo]
    var isReachable: Bool
    var lastSeen: Date
    var riskLevel: RiskLevel

    var displayName: String {
        if let hostname = hostname, !hostname.isEmpty {
            return hostname
        }
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            return "\(manufacturer) Device"
        }
        return "Unknown Device"
    }

    var displaySubtitle: String {
        var parts: [String] = [ipAddress]
        if let manufacturer = manufacturer {
            parts.append(manufacturer)
        }
        return parts.joined(separator: " · ")
    }
}

enum DeviceType: String, CaseIterable {
    case router = "Router"
    case phone = "Phone"
    case computer = "Computer"
    case tablet = "Tablet"
    case tv = "Smart TV"
    case speaker = "Speaker"
    case camera = "Camera"
    case iotDevice = "Smart Device"
    case printer = "Printer"
    case gameConsole = "Game Console"
    case unknown = "Unknown"

    var iconName: String {
        switch self {
        case .router: return "wifi.router"
        case .phone: return "iphone"
        case .computer: return "laptopcomputer"
        case .tablet: return "ipad"
        case .tv: return "tv"
        case .speaker: return "hifispeaker"
        case .camera: return "web.camera"
        case .iotDevice: return "sensor"
        case .printer: return "printer"
        case .gameConsole: return "gamecontroller"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum RiskLevel: Int, Comparable {
    case safe = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .safe: return "Good"
        case .low: return "OK"
        case .medium: return "Caution"
        case .high: return "Warning"
        case .critical: return "Danger"
        }
    }

    var color: String {
        switch self {
        case .safe: return "green"
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

struct PortInfo: Hashable, Identifiable {
    var id: Int { port }
    let port: Int
    let service: String
    let isOpen: Bool
    let risk: RiskLevel

    static let commonPorts: [(Int, String, RiskLevel)] = [
        (22, "Remote Access", .medium),
        (23, "Insecure Login", .critical),
        (53, "Name Lookup", .low),
        (80, "Web Page", .low),
        (443, "Secure Web", .safe),
        (445, "File Sharing", .high),
        (548, "Apple File Sharing", .medium),
        (554, "Video Stream", .high),
        (3389, "Remote Control", .high),
        (5000, "Device Discovery", .medium),
        (5353, "Auto-Discovery", .low),
        (8080, "Web Service", .medium),
        (8443, "Secure Web Alt", .low),
        (9100, "Printer", .low),
        (62078, "iPhone Sync", .low),
    ]
}

struct WiFiInfo {
    let ssid: String?
    let bssid: String?
    let security: WiFiSecurity
    let signalStrength: Int?

    var securityRisk: RiskLevel {
        switch security {
        case .wpa3: return .safe
        case .wpa2: return .low
        case .wpa: return .high
        case .wep: return .critical
        case .open: return .critical
        case .unknown: return .medium
        }
    }
}

enum WiFiSecurity: String {
    case wpa3 = "WPA3"
    case wpa2 = "WPA2"
    case wpa = "WPA"
    case wep = "WEP"
    case open = "Open"
    case unknown = "Unknown"
}

struct DetrimentScore {
    let total: Int // 0-100, higher = worse
    let networkSecurity: Int
    let unknownDevices: Int
    let openPorts: Int
    let vulnerableDevices: Int

    var grade: String {
        switch total {
        case 0...20: return "A"
        case 21...40: return "B"
        case 41...60: return "C"
        case 61...80: return "D"
        default: return "F"
        }
    }

    var gradeColor: String {
        switch total {
        case 0...20: return "green"
        case 21...40: return "mint"
        case 41...60: return "yellow"
        case 61...80: return "orange"
        default: return "red"
        }
    }

    var summary: String {
        switch total {
        case 0...20: return "Your WiFi looks great. Nice job!"
        case 21...40: return "Mostly good, a few things to check."
        case 41...60: return "Some devices need your attention."
        case 61...80: return "Several things look risky on your WiFi."
        default: return "Your WiFi needs help. Tap devices to learn more."
        }
    }
}
