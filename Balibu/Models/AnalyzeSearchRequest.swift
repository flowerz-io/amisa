//
//  AnalyzeSearchRequest.swift
//  Balibu
//
//  Requête pour l'endpoint POST /analyze-search.
//

import Foundation

/// Requête envoyée au backend pour analyser une image et rechercher des annonces.
struct AnalyzeSearchRequest: Encodable {
    let imageBase64: String
}
