import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Date()

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var bannerPickerItem: PhotosPickerItem?

    @State private var pickedProfileImage: UIImage?
    @State private var pickedBannerImage: UIImage?

    @State private var profilePhotoChanged = false
    @State private var bannerPhotoChanged = false
    @State private var isSaving = false

    private let avatarPreviewSize: CGFloat = 144

    private var bannerPlaceholderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.35),
                BrandColors.secondary.opacity(0.22),
                Color.black.opacity(colorScheme == .dark ? 0.45 : 0.25),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PhotosPicker(selection: $bannerPickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        bannerPreviewContent
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                        Label(String(localized: "Changer la bannière"), systemImage: "photo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(12)
                    }
                }
                .buttonStyle(.plain)

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
            firstName = store.firstName
            lastName = store.lastName
            pickedProfileImage = store.avatarImage()
            pickedBannerImage = store.bannerImage()
            profilePhotoChanged = false
            bannerPhotoChanged = false
            if let bd = profileManager.profile?.birthDate {
                birthDate = bd
            }
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
        .onChange(of: bannerPickerItem) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run {
                        pickedBannerImage = ui
                        bannerPhotoChanged = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bannerPreviewContent: some View {
        if let pickedBannerImage {
            Image(uiImage: pickedBannerImage)
                .resizable()
                .scaledToFill()
        } else if let ui = store.bannerImage() {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            bannerPlaceholderGradient
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
        var bannerName: String? = store.bannerFileName

        if profilePhotoChanged, let pickedProfileImage,
           let data = pickedProfileImage.jpegData(compressionQuality: 0.88) {
            if let old = store.avatarFileName {
                ImagePersistenceService.shared.deleteImage(fileName: old)
            }
            avatarName = ImagePersistenceService.shared.saveImage(data)
        }

        if bannerPhotoChanged, let pickedBannerImage,
           let data = pickedBannerImage.jpegData(compressionQuality: 0.88) {
            if let old = store.bannerFileName {
                ImagePersistenceService.shared.deleteImage(fileName: old)
            }
            bannerName = ImagePersistenceService.shared.saveImage(data)
        }

        if auth.isAuthenticated, let uid = auth.currentUser?.id {
            await saveAuthenticatedProfile(
                userId: uid,
                avatarFileName: avatarName,
                bannerFileName: bannerName
            )
        } else {
            store.save(
                firstName: firstName,
                lastName: lastName,
                avatarFileName: avatarName,
                bannerFileName: bannerName,
                mergeRemoteURLs: false
            )
        }

        dismiss()
    }

    private func saveAuthenticatedProfile(userId: String, avatarFileName: String?, bannerFileName: String?) async {
        var avatarURL = profileManager.profile?.avatarURL
        var bannerURL = profileManager.profile?.bannerURL

        if profilePhotoChanged, let pickedProfileImage,
           let data = pickedProfileImage.jpegData(compressionQuality: 0.88) {
            if let url = try? await SupabaseManager.shared.uploadProfileImage(imageData: data, userId: userId) {
                avatarURL = url
            }
        }

        if bannerPhotoChanged, let pickedBannerImage,
           let data = pickedBannerImage.jpegData(compressionQuality: 0.88) {
            if let url = try? await SupabaseManager.shared.uploadBannerImage(imageData: data, userId: userId) {
                bannerURL = url
            }
        }

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        let row = UserProfile(
            id: userId,
            firstName: trimmedFirst,
            lastName: trimmedLast,
            birthDate: birthDate,
            avatarURL: avatarURL,
            bannerURL: bannerURL,
            createdAt: profileManager.profile?.createdAt,
            updatedAt: Date()
        )

        store.save(
            firstName: trimmedFirst,
            lastName: trimmedLast,
            avatarFileName: avatarFileName,
            bannerFileName: bannerFileName,
            mergeRemoteURLs: false
        )

        await profileManager.updateProfile(row)
    }
}
