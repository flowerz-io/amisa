//
//  ProfileBannerHeaderView.swift
//  Balibu
//
//  Bannière (+ image perso / URL Supabase), avatar à cheval, réglages, nom sous la photo.
//

import SwiftUI
import UIKit

struct ProfileBannerHeaderView: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.colorScheme) private var colorScheme

    var onSettings: () -> Void

    private let avatarSize: CGFloat = 112
    private let bannerHeight: CGFloat = 160
    private var bannerAvatarStackHeight: CGFloat { bannerHeight + avatarSize / 2 }

    private var bannerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.35),
                BrandColors.secondary.opacity(0.28),
                Color.black.opacity(colorScheme == .dark ? 0.8 : 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    Group {
                        bannerContent
                            .frame(height: bannerHeight)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay {
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18),
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    avatarView
                        .offset(y: avatarSize / 2)
                }
                .frame(height: bannerAvatarStackHeight, alignment: .top)

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 54, height: 54)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.trailing, 12)
                .zIndex(10)
                .accessibilityLabel(String(localized: "Réglages"))
            }

            Text(store.displayName)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var bannerContent: some View {
        if let ui = store.bannerImage() {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let s = store.bannerRemoteURLString, let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(bannerGradient)
                default:
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
            }
        } else {
            Rectangle().fill(bannerGradient)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        ProfileAvatarCircleView(
            localUIImage: store.avatarImage(),
            remoteURLString: store.avatarRemoteURLString,
            diameter: avatarSize,
            outerSeparatorRingColor: Color(.systemBackground),
            outerSeparatorRingWidth: 7,
            innerAccentBorder: nil,
            fallbackSymbolName: "person.fill"
        )
    }
}

#Preview {
    ProfileBannerHeaderView(store: ProfileStore.shared, onSettings: {})
        .background(Color(.systemGroupedBackground))
}
