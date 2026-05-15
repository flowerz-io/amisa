//
//  AnalyzeSearchRequest.swift
//  Balibu
//
//  Requête pour l'endpoint POST /analyze-search.
//

import Foundation

/// Requête envoyée au backend pour analyser une image et rechercher des annonces.
struct AnalyzeSearchRequest: Encodable {
    let imageBase64: String?
    let textQuery: String?
    let enabledProviders: [String]

    init(imageBase64: String, enabledProviders: [String]) {
        self.imageBase64 = imageBase64
        self.textQuery = nil
        self.enabledProviders = enabledProviders
    }

    init(textQuery: String, enabledProviders: [String]) {
        self.imageBase64 = nil
        self.textQuery = textQuery
        self.enabledProviders = enabledProviders
    }
}
