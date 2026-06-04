//
//  ProfileHeaderView.swift
//  Amisa
//
//  En-tête profil : avatar, nom, réglages (sans bannière).
//

import SwiftUI

struct ProfileHeaderView: View {
    @ObservedObject var store: ProfileStore
    var onSettings: () -> Void

    private let avatarSize: CGFloat = 112

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                ProfileAvatarCircleView(
                    localUIImage: store.avatarImage(),
                    remoteURLString: store.avatarRemoteURLString,
                    diameter: avatarSize,
                    initials: store.initials,
                    outerSeparatorRingColor: Color(.systemBackground),
                    outerSeparatorRingWidth: 4,
                    innerAccentBorder: nil,
                    fallbackSymbolName: "person.fill",
                    fallbackFillColor: DesignTokens.accentMuted
                )
                .frame(maxWidth: .infinity)

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Réglages"))
            }

            Text(store.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

#Preview {
    ProfileHeaderView(store: ProfileStore.shared, onSettings: {})
        .background(Color(.systemGroupedBackground))
}
