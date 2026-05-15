//
//  AnalyzeFetchCoordinator.swift
//  Balibu
//
//  Permet d’attendre au plus X secondes en fullscreen puis d’ouvrir Results avec hydration async.
//

import Foundation

extension Notification.Name {
    /// `object` : `SearchSession` final (même `id` que le placeholder).
    static let amisaSearchSessionHydrated = Notification.Name("amisa.searchSession.hydrated")
    /// `object` : `String` message utilisateur.
    static let amisaSearchHydrationFailed = Notification.Name("amisa.searchHydration.failed")
}

/// Durées cibles fullscreen avant passage Results + skeletons.
enum FullscreenSearchTiming {
    /// Analyse image (aperçu premium court).
    static let photoNanoseconds: UInt64 = 1_400_000_000
    /// Recherche texte (légèrement plus courte).
    static let textNanoseconds: UInt64 = 1_200_000_000
}

actor AnalyzeFetchCoordinator {
    private(set) var outcome: Result<SearchSession, Error>?

    func run(_ operation: @Sendable () async throws -> SearchSession) async {
        guard outcome == nil else { return }
        do {
            outcome = .success(try await operation())
        } catch {
            outcome = .failure(error)
        }
    }

    func peekOutcome() -> Result<SearchSession, Error>? {
        outcome
    }
}
