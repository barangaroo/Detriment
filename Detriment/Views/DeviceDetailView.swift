import SwiftUI

struct DeviceDetailView: View {
    let device: NetworkDevice
    var intel: DeviceIntel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        deviceHeader
                        infoSection
                        if !device.openPorts.isEmpty {
                            portsSection
                        }
                        if let intel = intel, !intel.vulnerabilities.isEmpty {
                            vulnSection(intel.vulnerabilities)
                        }
                        // Show WHAT TO KNOW only if there are actual risk reasons beyond "looks fine"
                        if hasRealRisks {
                            riskSection
                        } else if intel == nil || intel?.vulnerabilities.isEmpty == true {
                            // No backend intel and no local risks — show single all-clear
                            allClearSection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DEVICE DETAILS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var deviceHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(riskColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: device.deviceType.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(riskColor)
            }

            Text(device.displayName)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(device.deviceType.rawValue)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)

            // Risk badge
            Text(device.riskLevel.label.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(riskColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(riskColor.opacity(0.15))
                )
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            sectionHeader("DETAILS")

            infoRow("Address", device.ipAddress)
            if let mac = device.macAddress {
                infoRow("Device ID", mac)
            }
            if let manufacturer = device.manufacturer {
                infoRow("Made by", manufacturer)
            }
            if let hostname = device.hostname {
                infoRow("Name", hostname)
            }
            infoRow("Last seen", formatDate(device.lastSeen))
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Ports

    private var portsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("OPEN DOORS")

            ForEach(device.openPorts) { port in
                HStack {
                    Text("\(port.port)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 60, alignment: .leading)

                    Text(port.service)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray)

                    Spacer()

                    Text(port.risk.label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(portRiskColor(port.risk))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(portRiskColor(port.risk).opacity(0.15))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if port.id != device.openPorts.last?.id {
                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.leading, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Risk

    private var riskSection: some View {
        VStack(spacing: 0) {
            sectionHeader("WHAT TO KNOW")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(riskReasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .padding(.top, 2)

                        Text(reason)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Vulnerabilities (from backend)

    private func vulnSection(_ vulns: [VulnIntel]) -> some View {
        VStack(spacing: 0) {
            sectionHeader("KNOWN ISSUES")

            ForEach(vulns) { vuln in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(vuln.title)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(severityLabel(vuln.severity))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(severityColor(vuln.severity))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(severityColor(vuln.severity).opacity(0.15)))
                    }

                    Text(vuln.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)

                    if let fix = vuln.fix {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .padding(.top, 2)
                            Text(fix)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Tips (from backend)

    private func tipsSection(_ tips: [String]) -> some View {
        VStack(spacing: 0) {
            sectionHeader("TIPS")

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func severityLabel(_ severity: String) -> String {
        switch severity {
        case "critical": return "DANGER"
        case "high": return "WARNING"
        case "medium": return "CAUTION"
        default: return "INFO"
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        default: return .green
        }
    }

    // MARK: - All Clear

    private var allClearSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Looking good")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text("No issues found with this device.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var hasRealRisks: Bool {
        // Check if there are actual risk reasons beyond the default "looks fine"
        if device.deviceType == .unknown { return true }
        if device.openPorts.contains(where: { $0.risk >= .medium }) { return true }
        if device.manufacturer == nil && device.hostname == nil { return true }
        if let mfr = device.manufacturer?.lowercased() {
            if mfr.contains("espressif") || mfr.contains("tuya") || mfr.contains("hikvision") { return true }
        }
        return false
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private var riskReasons: [String] {
        var reasons: [String] = []

        if device.deviceType == .unknown {
            reasons.append("We can't tell what this device is. If you don't recognize it, someone else might be on your WiFi.")
        }

        if device.openPorts.contains(where: { $0.port == 23 }) {
            reasons.append("This device uses an old, insecure way to log in. Anyone on your network could see its password.")
        }

        if device.openPorts.contains(where: { $0.port == 554 }) {
            reasons.append("This device is streaming video. If it's a camera, others on your network might be able to watch.")
        }

        if device.openPorts.contains(where: { $0.port == 445 }) {
            reasons.append("This device is sharing files on your network. Make sure it's password-protected.")
        }

        if device.openPorts.contains(where: { $0.port == 3389 }) {
            reasons.append("Someone can remotely control this device. Make sure you set this up — if not, turn it off.")
        }

        if device.openPorts.contains(where: { $0.port == 22 }) {
            reasons.append("This device accepts remote connections. Make sure it has a strong password.")
        }

        if device.manufacturer == nil && device.hostname == nil {
            reasons.append("This device is hiding its identity. It could be anything — check if you recognize it.")
        }

        if let mfr = device.manufacturer?.lowercased() {
            if mfr.contains("espressif") || mfr.contains("tuya") {
                reasons.append("This is a cheap smart home chip. These often have weak security and may send your data overseas.")
            }
            if mfr.contains("hikvision") {
                reasons.append("Hikvision cameras have had security problems in the past. Make sure the firmware is up to date.")
            }
        }

        if reasons.isEmpty {
            reasons.append("This device looks fine. No issues found.")
        }

        return reasons
    }

    private var riskColor: Color {
        switch device.riskLevel {
        case .safe: return .green
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func portRiskColor(_ risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return .green
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
