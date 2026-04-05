import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var hasPurchased: Bool
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Logo
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 36))
                                .foregroundColor(.red)
                        }

                        Text("DETRIMENT")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                    }

                    // Value props
                    VStack(spacing: 16) {
                        featureRow(icon: "wifi.exclamationmark", color: .red,
                                   title: "See every device",
                                   subtitle: "Know exactly what's connected to your WiFi")

                        featureRow(icon: "exclamationmark.shield.fill", color: .orange,
                                   title: "Spot threats instantly",
                                   subtitle: "Vulnerabilities explained in plain English")

                        featureRow(icon: "bell.badge.fill", color: .yellow,
                                   title: "New device alerts",
                                   subtitle: "Get notified when something new connects")

                        featureRow(icon: "chart.bar.fill", color: .green,
                                   title: "Security score",
                                   subtitle: "One number that tells you how safe you are")

                        featureRow(icon: "lock.shield.fill", color: .blue,
                                   title: "Your data stays private",
                                   subtitle: "Scans happen on your phone, not in the cloud")
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 8)

                    // Price
                    VStack(spacing: 6) {
                        Text("One-time purchase")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(1)

                        Text("$2.99")
                            .font(.system(size: 44, weight: .black, design: .monospaced))
                            .foregroundColor(.white)

                        Text("No subscriptions. No ads. Ever.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    // Buy button
                    Button(action: { purchase() }) {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isPurchasing ? "Purchasing..." : "Unlock Detriment")
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.8)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                    .padding(.horizontal, 24)

                    // Restore
                    Button(action: { restore() }) {
                        Text("Restore Purchase")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    // Legal
                    HStack(spacing: 16) {
                        Link("Terms", destination: URL(string: "https://detriment.ai/terms")!)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                        Link("Privacy", destination: URL(string: "https://detriment.ai/privacy")!)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    // MARK: - StoreKit

    private func purchase() {
        isPurchasing = true
        Task {
            do {
                let products = try await Product.products(for: ["com.detriment.app.unlock"])
                guard let product = products.first else {
                    isPurchasing = false
                    errorMessage = "Product not found. Please try again."
                    showError = true
                    return
                }

                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified:
                        await MainActor.run {
                            hasPurchased = true
                            isPurchasing = false
                        }
                    case .unverified:
                        await MainActor.run {
                            isPurchasing = false
                            errorMessage = "Purchase could not be verified."
                            showError = true
                        }
                    }
                case .userCancelled:
                    await MainActor.run { isPurchasing = false }
                case .pending:
                    await MainActor.run { isPurchasing = false }
                @unknown default:
                    await MainActor.run { isPurchasing = false }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func restore() {
        Task {
            do {
                try await AppStore.sync()
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        if transaction.productID == "com.detriment.app.unlock" {
                            await MainActor.run { hasPurchased = true }
                            return
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not restore. Please try again."
                    showError = true
                }
            }
        }
    }
}
