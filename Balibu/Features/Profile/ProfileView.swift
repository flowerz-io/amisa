import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var router: Router
    @ObservedObject private var store = ProfileStore.shared
    @State private var showEditProfile = false

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
            VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                headerCard
                linksSection
                moodboardSection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Profil"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: DesignTokens.spacingM) {
            avatarView
                .frame(width: 88, height: 88)

            Text(store.displayName)
                .font(DesignTokens.fontTitle)
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)

            Button(String(localized: "Modifier le profil")) {
                showEditProfile = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.spacingL)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
    }

    @ViewBuilder
    private var avatarView: some View {
        if let ui = store.avatarImage() {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }

    private var linksSection: some View {
        VStack(spacing: DesignTokens.spacingS) {
            NavigationLink {
                FavoritesView()
            } label: {
                rowLabel(String(localized: "Favoris"), systemImage: "heart.fill")
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsView()
            } label: {
                rowLabel(String(localized: "Réglages"), systemImage: "gearshape.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(DesignTokens.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
    }

    private var moodboardSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Text(String(localized: "Tes analyses photo"))
                .font(DesignTokens.headlineFont)
                .foregroundStyle(DesignTokens.textPrimary)

            if scannedSessions.isEmpty {
                Text(String(localized: "Aucun scan pour l’instant."))
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.textSecondary)
            } else {
                LazyVGrid(columns: moodColumns, spacing: 6) {
                    ForEach(scannedSessions) { session in
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
