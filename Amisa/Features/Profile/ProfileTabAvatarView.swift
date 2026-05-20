//
//  ProfileTabAvatarView.swift
//  Balibu
//
//  Avatar profil (tab bar, réglages, header) : cache distant + fallback SF Symbol.
//

import SwiftUI
import UIKit

/// Cercle avatar : fichier local prioritaire, puis URL distante via ``RemoteAvatarCache``.
struct ProfileAvatarCircleView: View {
    let localUIImage: UIImage?
    let remoteURLString: String?
    let diameter: CGFloat
    var outerSeparatorRingColor: Color?
    var outerSeparatorRingWidth: CGFloat = 0
    var innerAccentBorder: (color: Color, width: CGFloat)?
    var fallbackSymbolName: String = "person.fill"
    var fallbackFillColor: Color = Color.gray.opacity(0.15)

    @State private var resolvedRemote: UIImage?

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
            } else if hasRemoteURL {
                ProgressView()
                    .scaleEffect(0.85)
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: diameter * 0.38, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(fallbackFillColor)
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

    private var hasRemoteURL: Bool {
        guard let s = remoteURLString?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !s.isEmpty
    }

    private func resolveRemote() async {
        guard localUIImage == nil else {
            resolvedRemote = nil
            return
        }
        guard hasRemoteURL else {
            resolvedRemote = nil
            return
        }
        resolvedRemote = await RemoteAvatarCache.shared.image(for: remoteURLString)
    }
}

/// Avatar compact pour la tab bar « Profil » (symbole nu si aucune URL ni fichier local).
struct ProfileTabAvatarView: View {
    let localUIImage: UIImage?
    let remoteURLString: String?
    let isSelected: Bool
    let fallbackTint: Color

    private let diameter: CGFloat = 34

    private var hasRemoteHint: Bool {
        guard let s = remoteURLString?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !s.isEmpty
    }

    var body: some View {
        Group {
            if localUIImage != nil || hasRemoteHint {
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
