import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    let deviceName: String
    let riskCount: Int

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Blurred preview teaser
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 70, height: 70)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 32)

                    Text("Unlock Device Intel")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)

                    Text("See what \(deviceName) is doing on your network")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // What you get
                VStack(spacing: 14) {
                    unlockRow(icon: "magnifyingglass", color: .red, text: "Open ports and what they mean")
                    unlockRow(icon: "exclamationmark.triangle.fill", color: .orange, text: "Known vulnerabilities for this device")
                    unlockRow(icon: "wrench.and.screwdriver", color: .blue, text: "Step-by-step fix instructions")
                    unlockRow(icon: "lightbulb.fill", color: .yellow, text: "Security tips from our database")
                    unlockRow(icon: "checkmark.shield.fill", color: .green, text: "Trust and label your devices")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)

                Spacer()

                // Price + buy
                VStack(spacing: 12) {
                    if riskCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("\(riskCount) device\(riskCount == 1 ? "" : "s") on your network need attention")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                        .padding(.bottom, 4)
                    }

                    Button(action: { doPurchase() }) {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            }
                            Text(isPurchasing ? "Purchasing..." : "Unlock Everything — $3.99")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.red)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                    .padding(.horizontal, 24)

                    Text("One-time purchase. No subscription.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))

                    HStack(spacing: 20) {
                        Button("Restore Purchase") { doRestore() }
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                        Link("Privacy", destination: URL(string: "https://detriment.ai/privacy")!)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func unlockRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }

    private func doPurchase() {
        isPurchasing = true
        Task {
            do {
                let success = try await store.purchase()
                isPurchasing = false
                if !success {
                    // User cancelled or pending — no error needed
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func doRestore() {
        Task {
            do {
                try await store.restore()
                if !store.isUnlocked {
                    errorMessage = "No previous purchase found."
                    showError = true
                }
            } catch {
                errorMessage = "Could not restore. Try again."
                showError = true
            }
        }
    }
}
