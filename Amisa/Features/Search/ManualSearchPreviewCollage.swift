//
//  ManualSearchPreviewCollage.swift
//  Balibu
//

import SwiftUI

/// Snapshot logique d’une recherche manuelle au moment du chargement (les champs équivalents sont persistés sur `SearchSession` / `FavoriteSearchRecord`).
struct ManualSearchSnapshot {
    let query: String
    let createdAt: Date
    let listings: [MarketplaceListing]
    let previewImageURLs: [URL]

    init(query: String, createdAt: Date, listings: [MarketplaceListing]) {
        self.query = query
        self.createdAt = createdAt
        self.listings = listings
        self.previewImageURLs = MarketplaceListing.previewImageURLs(from: listings)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Tuile image réseau pour le collage : échec isolé → placeholder dans la cellule uniquement.
private struct CollageRemoteImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                cellPlaceholder
            case .empty:
                Color(uiColor: .systemGray5)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.85)
                    }
            @unknown default:
                cellPlaceholder
            }
        }
    }

    private var cellPlaceholder: some View {
        Color(uiColor: .systemGray5)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
    }
}

/// Collage : grande image à gauche, pile à droite (haut puis bas) pour 3 images ; variantes 1 et 2 images.
struct ManualSearchPreviewCollage: View {
    let imageURLs: [URL]
    var cornerRadius: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let gap: CGFloat = 0
            let leftWidth = width * 0.58
            let rightWidth = width - leftWidth - gap

            HStack(spacing: gap) {
                if let first = imageURLs[safe: 0] {
                    CollageRemoteImage(url: first)
                        .frame(width: imageURLs.count == 1 ? width : leftWidth, height: height)
                        .clipped()
                }

                if imageURLs.count >= 2, let secondURL = imageURLs[safe: 1] {
                    VStack(spacing: gap) {
                        CollageRemoteImage(url: secondURL)
                            .frame(width: rightWidth, height: imageURLs.count >= 3 ? height / 2 : height)
                            .clipped()

                        if imageURLs.count >= 3, let thirdURL = imageURLs[safe: 2] {
                            CollageRemoteImage(url: thirdURL)
                                .frame(width: rightWidth, height: height / 2)
                                .clipped()
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
    }
}
