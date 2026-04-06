import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var router: Router
    @ObservedObject private var store = ProfileStore.shared
    @State private var showEditProfile = false
    @State private var showSettings = false

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
            VStack(alignment: .leading, spacing: DesignTokens.spacingXL) {
                ProfileHeaderView(
                    store: store,
                    onEditProfile: { showEditProfile = true },
                    onSettings: { showSettings = true }
                )

                moodboardSection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Fermer")) {
                                showSettings = false
                            }
                        }
                    }
            }
        }
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
