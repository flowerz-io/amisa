//
//  SearchHomeView.swift
//  Balibu
//

import SwiftUI
import Combine
import UIKit

struct SearchHomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: HomeViewModel
    @AppStorage("amisa.notification.educationCompleted") private var notificationEducationCompleted = false
    @State private var manualSearchQuery = ""
    @State private var isManualSearchBusy = false
    @FocusState private var isSearchFieldFocused: Bool

    init(searchHistoryService: SearchHistoryService) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(searchHistoryService: searchHistoryService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                searchBar
                    .padding(.horizontal, 24)

                hintLine
                    .padding(.horizontal, 24)

                recentTextSearchesSection
                    .padding(.horizontal, 24)
            }
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "Recherche"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadRecentSessions()
            Task {
                await NotificationManager.shared.refreshAuthorizationStatus()
                let status = await NotificationManager.shared.currentAuthorizationStatus()
                await MainActor.run {
                    if status == .authorized || status == .provisional || status == .ephemeral {
                        notificationEducationCompleted = true
                    }
                }
            }
        }
        .onChange(of: router.path.count) { _, _ in
            viewModel.loadRecentSessions()
            isManualSearchBusy = false
        }
        .onChange(of: router.shouldFocusSearchField) { _, shouldFocus in
            guard shouldFocus else { return }
            isSearchFieldFocused = true
            router.shouldFocusSearchField = false
        }
    }

    private func submitManualSearch() {
        guard !isManualSearchBusy else { return }
        let query = manualSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isManualSearchBusy = true
        manualSearchQuery = ""
        isSearchFieldFocused = false
        router.presentManualSearchLoading(query: query)
    }

    // MARK: - Composants

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.textSecondary)

            TextField(String(localized: "Rechercher une pièce…"), text: $manualSearchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit { submitManualSearch() }

            if !manualSearchQuery.isEmpty {
                Button {
                    manualSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                router.openPhotoAnalysis()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(String(localized: "Analyser une photo"))
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.vertical, DesignTokens.spacingS)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
    }

    private var hintLine: some View {
        Text(String(localized: "Saisis un mot-clé pour lancer une recherche Vinted. Utilise le bouton scan pour une analyse à partir d'une photo."))
            .font(DesignTokens.captionFont)
            .foregroundStyle(DesignTokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentTextSearchesSection: some View {
        Group {
            if viewModel.recentTextOnlySessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "Aucune recherche récente"),
                    message: String(localized: "Lance une recherche depuis la barre ci-dessus.")
                )
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text(String(localized: "Recherches récentes"))
                        .font(DesignTokens.headlineFont)
                        .foregroundStyle(DesignTokens.textPrimary)

                    ForEach(viewModel.recentTextOnlySessions) { session in
                        HistoryRowView(session: session, onTap: {
                            router.navigateToResults(session: session)
                        })
                    }
                }
            }
        }
    }
}

struct HistoryRowView: View {
    let session: SearchSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingM) {
                historyThumbnail

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayQuery ?? "Search")
                        .font(DesignTokens.bodyFont)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(1)

                    Text(session.formattedDate)
                        .font(DesignTokens.captionFont)
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(DesignTokens.spacingM)
            .background(DesignTokens.cardBackground)
            .cornerRadius(DesignTokens.cornerRadiusM)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var historyThumbnail: some View {
        if let thumbnailURL = session.thumbnailImageURL,
           let data = try? Data(contentsOf: thumbnailURL),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS))
        } else if let name = session.imageFileName,
                  let ui = ImagePersistenceService.shared.loadUIImage(fileName: name) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS))
        } else if session.isTextOnlySearch, !session.previewImageURLs.isEmpty {
            ManualSearchPreviewCollage(imageURLs: session.previewImageURLs, cornerRadius: 14)
                .frame(width: 72, height: 72)
        } else if session.isTextOnlySearch {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS)
                .fill(DesignTokens.accentMuted)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS)
                .fill(DesignTokens.accentMuted)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DesignTokens.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.textSecondary)
            Text(title)
                .font(DesignTokens.headlineFont)
                .foregroundStyle(DesignTokens.textPrimary)
            Text(message)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.spacingXL)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.cardBackground)
        .cornerRadius(DesignTokens.cornerRadiusM)
    }
}

#Preview {
    NavigationStack {
        SearchHomeView(searchHistoryService: SearchHistoryService.shared)
            .environmentObject(Router())
    }
}
