//
//  AmisaPremiumEmptyState.swift
//  Amisa
//
//  Empty state carte premium réutilisable (Recherche, Favoris, etc.).
//

import SwiftUI

struct AmisaPremiumEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var iconTint: Color = DesignTokens.accentSecondary.opacity(0.85)
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignTokens.spacingM) {
            ZStack {
                Circle()
                    .fill(DesignTokens.accentMuted.opacity(0.55))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: AmisaChrome.emptyStateIconSize, weight: .medium))
                    .foregroundStyle(iconTint)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Label(secondaryActionTitle, systemImage: "camera.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(AmisaChrome.emptyStatePadding)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AmisaChrome.emptyStateRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AmisaChrome.emptyStateRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}
