//
//  NotificationsSettingsView.swift
//  Balibu
//
//  Préférences de notifications — sauvegardées via @AppStorage.
//

import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage("notifications_analysis_completed") private var analysisCompleted = true
    @AppStorage("notifications_price_drop")         private var priceDrop         = true
    @AppStorage("notifications_new_similar")        private var newSimilar        = false
    @AppStorage("notifications_saved_searches")     private var savedSearches     = false
    @AppStorage("notifications_marketing")          private var marketing         = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                lumaSection("Notifications") {
                    notifRow(
                        icon: "checkmark.circle.fill", color: .green,
                        label: "Résultats d'analyse terminés",
                        subtitle: "Quand une analyse est prête",
                        binding: $analysisCompleted
                    )
                    lumaDivider()
                    notifRow(
                        icon: "arrow.down.circle.fill", color: .blue,
                        label: "Alertes baisse de prix",
                        subtitle: "Quand un article suit une baisse",
                        binding: $priceDrop
                    )
                    lumaDivider()
                    notifRow(
                        icon: "sparkles", color: .purple,
                        label: "Nouvelles annonces similaires",
                        subtitle: nil,
                        binding: $newSimilar
                    )
                    lumaDivider()
                    notifRow(
                        icon: "bookmark.fill", color: .orange,
                        label: "Rappels recherches sauvegardées",
                        subtitle: nil,
                        binding: $savedSearches
                    )
                    lumaDivider()
                    notifRow(
                        icon: "megaphone.fill", color: .pink,
                        label: "Notifications marketing",
                        subtitle: "Actualités et offres Amisa",
                        binding: $marketing
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Helpers Luma

    private func lumaSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func lumaDivider() -> some View {
        Divider().padding(.leading, 56)
    }

    private func notifRow(
        icon: String, color: Color,
        label: String, subtitle: String?,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay { Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: binding).labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }
}

#Preview {
    NavigationStack { NotificationsSettingsView() }
}
