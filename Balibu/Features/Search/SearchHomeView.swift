//
//  SearchHomeView.swift
//  Balibu
//
//  Onglet « Rechercher » : barre de recherche + recherches texte récentes uniquement.
//

import SwiftUI
import Combine
import UIKit

struct SearchHomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: HomeViewModel
    @AppStorage("balibu.notification.educationCompleted") private var notificationEducationCompleted = false
    @State private var showNotificationOnboarding = false
    @State private var manualSearchQuery = ""
    @State private var textSearchAlert: String?

    init(searchHistoryService: SearchHistoryService) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(searchHistoryService: searchHistoryService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingL) {
                searchBar
                hintLine
                recentTextSearchesSection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNotificationOnboarding, onDismiss: {
            if !notificationEducationCompleted {
                notificationEducationCompleted = true
            }
        }) {
            NotificationOnboardingSheet(educationCompleted: $notificationEducationCompleted)
        }
        .onChange(of: router.path.count) { _, _ in
            viewModel.loadRecentSessions()
        }
        .onAppear {
            viewModel.loadRecentSessions()
            Task {
                await NotificationManager.shared.refreshAuthorizationStatus()
                let status = await NotificationManager.shared.currentAuthorizationStatus()
                await MainActor.run {
                    guard !notificationEducationCompleted else { return }
                    if status == .authorized || status == .provisional || status == .ephemeral {
                        notificationEducationCompleted = true
                        return
                    }
                    showNotificationOnboarding = true
                }
            }
        }
        .alert(String(localized: "Recherche"), isPresented: Binding(
            get: { textSearchAlert != nil },
            set: { if !$0 { textSearchAlert = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) { textSearchAlert = nil }
        } message: {
            Text(textSearchAlert ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: DesignTokens.spacingS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.textSecondary)
            TextField(String(localized: "Rechercher une pièce…"), text: $manualSearchQuery)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        do {
                            let session = try await viewModel.submitTextSearch(query: manualSearchQuery)
                            manualSearchQuery = ""
                            router.navigateToResults(session: session)
                        } catch {
                            textSearchAlert = error.localizedDescription
                        }
                    }
                }
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.vertical, DesignTokens.spacingS)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
    }

    private var hintLine: some View {
        Text(String(localized: "Saisis un mot-clé pour chercher sur les marketplaces activées dans Réglages (Profil). Utilise le bouton scan pour une analyse à partir d’une photo."))
            .font(DesignTokens.captionFont)
            .foregroundColor(DesignTokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentTextSearchesSection: some View {
        Group {
            if viewModel.recentTextOnlySessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "Aucune recherche texte récente"),
                    message: String(localized: "Lance une recherche depuis la barre ci-dessus.")
                )
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text(String(localized: "Recherches récentes"))
                        .font(DesignTokens.headlineFont)
                        .foregroundColor(DesignTokens.textPrimary)

                    ForEach(viewModel.recentTextOnlySessions) { session in
                        HistoryRowView(session: session, onTap: {
                            router.navigateToResults(session: session)
                        })
                    }

                    if viewModel.recentTextOnlySessions.count >= 3 {
                        Button(String(localized: "Voir tout")) {
                            router.navigateToSearchHistory()
                        }
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Réutilisé par l’historique texte (même style que l’ancienne Home)

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
                        .foregroundColor(DesignTokens.textPrimary)
                        .lineLimit(1)

                    Text(session.formattedDate)
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignTokens.textSecondary)
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
        } else if session.isTextOnlySearch {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS)
                .fill(DesignTokens.accentMuted)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundColor(DesignTokens.textSecondary)
                }
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS)
                .fill(DesignTokens.accentMuted)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(DesignTokens.textSecondary)
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
                .foregroundColor(DesignTokens.textSecondary)
            Text(title)
                .font(DesignTokens.headlineFont)
                .foregroundColor(DesignTokens.textPrimary)
            Text(message)
                .font(DesignTokens.bodyFont)
                .foregroundColor(DesignTokens.textSecondary)
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
