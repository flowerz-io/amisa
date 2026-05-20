//
//  ProvidersSettingsView.swift
//  Balibu
//

import SwiftUI

struct ProvidersSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Amisa recherche les annonces sur Vinted à partir de tes photos ou de tes requêtes texte. Les autres places de marché ne sont pas prises en charge pour l’instant.")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                HStack(spacing: 12) {
                    ProviderLogoView(
                        source: "Vinted",
                        fallbackLabel: "Vinted",
                        logoHeight: 20,
                        logoMaxWidth: 72
                    )
                    Text("Vinted")
                        .font(.system(size: 17, weight: .medium))
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.large)
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Recherche Vinted")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
      ProvidersSettingsView()
    }
}
