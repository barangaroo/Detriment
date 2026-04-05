import SwiftUI

struct MainView: View {
    @StateObject private var scanner = NetworkScanner()
    @State private var selectedDevice: NetworkDevice?
    @State private var pulseScale: CGFloat = 1.0
    @State private var radarAngle: Double = 0
    @State private var showScore = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.02, blue: 0.02)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if scanner.isScanning {
                        scanningView
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if let score = scanner.detrimentScore {
                        scoreHeader(score)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        idleHeader
                            .transition(.opacity)
                    }

                    if !scanner.devices.isEmpty {
                        deviceList
                            .transition(.move(edge: .bottom))
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: scanner.isScanning)
                .animation(.easeInOut(duration: 0.4), value: scanner.detrimentScore != nil)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        Text("DETRIMENT")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device, intel: scanner.getIntel(for: device))
            }
        }
    }

    // MARK: - Idle State

    private var idleHeader: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Outer pulse rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.red.opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                        .frame(width: CGFloat(200 + i * 40), height: CGFloat(200 + i * 40))
                        .scaleEffect(pulseScale)
                }

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)

                Button(action: {
                    withAnimation { scanner.startScan() }
                }) {
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40, weight: .medium))
                            .symbolEffect(.pulse, options: .repeating)
                        Text("SCAN")
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .tracking(4)
                    }
                    .foregroundColor(.red)
                    .frame(width: 150, height: 150)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.6), Color.red.opacity(0.2)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            }

            VStack(spacing: 6) {
                Text("Tap to check your WiFi")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)

                if let ip = scanner.getLocalIPAddress() {
                    Text(ip)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Scanning State

    private var scanningView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.red.opacity(0.06), lineWidth: 1)
                        .frame(width: CGFloat(140 + i * 30), height: CGFloat(140 + i * 30))
                }

                // Radar sweep
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        AngularGradient(
                            colors: [Color.red.opacity(0.5), Color.clear],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(90)
                        ),
                        lineWidth: 60
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(radarAngle))

                // Progress ring
                Circle()
                    .trim(from: 0, to: scanner.scanProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text("\(scanner.devices.count)")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text("found")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                }
            }
            .padding(.top, 24)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    radarAngle = 360
                }
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * scanner.scanProgress, height: 4)
                            .animation(.linear(duration: 0.3), value: scanner.scanProgress)
                    }
                }
                .frame(height: 4)

                Text("Scanning your network...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 50)

            Button(action: { withAnimation { scanner.stopScan() } }) {
                Text("STOP")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.6))
                    .tracking(2)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Score Header

    private func scoreHeader(_ score: DetrimentScore) -> some View {
        VStack(spacing: 16) {
            // Score gauge
            HStack(spacing: 20) {
                // Circular gauge
                ZStack {
                    // Background track
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 8)
                        .frame(width: 90, height: 90)

                    // Score arc
                    Circle()
                        .trim(from: 0, to: CGFloat(score.total) / 100.0)
                        .stroke(
                            LinearGradient(
                                colors: scoreGradient(score),
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text(score.grade)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(gradeColor(score))
                        Text("\(score.total)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("DETRIMENT SCORE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(1)

                    Text(score.summary)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)

                    Button(action: { withAnimation { scanner.startScan() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Rescan")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Score breakdown chips
            HStack(spacing: 8) {
                scoreChip("WiFi", score.networkSecurity, max: 25, icon: "wifi")
                scoreChip("Mystery", score.unknownDevices, max: 25, icon: "questionmark")
                scoreChip("Doors", score.openPorts, max: 25, icon: "door.left.hand.open")
                scoreChip("Risky", score.vulnerableDevices, max: 25, icon: "exclamationmark.triangle")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.white.opacity(0.02))
        )
    }

    private func scoreChip(_ label: String, _ value: Int, max: Int, icon: String) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(chipColor(value, max: max).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(chipColor(value, max: max))
            }
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(chipColor(value, max: max))
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func chipColor(_ value: Int, max: Int) -> Color {
        if value == 0 { return .green }
        if value <= max / 3 { return .green }
        if value <= max * 2 / 3 { return .yellow }
        return .red
    }

    // MARK: - Device List

    private var deviceList: some View {
        List {
            Section {
                ForEach(scanner.devices.sorted { $0.riskLevel > $1.riskLevel }) { device in
                    DeviceRow(device: device)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedDevice = device }
                }
            } header: {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Text("\(scanner.devices.count) ON YOUR WIFI")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    let risky = scanner.devices.filter { $0.riskLevel >= .medium }.count
                    if risky > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("\(risky) NEED ATTENTION")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private func gradeColor(_ score: DetrimentScore) -> Color {
        switch score.total {
        case 0...20: return .green
        case 21...40: return .mint
        case 41...60: return .yellow
        case 61...80: return .orange
        default: return .red
        }
    }

    private func scoreGradient(_ score: DetrimentScore) -> [Color] {
        switch score.total {
        case 0...20: return [.green, .mint]
        case 21...40: return [.mint, .green]
        case 41...60: return [.yellow, .orange]
        case 61...80: return [.orange, .red]
        default: return [.red, .pink]
        }
    }
}
