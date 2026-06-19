//
//  DeleteAccountView.swift
//  Amisa
//
//  Flux de suppression de compte — avertissement puis confirmation définitive.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .warning
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private enum Step {
        case warning
        case confirm
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch step {
                case .warning:
                    warningContent
                case .confirm:
                    confirmContent
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.error)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: "Supprimer mon compte"))
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isDeleting)
    }

    // MARK: - Étape 1 — Avertissement

    private var warningContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                Text(String(localized: "Action irréversible"))
                    .font(.system(size: 20, weight: .bold))
            }

            Text(String(localized: "La suppression de ton compte est définitive. Tu ne pourras pas récupérer tes données."))
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                deletionBullet(String(localized: "Ton compte Amisa et ton profil"))
                deletionBullet(String(localized: "Tes recherches enregistrées et alertes"))
                deletionBullet(String(localized: "Tes analyses et favoris locaux"))
                deletionBullet(String(localized: "Tes photos de profil sur nos serveurs"))
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(String(localized: "Cette action ne peut pas être annulée. Aucun e-mail au support n’est nécessaire — la suppression se fait directement dans l’application."))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                step = .confirm
                errorMessage = nil
            } label: {
                Text(String(localized: "Je comprends, continuer"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Étape 2 — Confirmation définitive

    private var confirmContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "Confirmer la suppression"))
                .font(.system(size: 20, weight: .bold))

            Text(String(localized: "Ton compte et toutes les données associées seront supprimés immédiatement. Tu seras déconnecté automatiquement."))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await performDeletion() }
            } label: {
                Group {
                    if isDeleting {
                        ProgressView().tint(.white)
                    } else {
                        Text(String(localized: "Supprimer définitivement"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)

            Button(String(localized: "Annuler")) {
                dismiss()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .disabled(isDeleting)
        }
    }

    private func deletionBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func performDeletion() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await DeleteAccountService.shared.deleteCurrentAccount()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { DeleteAccountView() }
}
