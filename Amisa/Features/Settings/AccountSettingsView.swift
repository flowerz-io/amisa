//
//  AccountSettingsView.swift
//  Balibu
//
//  Paramètres du compte : e-mail, téléphone, nom d'utilisateur.
//

import SwiftUI

struct AccountSettingsView: View {
    // TODO: Brancher sur AuthManager / ProfileManager quand Supabase est configuré
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var username: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                lumaSection("Informations") {
                    accountRow(icon: "envelope.fill",   color: .blue,   label: "E-mail",           value: email.isEmpty   ? "—" : email)
                    lumaDivider()
                    accountRow(icon: "phone.fill",      color: .green,  label: "Téléphone",        value: phone.isEmpty   ? "—" : phone)
                    lumaDivider()
                    accountRow(icon: "at.circle.fill",  color: .orange, label: "Nom d'utilisateur", value: username.isEmpty ? "—" : username)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Paramètres du compte")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { populateFromAuth() }
    }

    private func populateFromAuth() {
        // TODO: lire depuis ProfileManager.shared.profile quand Supabase est actif
        if let user = AuthManager.shared.currentUser {
            email    = user.email ?? ""
            username = user.displayName
        }
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

    private func accountRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay { Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }
}

#Preview {
    NavigationStack { AccountSettingsView() }
}
