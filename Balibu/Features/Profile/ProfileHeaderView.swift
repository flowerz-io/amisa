import SwiftUI
import UIKit

struct ProfileHeaderView: View {
    @ObservedObject var store: ProfileStore
    var onEditProfile: () -> Void
    var onSettings: () -> Void

    private let avatarSize: CGFloat = 100

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
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
                .foregroundStyle(Color.black.opacity(0.72))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.16))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            profileSettingsButton
        }
    }

    private var profileSettingsButton: some View {
        Button(action: onSettings) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Réglages"))
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
