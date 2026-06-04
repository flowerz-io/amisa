import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Date()

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var pickedProfileImage: UIImage?
    @State private var profilePhotoChanged = false
    @State private var isSaving = false

    private let avatarPreviewSize: CGFloat = 144

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Spacer(minLength: 0)
                    PhotosPicker(selection: $profilePickerItem, matching: .images) {
                        ZStack(alignment: .bottom) {
                            profileImagePreview
                                .frame(width: avatarPreviewSize, height: avatarPreviewSize)
                                .clipShape(Circle())

                            Text(String(localized: "Choisir"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(.bottom, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    TextField(String(localized: "Prénom"), text: $firstName)
                        .textContentType(.givenName)
                    Divider()
                    TextField(String(localized: "Nom"), text: $lastName)
                        .textContentType(.familyName)
                    if auth.isAuthenticated {
                        Divider()
                        DatePicker(
                            String(localized: "Date de naissance"),
                            selection: $birthDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                    }
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "Modifier le profil"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer")) {
                    Task { await saveAndDismiss() }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            if auth.isAuthenticated, let p = profileManager.profile {
                firstName = p.firstName ?? store.firstName
                lastName = p.lastName ?? store.lastName
                if let bd = p.birthDate { birthDate = bd }
            } else {
                firstName = store.firstName
                lastName = store.lastName
            }
            pickedProfileImage = store.avatarImage()
            profilePhotoChanged = false
        }
        .onChange(of: profilePickerItem) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run {
                        pickedProfileImage = ui
                        profilePhotoChanged = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var profileImagePreview: some View {
        if let pickedProfileImage {
            Image(uiImage: pickedProfileImage)
                .resizable()
                .scaledToFill()
        } else {
            ProfileAvatarCircleView(
                localUIImage: store.avatarImage(),
                remoteURLString: store.avatarRemoteURLString,
                diameter: avatarPreviewSize,
                initials: store.initials,
                outerSeparatorRingColor: nil,
                innerAccentBorder: nil,
                fallbackSymbolName: "person.fill",
                fallbackFillColor: DesignTokens.accentMuted
            )
        }
    }

    @MainActor
    private func saveAndDismiss() async {
        isSaving = true
        defer { isSaving = false }

        var avatarName: String? = store.avatarFileName

        if profilePhotoChanged, let pickedProfileImage,
           let data = pickedProfileImage.jpegData(compressionQuality: 0.88) {
            if let old = store.avatarFileName {
                ImagePersistenceService.shared.deleteImage(fileName: old)
            }
            avatarName = ImagePersistenceService.shared.saveImage(data)
        }

        if auth.isAuthenticated, let uid = auth.currentUser?.id {
            await saveAuthenticatedProfile(userId: uid, avatarFileName: avatarName)
        } else {
            store.save(
                firstName: firstName,
                lastName: lastName,
                avatarFileName: avatarName,
                bannerFileName: store.bannerFileName,
                mergeRemoteURLs: false
            )
        }

        dismiss()
    }

    private func saveAuthenticatedProfile(userId: String, avatarFileName: String?) async {
        var avatarURL = profileManager.profile?.avatarURL
        let bannerURL = profileManager.profile?.bannerURL

        if profilePhotoChanged, let pickedProfileImage,
           let data = pickedProfileImage.jpegData(compressionQuality: 0.88) {
            if let url = try? await SupabaseManager.shared.uploadProfileImage(imageData: data, userId: userId) {
                avatarURL = url
            }
        }

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        var row = UserProfile(
            id: userId,
            firstName: trimmedFirst,
            lastName: trimmedLast,
            birthDate: birthDate,
            gender: profileManager.profile?.gender,
            country: profileManager.profile?.country,
            avatarURL: avatarURL,
            bannerURL: bannerURL,
            createdAt: profileManager.profile?.createdAt,
            updatedAt: Date()
        )
        row.applyComputedDisplayName()

        store.save(
            firstName: trimmedFirst,
            lastName: trimmedLast,
            avatarFileName: avatarFileName,
            bannerFileName: store.bannerFileName,
            mergeRemoteURLs: false
        )

        await profileManager.updateProfile(row)
    }
}
