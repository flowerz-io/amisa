import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var router: Router
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var auth  = AuthManager.shared
    @State private var showSettings      = false
    @State private var showAuthSheet     = false
    @State private var showAllAnalyses   = false

    private let moodColumns = [
        GridItem(.adaptive(minimum: AmisaChrome.analysisThumbMinSize), spacing: AmisaChrome.analysisGridSpacing),
    ]

    private var scannedSessions: [SearchSession] {
        SearchHistoryService.shared.fetchSessions().filter { session in
            guard session.mode == .imageAnalysis else { return false }
            return session.imageFileName != nil || session.thumbnailImageURL != nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if auth.isAuthenticated {
                    ProfileHeaderView(store: store, onSettings: { showSettings = true })
                } else {
                    guestHeader
                }

                moodboardSection
            }
            .padding(.horizontal, auth.isAuthenticated ? 0 : 24)
            .padding(.top, auth.isAuthenticated ? 0 : 12)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Fermer")) { showSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthBottomSheet(onSignedIn: { @MainActor in showAuthSheet = false })
                .presentationDetents([.height(560)])
                .presentationCornerRadius(32)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAllAnalyses) {
            NavigationStack {
                AllPhotoAnalysesView()
                    .environmentObject(router)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { showAllAnalyses = false }
                        }
                    }
            }
        }
    }

    // MARK: - Guest header (non connecté)

    private var guestHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ProfileAvatarCircleView(
                    localUIImage: nil,
                    remoteURLString: nil,
                    diameter: 72,
                    initials: nil,
                    fallbackSymbolName: "person.fill",
                    fallbackFillColor: DesignTokens.accentMuted
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Non connecté")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)

                    Text("Connecte-toi pour retrouver tes\nanalyses sur tous tes appareils.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showAuthSheet = true
            } label: {
                Label("Se connecter", systemImage: "person.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacingM)
        .background(DesignTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusL, style: .continuous))
    }

    // MARK: - Analyses photo

    private var moodboardSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            HStack {
                Text(String(localized: "Tes analyses photo"))
                    .font(DesignTokens.headlineFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()
                if !scannedSessions.isEmpty {
                    Button {
                        showAllAnalyses = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(localized: "Voir tout"))
                            Text("(\(scannedSessions.count))")
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, auth.isAuthenticated ? 24 : 0)

            if scannedSessions.isEmpty {
                ProfileAnalysesEmptyState()
                    .padding(.horizontal, auth.isAuthenticated ? 24 : 0)
            } else {
                let previewSessions = Array(scannedSessions.prefix(12))
                LazyVGrid(columns: moodColumns, spacing: 6) {
                    ForEach(previewSessions) { session in
                        Button {
                            router.navigateToResults(session: session)
                        } label: {
                            moodThumb(for: session)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minWidth: AmisaChrome.analysisThumbMinSize, minHeight: AmisaChrome.analysisThumbMinSize)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: AmisaChrome.analysisThumbRadius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AmisaChrome.analysisThumbRadius, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                                }
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, auth.isAuthenticated ? 24 : 0)
            }
        }
    }

    @ViewBuilder
    private func moodThumb(for session: SearchSession) -> some View {
        if let ui = session.sourceImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let thumb = session.thumbnailImageURL,
                  let data = try? Data(contentsOf: thumb),
                  let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: AmisaChrome.analysisThumbRadius, style: .continuous)
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}

// MARK: - Empty state analyses

private struct ProfileAnalysesEmptyState: View {
    private let cardCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0 ..< cardCount, id: \.self) { index in
                    ProfileAnalysisSkeletonCard()
                        .opacity(1 - Double(index) * 0.12)
                }
            }

            Text(String(localized: "Tes analyses apparaîtront ici après avoir analysé tes premières photos."))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AmisaChrome.emptyStateRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AmisaChrome.emptyStateRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
    }
}

private struct ProfileAnalysisSkeletonCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill).opacity(colorScheme == .dark ? 0.42 : 0.58))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(Router())
    }
}
