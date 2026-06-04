//
//  ProfileTabAvatarView.swift
//  Amisa
//
//  Avatar profil (tab bar, réglages, header) : cache distant + fallback premium.
//

import SwiftUI
import UIKit

/// Cercle avatar : fichier local prioritaire, puis URL distante via ``RemoteAvatarCache``.
struct ProfileAvatarCircleView: View {
    let localUIImage: UIImage?
    let remoteURLString: String?
    let diameter: CGFloat
    var initials: String? = nil
    var outerSeparatorRingColor: Color?
    var outerSeparatorRingWidth: CGFloat = 0
    var innerAccentBorder: (color: Color, width: CGFloat)?
    var fallbackSymbolName: String = "person.fill"
    var fallbackFillColor: Color = Color.gray.opacity(0.15)

    @State private var resolvedRemote: UIImage?
    @State private var remoteFailed = false

    var body: some View {
        Group {
            if let localUIImage {
                Image(uiImage: localUIImage)
                    .resizable()
                    .scaledToFill()
            } else if let resolvedRemote {
                Image(uiImage: resolvedRemote)
                    .resizable()
                    .scaledToFill()
            } else if isLoadingRemote {
                placeholderContent
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.85)
                    }
            } else {
                placeholderContent
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            if let innerAccentBorder {
                Circle()
                    .strokeBorder(innerAccentBorder.color, lineWidth: innerAccentBorder.width)
            }
        }
        .overlay {
            if let outerSeparatorRingColor, outerSeparatorRingWidth > 0 {
                Circle()
                    .strokeBorder(outerSeparatorRingColor, lineWidth: outerSeparatorRingWidth)
            }
        }
        .task(id: remoteURLString) {
            await resolveRemote()
        }
    }

    private var isLoadingRemote: Bool {
        validRemoteURL != nil && !remoteFailed && resolvedRemote == nil && localUIImage == nil
    }

    private var validRemoteURL: URL? {
        guard let s = remoteURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            fallbackFillColor,
                            fallbackFillColor.opacity(0.65),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let initials, !initials.isEmpty {
                Text(initials)
                    .font(.system(size: diameter * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary.opacity(0.85))
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: diameter * 0.38, weight: .medium))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private func resolveRemote() async {
        remoteFailed = false
        resolvedRemote = nil

        guard localUIImage == nil else { return }
        guard validRemoteURL != nil else {
            remoteFailed = true
            return
        }

        let img = await RemoteAvatarCache.shared.image(for: remoteURLString)
        if Task.isCancelled { return }

        if let img {
            resolvedRemote = img
            remoteFailed = false
        } else {
            resolvedRemote = nil
            remoteFailed = true
        }
    }
}

/// Avatar compact pour la tab bar « Profil » (symbole nu si aucune URL ni fichier local).
struct ProfileTabAvatarView: View {
    let localUIImage: UIImage?
    let remoteURLString: String?
    let isSelected: Bool
    let fallbackTint: Color

    private let diameter: CGFloat = 34

    private var hasAvatarHint: Bool {
        if localUIImage != nil { return true }
        guard let s = remoteURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return false }
        return true
    }

    var body: some View {
        Group {
            if hasAvatarHint {
                ProfileAvatarCircleView(
                    localUIImage: localUIImage,
                    remoteURLString: remoteURLString,
                    diameter: diameter,
                    outerSeparatorRingColor: nil,
                    innerAccentBorder: (
                        color: isSelected ? Color.accentColor : Color.white.opacity(0.85),
                        width: 2
                    ),
                    fallbackSymbolName: "person.fill"
                )
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(fallbackTint)
                    .frame(width: diameter, height: diameter)
            }
        }
    }
}
