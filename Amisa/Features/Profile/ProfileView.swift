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
        GridItem(.adaptive(minimum: 72), spacing: 6),
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
                    ProfileBannerHeaderView(store: store, onSettings: { showSettings = true })
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
            AuthBottomSheet(onSignedIn: { showAuthSheet = false })
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
                Circle()
                    .fill(DesignTokens.accentMuted)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

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

    // MARK: - Moodboard

    private var moodboardSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            HStack {
                Text(String(localized: "Tes analyses photo"))
                    .font(DesignTokens.headlineFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()
                if !scannedSessions.isEmpty {
                    Button {
                        showAllAnalyses = true
                    } label: {
                        Text("Voir tout (\(scannedSessions.count))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, auth.isAuthenticated ? 24 : 0)

            if scannedSessions.isEmpty {
                Text(String(localized: "Aucun scan pour l'instant."))
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.textSecondary)
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
                                .frame(minWidth: 72, minHeight: 72)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(Router())
    }
}
