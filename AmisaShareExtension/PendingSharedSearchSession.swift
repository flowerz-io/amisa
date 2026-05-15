//
//  PendingSharedSearchSession.swift
//  BalibuShareExtension
//
//  Doit rester aligné sur `Balibu/Models/PendingSharedSearchSession.swift`.
//

import Foundation

struct PendingSharedSearchSession: Codable, Equatable {
    let sessionId: String
    let createdAt: Date
    let source: String
    var status: String
    var previewImagePath: String?
    var originalImagePath: String?
    var searchQuery: String?
    var completedResultJSONFileName: String?
    var continuitySnapshotFileName: String?
}
