//
//  FashionVisionResult.swift
//  Balibu
//
//  Résultat de l'analyse Vision d'un vêtement (champ visionResult de la réponse).
//

import Foundation

/// Résultat de l'analyse fashion par un modèle vision.
struct FashionVisionResult: Codable, Equatable, Hashable {
    let category: String?
    let subcategory: String?
    let dominantItem: String?
    let probableBrand: String?
    let color: String?
    let material: String?
    let styleKeywords: [String]?
    let confidence: Double?
    /// Confiance que l'image est une source e-commerce/fashion (0-1).
    let sourceConfidence: Double?
}
