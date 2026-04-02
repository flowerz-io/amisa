//
//  SharedImportReviewView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI

struct SharedImportReviewView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: SharedImportReviewViewModel

    let payload: SharedImagePayload

    init(payload: SharedImagePayload, apiClient: (any APIClientProtocol)? = nil) {
        self.payload = payload
        _viewModel = StateObject(wrappedValue: SharedImportReviewViewModel(
            payload: payload,
            apiClient: apiClient ?? APIConfig.apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingXL) {
                imageSection
                explanationText
                actionSection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cleanupAndDismiss { router.popToRoot() }
                }
            }
        }
        .onAppear {
            viewModel.setSearchHistoryService(.shared)
        }
    }

    private var imageSection: some View {
        Group {
            if let url = payload.imageURL,
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM)
                            .stroke(DesignTokens.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM)
                    .fill(DesignTokens.cardBackground)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: DesignTokens.spacingS) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Image not available")
                                .font(DesignTokens.bodyFont)
                        }
                        .foregroundColor(DesignTokens.textSecondary)
                    }
            }
        }
    }

    private var explanationText: some View {
        Text("We'll analyze this image and find similar items on resale marketplaces.")
            .font(DesignTokens.bodyFont)
            .foregroundColor(DesignTokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionSection: some View {
        VStack(spacing: DesignTokens.spacingM) {
            switch viewModel.searchState {
            case .idle, .error:
                Button {
                    viewModel.startSearch { session in
                        router.navigateToResults(session: session)
                    }
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search resale matches")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.spacingL)
                }
                .buttonStyle(BalibuButtonStyle())
                .disabled(viewModel.searchState == .loading)

            case .loading:
                LoadingView(message: "Analyzing image…")

            case .success:
                EmptyView()
            }

            if case .error(let message) = viewModel.searchState {
                VStack(spacing: DesignTokens.spacingS) {
                    Text(message)
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.errorColor)
                        .multilineTextAlignment(.center)
                    Text("Tap the button above to try again.")
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SharedImportReviewView(payload: SharedImagePayload(imageFileName: "preview.jpg"))
            .environmentObject(Router())
    }
}
