//
//  ResultsFloatingHeader.swift
//

import SwiftUI

struct ResultsFloatingHeader: View {
    let safeTop: CGFloat
    let scrollOffset: CGFloat
    let isFavorite: Bool
    let image: UIImage?
    let onBack: () -> Void
    let onFavoriteTap: () -> Void
    let onPreviewTap: (() -> Void)?

    private var progress: CGFloat {
        min(max((scrollOffset - 120) / 80, 0), 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            headerButton(systemName: "chevron.left", action: onBack)
                .accessibilityLabel(String(localized: "Retour"))

            Spacer(minLength: 0)

            HeaderMiniSquircle(image: image)
                .frame(width: 46, height: 46)
                .opacity(progress)
                .scaleEffect(0.85 + progress * 0.15)
                .contentShape(Rectangle())
                .onTapGesture { onPreviewTap?() }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: progress)

            Spacer(minLength: 0)

            headerButton(systemName: isFavorite ? "heart.fill" : "heart", action: onFavoriteTap)
                .foregroundStyle(isFavorite ? Color.accentColor : Color.primary)
                .accessibilityLabel(String(localized: "Favori"))
        }
        .padding(.horizontal, 28)
        .padding(.top, safeTop + 8)
        .frame(height: safeTop + 62, alignment: .top)
        .background {
            ProgressiveHeaderBlur(opacity: progress)
                .allowsHitTesting(false)
        }
        .zIndex(1000)
        .allowsHitTesting(true)
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .contentShape(Circle())
    }
}

private struct HeaderMiniSquircle: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.9), lineWidth: 1.5)
        )
    }
}

private struct ProgressiveHeaderBlur: View {
    let opacity: CGFloat

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(opacity)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.00),
                        .init(color: .black.opacity(0.90), location: 0.55),
                        .init(color: .black.opacity(0.25), location: 0.85),
                        .init(color: .clear, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
