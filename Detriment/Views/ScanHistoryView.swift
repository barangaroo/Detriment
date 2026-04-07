import SwiftUI

struct ScanHistoryView: View {
    @State private var history: [ScanSnapshot] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No scans yet")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("Run a scan to start tracking history")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                }
            } else {
                List {
                    ForEach(history) { snapshot in
                        HStack(spacing: 14) {
                            // Grade circle
                            ZStack {
                                Circle()
                                    .fill(gradeColor(snapshot.score).opacity(0.12))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Circle()
                                            .stroke(gradeColor(snapshot.score).opacity(0.2), lineWidth: 1)
                                    )
                                Text(snapshot.grade)
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundColor(gradeColor(snapshot.score))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(snapshot.date))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)

                                HStack(spacing: 8) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "wifi")
                                            .font(.system(size: 9))
                                        Text("\(snapshot.deviceCount)")
                                            .font(.system(size: 11, design: .monospaced))
                                    }
                                    .foregroundColor(.gray)

                                    if snapshot.newDeviceCount > 0 {
                                        HStack(spacing: 3) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 9))
                                            Text("\(snapshot.newDeviceCount) new")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        }
                                        .foregroundColor(.orange)
                                    }
                                }
                            }

                            Spacer()

                            Text("\(snapshot.score)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(gradeColor(snapshot.score))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SCAN HISTORY")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            history = DeviceStorage.shared.loadScanHistory()
        }
    }

    private func gradeColor(_ score: Int) -> Color {
        switch score {
        case 0...20: return .green
        case 21...40: return .mint
        case 41...60: return .yellow
        case 61...80: return .orange
        default: return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }
}
