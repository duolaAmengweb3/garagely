import SwiftUI

struct AltIconsView: View {
    @EnvironmentObject private var icons: IconManager

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(IconManager.icons) { icon in
                    Button {
                        Task { await icons.setIcon(icon) }
                    } label: {
                        VStack(spacing: 8) {
                            Image(icon.previewAsset)
                                .resizable().scaledToFit().frame(width: 74, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
                                .overlay(alignment: .bottomTrailing) {
                                    if icons.current == icon.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .appFont(20).foregroundStyle(.white, Theme.brand)
                                            .offset(x: 4, y: 4)
                                    }
                                }
                            Text(icon.displayName)
                                .appFont(12, weight: .semibold)
                                .foregroundStyle(icons.current == icon.id ? Theme.brand : Theme.ink2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}
