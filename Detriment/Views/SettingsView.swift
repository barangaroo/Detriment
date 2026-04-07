import SwiftUI

struct SettingsView: View {
    @State private var showResetKnownAlert = false
    @State private var showResetTrustedAlert = false
    @State private var showClearNamesAlert = false
    @State private var showClearHistoryAlert = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("shareAnonymousData") private var shareAnonymousData = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                Section {
                    Button(action: { showResetKnownAlert = true }) {
                        settingsRow("xmark.circle", "Reset Known Devices", "New device alerts will trigger for all devices on next scan", .orange)
                    }
                    .alert("Reset Known Devices?", isPresented: $showResetKnownAlert) {
                        Button("Reset", role: .destructive) { DeviceStorage.shared.clearAllKnown() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("All devices will be treated as new on the next scan.")
                    }

                    Button(action: { showResetTrustedAlert = true }) {
                        settingsRow("shield.slash", "Reset Trusted Devices", "Remove trust from all devices", .orange)
                    }
                    .alert("Reset Trusted Devices?", isPresented: $showResetTrustedAlert) {
                        Button("Reset", role: .destructive) { DeviceStorage.shared.clearTrustedDevices() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("You'll need to re-trust devices individually.")
                    }

                    Button(action: { showClearNamesAlert = true }) {
                        settingsRow("textformat.abc", "Clear Custom Names", "Remove all custom device names", .orange)
                    }
                    .alert("Clear Custom Names?", isPresented: $showClearNamesAlert) {
                        Button("Clear", role: .destructive) { DeviceStorage.shared.clearDeviceNames() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("All custom device labels will be removed.")
                    }
                } header: {
                    sectionLabel("DEVICES")
                }
                .listRowBackground(Color.white.opacity(0.03))

                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("New Device Alerts")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Get notified when unknown devices join")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .tint(.red)

                    Toggle(isOn: $shareAnonymousData) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Improve Detection")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Share anonymous device types to help everyone")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .tint(.red)
                } header: {
                    sectionLabel("NOTIFICATIONS")
                }
                .listRowBackground(Color.white.opacity(0.03))

                Section {
                    Button(action: { showClearHistoryAlert = true }) {
                        settingsRow("trash", "Clear Scan History", "Delete all past scan records", .red)
                    }
                    .alert("Clear Scan History?", isPresented: $showClearHistoryAlert) {
                        Button("Clear", role: .destructive) { DeviceStorage.shared.clearHistory() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("All past scan records will be permanently deleted.")
                    }
                } header: {
                    sectionLabel("DATA")
                }
                .listRowBackground(Color.white.opacity(0.03))

                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text("Detriment v1.0.0")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("WiFi Security Scanner")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } header: {
                    sectionLabel("ABOUT")
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SETTINGS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }

    private func settingsRow(_ icon: String, _ title: String, _ subtitle: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.gray)
    }
}
