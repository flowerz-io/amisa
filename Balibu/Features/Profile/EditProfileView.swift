import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    profileImage
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    Spacer()
                }
                .listRowBackground(Color.clear)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(String(localized: "Choisir une photo"), systemImage: "photo")
                }
            }

            Section {
                TextField(String(localized: "Prénom"), text: $firstName)
                TextField(String(localized: "Nom"), text: $lastName)
            }
        }
        .navigationTitle(String(localized: "Modifier le profil"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer")) { saveAndDismiss() }
            }
        }
        .onAppear {
            firstName = store.firstName
            lastName = store.lastName
            pickedImage = store.avatarImage()
        }
        .onChange(of: pickedItem) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run { pickedImage = ui }
                }
            }
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let pickedImage {
            Image(uiImage: pickedImage)
                .resizable()
                .scaledToFill()
        } else if let ui = store.avatarImage() {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }

    private func saveAndDismiss() {
        var avatarName: String? = store.avatarFileName
        if pickedItem != nil, let pickedImage, let data = pickedImage.jpegData(compressionQuality: 0.88) {
            if let old = store.avatarFileName {
                ImagePersistenceService.shared.deleteImage(fileName: old)
            }
            avatarName = ImagePersistenceService.shared.saveImage(data)
        }
        store.save(firstName: firstName, lastName: lastName, avatarFileName: avatarName)
        dismiss()
    }
}
