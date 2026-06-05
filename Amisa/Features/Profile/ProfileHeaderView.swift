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

    private let avatarSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 14) {
                    ProfileAvatarCircleView(
                        localUIImage: store.avatarImage(),
                        remoteURLString: store.avatarRemoteURLString,
                        diameter: avatarSize,
                        initials: store.initials,
                        outerSeparatorRingColor: DesignTokens.backgroundSecondary,
                        outerSeparatorRingWidth: 3,
                        innerAccentBorder: (Color.accentColor.opacity(0.22), 2),
                        fallbackSymbolName: "person.fill",
                        fallbackFillColor: DesignTokens.accentMuted
                    )
                    .frame(maxWidth: .infinity)

                    Text(store.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 20)
                .padding(.bottom, 18)
                .padding(.horizontal, 20)

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .padding(.trailing, 16)
                .accessibilityLabel(String(localized: "Réglages"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .background(DesignTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AmisaChrome.emptyStateRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AmisaChrome.emptyStateRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ProfileHeaderView(store: ProfileStore.shared, onSettings: {})
        .background(Color(.systemGroupedBackground))
}
