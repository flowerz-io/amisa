import Combine
import SwiftUI

enum TextSearchError: LocalizedError {
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return String(localized: "Saisis une requête.")
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentSessions: [SearchSession] = []
    /// Uniquement `mode == .textQuery` (onglet Recherche), ordre historique complet.
    @Published private(set) var recentTextOnlySessions: [SearchSession] = []
    @Published var textSearchError: String?

    private let searchHistoryService: SearchHistoryService
    private let apiClient: any APIClientProtocol

    init(
        searchHistoryService: SearchHistoryService,
        apiClient: any APIClientProtocol = APIConfig.apiClient
    ) {
        self.searchHistoryService = searchHistoryService
        self.apiClient = apiClient
        loadRecentSessions()
    }

    func loadRecentSessions() {
        recentSessions = searchHistoryService.recentSessions(limit: 5)
        recentTextOnlySessions = searchHistoryService.fetchSessions().filter { $0.mode == .textQuery }
    }

    func submitTextSearch(query: String) async throws -> SearchSession {
        textSearchError = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TextSearchError.emptyQuery }

        let response = try await apiClient.analyzeTextSearch(query: trimmed)
        let listings = response.listings.map { MarketplaceListing.from($0) }

        ProviderRuntimeAvailabilityStore.shared.merge(from: response.providerAvailability)

        let session = SearchSession(
            id: UUID(),
            imageFileName: nil,
            thumbnailImageURL: nil,
            searchQuery: trimmed,
            generatedQueries: [trimmed],
            attributes: nil,
            listings: listings,
            createdAt: Date(),
            vintedSearchFailed: response.vintedSearchFailed ?? false,
            paginationState: response.pagination,
            rankingContext: response.rankingContext,
            providerAvailability: response.providerAvailability,
            mode: .textQuery
        )

        searchHistoryService.addSession(session)
        loadRecentSessions()
        return session
    }
}
