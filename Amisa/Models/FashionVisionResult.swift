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
    /// Équipe, club, franchise (ex: Mets).
    let inferredEntity: String?
    /// Collab / texte secondaire (ex: MoMA).
    let secondaryMarking: String?
    /// Modèle si identifiable (ex: Detroit Jacket).
    let inferredModel: String?
    /// Couleur dominante sur ~80 % de l’objet.
    let dominantColorPrecise: String?
    /// Type canon court (ex: jacket, cap, clog).
    let itemTypeCanonical: String?
    /// Modèle exact probable (prompt vision expert).
    let exactModel: String?
    /// Coloris commercial ou descriptif.
    let colorway: String?
    /// Marque + modèle + coloris (affichage prioritaire).
    let fullIdentification: String?
    /// Indices visuels courts (transparence / debug).
    let visualReasoning: String?
    /// Requêtes Vinted suggérées par le backend.
    let searchQueries: [String]?
}
