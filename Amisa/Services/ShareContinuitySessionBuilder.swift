//
//  ShareContinuitySessionBuilder.swift
//  Balibu
//

import Foundation

enum ShareContinuitySessionBuilder {
    static func sessionForContinuityResume(
        sessionId: String,
        pending: PendingSharedSearchSession?
    ) -> SearchSession? {
        guard let pending, pending.sessionId == sessionId else { return nil }

        let listings = loadListings(fileName: pending.continuitySnapshotFileName)
        let query = pending.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let terminal = pending.status == "completed" || pending.status == "failed"
        let awaitsRailwayHydration = !terminal && pending.originalImagePath != nil

        if listings.isEmpty, pending.originalImagePath == nil, query.isEmpty {
            return nil
        }

        return SearchSession(
            imageFileName: pending.originalImagePath,
            thumbnailImageURL: nil,
            searchQuery: query,
            generatedQueries: query.isEmpty ? [] : [query],
            attributes: nil,
            listings: listings,
            createdAt: pending.createdAt,
            mode: .imageAnalysis,
            previewImageURLs: [],
            awaitsRailwayHydration: awaitsRailwayHydration
        )
    }

    private static func loadListings(fileName: String?) -> [MarketplaceListing] {
        guard let fileName,
              let url = SharedSearchSessionStore.continuitySnapshotURL(fileName: fileName),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(ShareContinuitySnapshotFile.self, from: data)
        else {
            return []
        }
        return payload.listings.map { $0.toMarketplaceListing() }
    }
}
