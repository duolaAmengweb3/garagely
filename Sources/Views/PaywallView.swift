import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchases: PurchaseManager

    // Every benefit below maps to a real, Pro-gated feature in the app.
    private let benefits: [(String, String, String)] = [
        ("car.2.fill", "Unlimited vehicles", "Cars, motorcycles, RVs — no limit"),
        ("chart.bar.fill", "Full spend analytics", "Cost-per-mile, economy & trends"),
        ("square.and.arrow.up.fill", "Export CSV & PDF", "Hand a full history to the next owner"),
        ("icloud.fill", "iCloud sync", "Your garage on every device"),
        ("square.stack.3d.up.fill", "Service templates", "Reusable schedules, one tap to apply"),
        ("paintbrush.fill", "Alternate app icons", "Six finishes to match your style"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .appFont(30, weight: .bold).foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Text("Garagely Pro").appFont(28, weight: .bold).foregroundStyle(Theme.ink)
                    Text("One payment. Yours forever.\nNo subscription, no account, no ads.")
                        .appFont(15, weight: .medium).foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(benefits.enumerated()), id: \.offset) { idx, b in
                        HStack(spacing: 14) {
                            Image(systemName: b.0).appFont(17, weight: .semibold)
                                .foregroundStyle(Theme.brand).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.1).appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                                Text(b.2).appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                            }
                            Spacer()
                            Image(systemName: "checkmark").appFont(14, weight: .bold).foregroundStyle(Theme.green)
                        }
                        .padding(.vertical, 14)
                        if idx < benefits.count - 1 { Divider().overlay(Theme.line) }
                    }
                }
                .padding(.horizontal, 16)
                .card(padding: 4, radius: 22)

                VStack(spacing: 10) {
                    if purchases.isPro {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Garagely Pro unlocked")
                        }
                        .appFont(17, weight: .semibold).foregroundStyle(Theme.green)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        PrimaryButton(title: "Unlock everything · \(purchases.priceText)", icon: "lock.open.fill") {
                            Task { await purchases.purchase(); if purchases.isPro { dismiss() } }
                        }
                        Button("Restore Purchase") {
                            Task { await purchases.restore(); if purchases.isPro { dismiss() } }
                        }
                        .appFont(14, weight: .semibold).foregroundStyle(Theme.ink2)
                    }
                }
                if purchases.purchasing { ProgressView().tint(Theme.brand) }
                Text("A one-time purchase. No recurring charges, ever.")
                    .appFont(12, weight: .medium).foregroundStyle(Theme.ink3)
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.paper)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").appFont(28)
                    .foregroundStyle(Theme.ink3, Theme.line)
            }
            .padding(16)
        }
    }
}
