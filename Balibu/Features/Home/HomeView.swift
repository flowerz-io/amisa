//
//  HomeView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import PhotosUI
import Combine

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: HomeViewModel

    init(searchHistoryService: SearchHistoryService) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(searchHistoryService: searchHistoryService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingXL) {
                headerSection
                shareFlowSection
                importFromPhotosSection
                recentHistorySection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle("Balibu")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Text("Find similar pieces")
                .font(DesignTokens.titleFont)
                .foregroundColor(DesignTokens.textPrimary)

            Text("Share an outfit from Instagram, Pinterest or any app to find resale matches.")
                .font(DesignTokens.bodyFont)
                .foregroundColor(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareFlowSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("How it works")
                .font(DesignTokens.headlineFont)
                .foregroundColor(DesignTokens.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                flowStep(number: 1, text: "See a piece you like in any app")
                flowStep(number: 2, text: "Tap Share → Choose Balibu")
                flowStep(number: 3, text: "We analyze and find resale matches")
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

    private var importFromPhotosSection: some View {
        Button {
            viewModel.presentPhotoPicker = true
        } label: {
            HStack(spacing: DesignTokens.spacingM) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)

                Text("Import from Photos")
                    .font(DesignTokens.headlineFont)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.spacingL)
            .background(DesignTokens.cardBackground)
            .foregroundColor(DesignTokens.textPrimary)
            .cornerRadius(DesignTokens.cornerRadiusM)
        }
        .buttonStyle(BalibuButtonStyle())
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

    private var recentHistorySection: some View {
        Group {
            if viewModel.recentSessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No searches yet",
                    message: "Share an image to get started."
                )
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text("Recent searches")
                        .font(DesignTokens.headlineFont)
                        .foregroundColor(DesignTokens.textPrimary)

                    ForEach(viewModel.recentSessions) { session in
                        HistoryRowView(session: session, onTap: {
                            router.navigateToResults(session: session)
                        })
                    }

                    if viewModel.recentSessions.count >= 3 {
                        Button("See all") {
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
            if let thumbnailURL = session.thumbnailImageURL,
               let data = try? Data(contentsOf: thumbnailURL),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
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
