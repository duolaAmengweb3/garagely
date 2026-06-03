import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject private var notifications: NotificationManager
    @State private var showAddVehicle = false

    private let features: [(String, String, String)] = [
        ("car.2.fill", "Every vehicle, one garage", "Log service, repairs, fuel and mileage for each car."),
        ("bell.badge.fill", "Never miss an oil change", "Reminders by date or mileage — whichever comes first."),
        ("lock.fill", "Private by design", "On-device. No account, no sign-in, no ads."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            VStack(spacing: 18) {
                Image("OnboardingMark")
                    .resizable().scaledToFit().frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text("Welcome to Garagely")
                        .appFont(28, weight: .bold).foregroundStyle(Theme.ink)
                    Text("The simple way to track your car's upkeep.")
                        .appFont(15, weight: .medium).foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 24)

            VStack(spacing: 14) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                    HStack(spacing: 14) {
                        Image(systemName: f.0).appFont(18, weight: .semibold)
                            .foregroundStyle(Theme.brand).frame(width: 42, height: 42)
                            .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.1).appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                            Text(f.2).appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: "Add your first vehicle", icon: "plus") { showAddVehicle = true }
                .padding(.horizontal, 24).padding(.bottom, 20)
        }
        .screenBackground()
        .sheet(isPresented: $showAddVehicle) {
            VehicleEditorView()
                .onDisappear {
                    Task { await notifications.requestAuthorization() }
                }
        }
    }
}
