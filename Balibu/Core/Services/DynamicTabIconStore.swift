//
//  DynamicTabIconStore.swift
//  Balibu
//
//  Store singleton qui expose l'icône dynamique de l'onglet Home.
//  - Recompute uniquement si les deux premières annonces changent (hash stable).
//  - Chargement réseau asynchrone, non bloquant pour la UI.
//  - Fallback transparent : homeIcon reste nil tant que les images ne sont pas prêtes.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class DynamicTabIconStore: ObservableObject {

    static let shared = DynamicTabIconStore()

    // nil → la tab bar affiche l'icône SF Symbol par défaut
    @Published private(set) var homeIcon: UIImage? = nil

    private var currentHash: String? = nil

    private init() {}

    // MARK: - Update

    /// Appeler depuis le ViewModel Home après chaque rechargement du feed.
    /// Non bloquant : retourne immédiatement, le calcul est async.
    func updateIfNeeded(with listings: [MarketplaceListing]) {
        // On prend les deux premières annonces qui ont une URL d'image valide.
        let candidates = listings.filter { $0.thumbnailURL != nil || $0.imageURL != nil }
        guard candidates.count >= 2 else { return }

        let l1 = candidates[0]
        let l2 = candidates[1]
        let url1 = l1.thumbnailURL ?? l1.imageURL
        let url2 = l2.thumbnailURL ?? l2.imageURL

        // Hash stable basé sur les identifiants + URLs
        let hash = [l1.id, l2.id,
                    url1?.absoluteString ?? "",
                    url2?.absoluteString ?? ""].joined(separator: "|")

        guard hash != currentHash else { return }

        // On marque le hash immédiatement pour éviter les requêtes doublons
        currentHash = hash

        Task {
            // Les deux téléchargements partent en parallèle.
            // URLSession.shared bénéficie du URLCache système partagé avec AsyncImage.
            async let fetch1 = Self.fetchImage(from: url1)
            async let fetch2 = Self.fetchImage(from: url2)

            guard let img1 = await fetch1, let img2 = await fetch2 else {
                // Échec de chargement : reset du hash pour permettre un retry au prochain load()
                self.currentHash = nil
                return
            }

            // Composition (rapide, ~78×78 px) — sur le MainActor, acceptable
            let icon = TabBarIconComposer.compose(leading: img1, trailing: img2)
            self.homeIcon = icon
        }
    }

    // MARK: - Private image loading

    /// Télécharge ou récupère depuis le cache URLSession.
    /// Nonisolated → s'exécute dans le cooperative thread pool, libère le MainActor.
    private static func fetchImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
