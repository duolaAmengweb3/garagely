import UIKit

struct AltIcon: Identifiable, Hashable {
    let id: String?          // nil = primary
    let displayName: String
    let previewAsset: String // image in asset catalog for the picker preview
}

@MainActor
final class IconManager: ObservableObject {
    @Published var current: String?   // nil = primary

    // Order matters — first is primary.
    static let icons: [AltIcon] = [
        AltIcon(id: nil,           displayName: "Safety Orange", previewAsset: "IconOrangePreview"),
        AltIcon(id: "IconCobalt",  displayName: "Cobalt",        previewAsset: "IconCobaltPreview"),
        AltIcon(id: "IconGreen",   displayName: "Racing Green",  previewAsset: "IconGreenPreview"),
        AltIcon(id: "IconViolet",  displayName: "Violet",        previewAsset: "IconVioletPreview"),
        AltIcon(id: "IconCrimson", displayName: "Crimson",       previewAsset: "IconCrimsonPreview"),
        AltIcon(id: "IconSlate",   displayName: "Slate",         previewAsset: "IconSlatePreview"),
    ]

    init() { current = UIApplication.shared.alternateIconName }

    func setIcon(_ icon: AltIcon) async {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        guard icon.id != UIApplication.shared.alternateIconName else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.id)
            current = icon.id
        } catch {
            // user cancelled or unsupported — ignore
        }
    }
}
