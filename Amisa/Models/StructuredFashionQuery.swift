//
//  StructuredFashionQuery.swift
//  Balibu
//
//  Requête structurée pour recherche marketplace.
//

import Foundation

/// Requête mode structurée générée à partir de l'analyse image.
struct StructuredFashionQuery: Codable, Equatable {
    let searchQuery: String
    let attributes: FashionVisionResult?
}
