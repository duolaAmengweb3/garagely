import SwiftUI

struct PrivacyView: View {
    private let sections: [(String, String)] = [
        ("On-device by design",
         "Garagely stores everything — your vehicles, service records, fuel logs, reminders and photos — locally on your device using Apple's on-device database. There is no account to create and no sign-in."),
        ("No tracking, no ads",
         "Garagely does not track you, does not contain advertising, and includes no third-party analytics or advertising SDKs. We do not collect, sell or share any personal data."),
        ("iCloud sync (optional, Pro)",
         "If you enable iCloud Sync, your garage is synced through your own private iCloud account using Apple CloudKit so your data appears on your other devices. This data lives in your iCloud and is not accessible to us."),
        ("Photos & camera",
         "When you attach a photo to a record, the image is stored locally with that record. Camera and photo-library access are used only for this purpose and only when you choose to add a photo."),
        ("Purchases",
         "Garagely Pro is a one-time purchase processed by Apple. We never see your payment information."),
        ("Your data is yours",
         "You can export your full history to CSV or PDF at any time, and deleting the app removes all locally stored data."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Garagely keeps your data on your device. Here's exactly what that means.")
                    .appFont(15, weight: .medium).foregroundStyle(Theme.ink2)
                ForEach(Array(sections.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.0).appFont(16, weight: .bold).foregroundStyle(Theme.ink)
                        Text(s.1).appFont(14, weight: .regular).foregroundStyle(Theme.ink2).lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 16, radius: 18)
                }
                Text("Questions? Email xxhhuan2022@163.com")
                    .appFont(12, weight: .medium).foregroundStyle(Theme.ink3).padding(.top, 4)
                Color.clear.frame(height: 30)
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
