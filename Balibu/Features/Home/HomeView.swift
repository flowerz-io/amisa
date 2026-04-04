//
//  HomeView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import PhotosUI
import Combine
import UIKit

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: HomeViewModel
    @AppStorage("balibu.notification.educationCompleted") private var notificationEducationCompleted = false
    @State private var showNotificationOnboarding = false
    @State private var manualSearchQuery = ""

    init(searchHistoryService: SearchHistoryService) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(searchHistoryService: searchHistoryService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingL) {
                searchAndImportBar
                hintLine
                compactHowItWorks
                recentHistorySection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Balibu"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showNotificationOnboarding, onDismiss: {
            if !notificationEducationCompleted {
                notificationEducationCompleted = true
            }
        }) {
            NotificationOnboardingSheet(educationCompleted: $notificationEducationCompleted)
        }
        .onAppear {
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
    }

    /// Barre recherche (saisie réservée à une évolution texte) + import image.
    private var searchAndImportBar: some View {
        HStack(spacing: DesignTokens.spacingS) {
            HStack(spacing: DesignTokens.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignTokens.textSecondary)
                TextField(String(localized: "Rechercher une pièce…"), text: $manualSearchQuery)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit {
                        manualSearchQuery = ""
                    }
            }
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.vertical, DesignTokens.spacingS)
            .background(DesignTokens.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))

            Button {
                viewModel.presentPhotoPicker = true
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(DesignTokens.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Importer une image"))
        }
        .photosPicker(
            isPresented: $viewModel.presentPhotoPicker,
            selection: $viewModel.selectedItems,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: viewModel.selectedItems) { _, _ in
            viewModel.onPhotoSelected { payload in
                if let payload {
                    router.navigateToSharedImportReview(payload: payload)
                }
            }
        }
    }

    private var hintLine: some View {
        Text(String(localized: "L’analyse et les résultats se basent sur une photo : importe une image ou utilise Partager depuis une autre app."))
            .font(DesignTokens.captionFont)
            .foregroundColor(DesignTokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactHowItWorks: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Text(String(localized: "Comment ça marche"))
                .font(DesignTokens.headlineFont)
                .foregroundColor(DesignTokens.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                flowStep(number: 1, text: String(localized: "Repère une pièce dans une app"))
                flowStep(number: 2, text: String(localized: "Partage → Balibu ou importe une photo ici"))
                flowStep(number: 3, text: String(localized: "Analyse et annonces similaires"))
            }
            .padding(DesignTokens.spacingM)
            .background(DesignTokens.cardBackground)
            .cornerRadius(DesignTokens.cornerRadiusM)
        }
    }

    private func flowStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingM) {
            Text("\(number)")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(DesignTokens.textSecondary)
                .frame(width: 20, height: 20, alignment: .center)
                .background(DesignTokens.accentMuted)
                .clipShape(Circle())

            Text(text)
                .font(DesignTokens.bodyFont)
                .foregroundColor(DesignTokens.textPrimary)
        }
    }

    private var recentHistorySection: some View {
        Group {
            if viewModel.recentSessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "Aucune recherche récente"),
                    message: String(localized: "Importe une image ou partage depuis une autre app.")
                )
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text(String(localized: "Recherches récentes"))
                        .font(DesignTokens.headlineFont)
                        .foregroundColor(DesignTokens.textPrimary)

                    ForEach(viewModel.recentSessions) { session in
                        HistoryRowView(session: session, onTap: {
                            router.navigateToResults(session: session)
                        })
                    }

                    if viewModel.recentSessions.count >= 3 {
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

// MARK: - Supporting Views

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
        HomeView(searchHistoryService: SearchHistoryService.shared)
    }
}
