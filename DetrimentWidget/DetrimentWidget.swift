import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct DetrimentProvider: TimelineProvider {
    private let storage = DeviceStorage()

    func placeholder(in context: Context) -> DetrimentEntry {
        DetrimentEntry(date: Date(), score: 0, grade: "?", deviceCount: 0, newDevices: [], lastScan: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DetrimentEntry) -> Void) {
        let entry = currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DetrimentEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> DetrimentEntry {
        let devices = storage.loadLastScan()
        let newDevices = storage.loadNewDevices()
        return DetrimentEntry(
            date: Date(),
            score: storage.savedScore,
            grade: storage.savedGrade,
            deviceCount: devices.count,
            newDevices: newDevices,
            lastScan: storage.lastScanDate
        )
    }

    private struct DeviceStorage {
        private let defaults: UserDefaults

        init() {
            self.defaults = UserDefaults(suiteName: "group.com.detriment.app") ?? .standard
        }

        var lastScanDate: Date? {
            defaults.object(forKey: "lastScanDate") as? Date
        }

        var savedScore: Int { defaults.integer(forKey: "detrimentScore") }
        var savedGrade: String { defaults.string(forKey: "detrimentGrade") ?? "?" }

        func loadLastScan() -> [WidgetDevice] {
            guard let data = defaults.data(forKey: "lastScanDevices"),
                  let devices = try? JSONDecoder().decode([WidgetDevice].self, from: data) else {
                return []
            }
            return devices
        }

        func loadNewDevices() -> [WidgetDevice] {
            guard let data = defaults.data(forKey: "newDevices"),
                  let devices = try? JSONDecoder().decode([WidgetDevice].self, from: data) else {
                return []
            }
            return devices
        }
    }
}

// MARK: - Lightweight device model for widget

struct WidgetDevice: Codable, Identifiable {
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
}

// MARK: - Timeline Entry

struct DetrimentEntry: TimelineEntry {
    let date: Date
    let score: Int
    let grade: String
    let deviceCount: Int
    let newDevices: [WidgetDevice]
    let lastScan: Date?
}

// MARK: - Widget Views

struct DetrimentWidgetSmall: View {
    let entry: DetrimentEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DETRIMENT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                Spacer()
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 6) {
                Text(entry.grade)
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundColor(gradeColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.score)/100")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "wifi")
                    .font(.system(size: 10))
                Text("\(entry.deviceCount) devices")
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundColor(.gray)

            if !entry.newDevices.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(entry.newDevices.count) new")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
        }
        .widgetURL(URL(string: "detriment://scan"))
        .padding(14)
        .containerBackground(.black, for: .widget)
    }

    private var gradeColor: Color {
        switch entry.score {
        case 0...20: return .green
        case 21...40: return .mint
        case 41...60: return .yellow
        case 61...80: return .orange
        default: return .red
        }
    }
}

struct DetrimentWidgetMedium: View {
    let entry: DetrimentEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Score
            VStack(alignment: .leading, spacing: 8) {
                Text("DETRIMENT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.red)

                Spacer()

                Text(entry.grade)
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundColor(gradeColor)

                Text("\(entry.score)/100")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 10))
                    Text("\(entry.deviceCount) devices")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(.gray)
            }

            // Right: New devices or status
            VStack(alignment: .leading, spacing: 6) {
                if entry.newDevices.isEmpty {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("No new\ndevices")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    Text("\(entry.newDevices.count) NEW")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)

                    ForEach(entry.newDevices.prefix(3)) { device in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(device.riskLevel >= 2 ? Color.red : Color.orange)
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.displayName)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(device.ipAddress)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Spacer()

                if let lastScan = entry.lastScan {
                    Text("Scanned \(lastScan, style: .relative) ago")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(URL(string: "detriment://scan"))
        .padding(14)
        .containerBackground(.black, for: .widget)
    }

    private var gradeColor: Color {
        switch entry.score {
        case 0...20: return .green
        case 21...40: return .mint
        case 41...60: return .yellow
        case 61...80: return .orange
        default: return .red
        }
    }
}

// MARK: - Widget Configuration

struct DetrimentWidget: Widget {
    let kind = "DetrimentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DetrimentProvider()) { entry in
            if #available(iOS 17.0, *) {
                DetrimentWidgetView(entry: entry)
            } else {
                DetrimentWidgetView(entry: entry)
                    .padding()
                    .background(.black)
            }
        }
        .configurationDisplayName("Detriment")
        .description("Monitor your network security score and new device alerts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DetrimentWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DetrimentEntry

    var body: some View {
        switch family {
        case .systemMedium:
            DetrimentWidgetMedium(entry: entry)
        default:
            DetrimentWidgetSmall(entry: entry)
        }
    }
}

@main
struct DetrimentWidgetBundle: WidgetBundle {
    var body: some Widget {
        DetrimentWidget()
    }
}
