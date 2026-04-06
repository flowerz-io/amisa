import SwiftUI
import UIKit

struct ProfileHeaderView: View {
    @ObservedObject var store: ProfileStore
    var onEditProfile: () -> Void
    var onSettings: () -> Void

    private let avatarSize: CGFloat = 100

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            profileImage
                .frame(width: avatarSize, height: avatarSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(store.displayName)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Button(String(localized: "Modifier le profil")) {
                    onEditProfile()
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 0)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Réglages"))
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let ui = store.avatarImage() {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}

#Preview {
    ProfileHeaderView(
        store: ProfileStore.shared,
        onEditProfile: {},
        onSettings: {}
    )
    .padding()
}
