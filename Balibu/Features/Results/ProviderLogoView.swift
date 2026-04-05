//
//  ProviderLogoView.swift
//  Balibu
//
//  Logo provider réutilisable (cards + filtres).
//

import SwiftUI
import UIKit

struct ProviderLogoView: View {
    let source: String
    let fallbackLabel: String
    let logoHeight: CGFloat
    let logoMaxWidth: CGFloat

    var body: some View {
        if let uiImage = resolvedLogo {
            Image(uiImage: uiImage)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(height: logoHeight, alignment: .center)
                .frame(maxWidth: logoMaxWidth, alignment: .trailing)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                .accessibilityLabel(fallbackLabel)
                .fixedSize(horizontal: true, vertical: true)
        } else {
            Text(fallbackLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                .accessibilityLabel(fallbackLabel)
                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var resolvedLogo: UIImage? {
        guard let assetName = MarketplaceSource.providerLogoAssetName(for: source) else {
            return nil
        }
        guard let image = UIImage(named: assetName) else {
            return nil
        }
        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return image
    }
}

