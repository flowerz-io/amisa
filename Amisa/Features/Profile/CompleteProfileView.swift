//
//  CompleteProfileView.swift
//  Balibu
//
//  Étape obligatoire après première connexion Supabase (profil incomplet).
//

import PhotosUI
import SwiftUI
import UIKit

struct CompleteProfileView: View {
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedAvatar: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var userEditedFirstName = false
    @State private var userEditedLastName = false
    @State private var isApplyingPrefill = false

    private let avatarSize: CGFloat = 112

    private var hideNameFields: Bool {
        profileManager.mandatoryProfilePrefill?.hideNameFields == true
    }

    private var birthDateValid: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let bd = cal.startOfDay(for: birthDate)
        guard bd <= today else { return false }
        if let oldest = cal.date(byAdding: .year, value: -120, to: today) {
            guard bd >= oldest else { return false }
        }
        return true
    }

    private var canContinue: Bool {
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !fn.isEmpty && !ln.isEmpty && birthDateValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(String(localized: "Complète ton profil"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignTokens.textPrimary)

                    Text(String(localized: "Ces informations nous permettent de personnaliser ton expérience."))
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineSpacing(2)

                    HStack {
                        Spacer(minLength: 0)
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            ZStack(alignment: .bottom) {
                                avatarPreview
                                    .frame(width: avatarSize, height: avatarSize)
                                    .clipShape(Circle())

                                Text(String(localized: "Photo (optionnel)"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.55))
                                    .clipShape(Capsule())
                                    .padding(.bottom, 8)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if hideNameFields {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayFullName)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(DesignTokens.textPrimary)
                                Text(String(localized: "Prénom et nom déjà renseignés — tu peux passer à la date de naissance."))
                                    .font(.system(size: 13))
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                        } else {
                            TextField(String(localized: "Prénom"), text: $firstName)
                                .textContentType(.givenName)
                                .onChange(of: firstName) { _, _ in
                                    guard !isApplyingPrefill else { return }
                                    userEditedFirstName = true
                                }
                            Divider()
                            TextField(String(localized: "Nom"), text: $lastName)
                                .textContentType(.familyName)
                                .onChange(of: lastName) { _, _ in
                                    guard !isApplyingPrefill else { return }
                                    userEditedLastName = true
                                }
                            Divider()
                        }
                        DatePicker(
                            String(localized: "Date de naissance"),
                            selection: $birthDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                    }
                    .padding(16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignTokens.error)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        Task { await saveProfile() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(String(localized: "Continuer"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canContinue && !isSaving ? Color.accentColor : Color.accentColor.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue || isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .onAppear {
            applyMandatoryPrefill(profileManager.mandatoryProfilePrefill)
        }
        .onChange(of: profileManager.mandatoryProfilePrefill) { _, newValue in
            applyMandatoryPrefill(newValue)
        }
        .onChange(of: pickerItem) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run { pickedAvatar = ui }
                }
            }
        }
    }

    private var displayFullName: String {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = [f, l].filter { !$0.isEmpty }.joined(separator: " ")
        return joined.isEmpty ? "—" : joined
    }

    /// Met à jour les champs depuis `ProfileManager` sans écraser une saisie manuelle.
    private func applyMandatoryPrefill(_ prefill: MandatoryProfilePrefill?) {
        guard let prefill else { return }
        isApplyingPrefill = true
        if !userEditedFirstName {
            firstName = prefill.suggestedFirstName
        }
        if !userEditedLastName {
            lastName = prefill.suggestedLastName
        }
        isApplyingPrefill = false
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let pickedAvatar {
            Image(uiImage: pickedAvatar)
                .resizable()
                .scaledToFill()
        } else if let urlString = profileManager.mandatoryProfilePrefill?.avatarRemoteURL {
            ProfileAvatarCircleView(
                localUIImage: nil,
                remoteURLString: urlString,
                diameter: avatarSize,
                outerSeparatorRingColor: nil,
                innerAccentBorder: nil,
                fallbackSymbolName: "person.fill",
                fallbackFillColor: DesignTokens.accentMuted
            )
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(DesignTokens.accentMuted)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
    }

    @MainActor
    private func saveProfile() async {
        guard let uid = auth.currentUser?.id else {
            errorMessage = String(localized: "Session invalide.")
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let jpeg = pickedAvatar.flatMap { $0.jpegData(compressionQuality: 0.88) }
        let fallbackAvatarURL = pickedAvatar == nil ? profileManager.mandatoryProfilePrefill?.fallbackAvatarURLForUpsert : nil

        do {
            try await ProfileManager.shared.submitMandatoryProfile(
                userId: uid,
                firstName: firstName,
                lastName: lastName,
                birthDate: birthDate,
                avatarJPEGData: jpeg,
                fallbackAvatarURL: fallbackAvatarURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CompleteProfileView()
}
