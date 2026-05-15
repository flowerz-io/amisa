//
//  ShareContinuitySnapshot.swift
//  BalibuShareExtension
//
//  Schéma JSON aligné sur `Balibu/Models/ShareContinuitySnapshot.swift`.
//

import Foundation

struct ShareContinuitySnapshotFile: Encodable {
    let schemaVersion: Int
    let sessionId: String
    let savedAt: Date
    let status: String
    let searchQuery: String?
    let listings: [ShareContinuityListingRow]
}

struct ShareContinuityListingRow: Encodable {
    let id: String
    let title: String
    let price: Double
    let currency: String?
    let imageURL: URL?
    let thumbnailURL: URL?
    let source: String

    init(teaser: ShareExtensionTeaserListing) {
        id = teaser.id
        title = teaser.title
        price = teaser.price
        currency = teaser.currency
        imageURL = teaser.imageURL
        thumbnailURL = teaser.thumbnailURL ?? teaser.imageURL
        source = teaser.source
    }
}
