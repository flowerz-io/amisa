//
//  AccountSettingsView.swift
//  Balibu
//
//  Paramètres du compte : e-mail, téléphone, nom d'utilisateur, suppression.
//

import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject private var auth = AuthManager.shared
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var username: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                lumaSection(String(localized: "Informations")) {
                    accountRow(icon: "envelope.fill", color: BrandColors.secondaryOrange, label: String(localized: "E-mail"), value: email.isEmpty ? "—" : email)
                    lumaDivider()
                    accountRow(icon: "phone.fill", color: .green, label: String(localized: "Téléphone"), value: phone.isEmpty ? "—" : phone)
                    lumaDivider()
                    accountRow(icon: "at.circle.fill", color: .orange, label: String(localized: "Nom d'utilisateur"), value: username.isEmpty ? "—" : username)
                }

                if auth.isAuthenticated {
                    lumaSection(String(localized: "Zone de danger")) {
                        NavigationLink {
                            DeleteAccountView()
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                Text(String(localized: "Supprimer mon compte"))
                                    .font(.system(size: 16))
                                    .foregroundStyle(.red)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: "Paramètres du compte"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { populateFromAuth() }
        .onChange(of: auth.currentUser?.id) { _, _ in populateFromAuth() }
    }

    private func populateFromAuth() {
        if let user = auth.currentUser {
            email = user.email ?? ""
            username = user.displayName
        }
        if let profile = ProfileManager.shared.profile {
            if let display = profile.displayName, !display.isEmpty {
                username = display
            }
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
