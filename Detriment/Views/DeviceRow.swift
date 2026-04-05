import SwiftUI

struct DeviceRow: View {
    let device: NetworkDevice

    var body: some View {
        HStack(spacing: 14) {
            // Device icon with colored glow
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(riskColor.opacity(0.08))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(riskColor.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: device.deviceType.iconName)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(riskColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let mfr = device.manufacturer {
                        Text(mfr)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(1)
                    }

                    if !device.openPorts.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "door.left.hand.open")
                                .font(.system(size: 8))
                            Text("\(device.openPorts.count)")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Risk badge
            Text(device.riskLevel.label.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(riskColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(riskColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(riskColor.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
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
}
