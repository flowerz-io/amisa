//
//  PhotoLibraryPicker.swift
//  Amisa
//
//  Sélection galerie via PHPicker (fiable vs PhotosPicker sheet sur caméra plein écran).
//

import PhotosUI
import SwiftUI
import UIKit

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker

        init(parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self)
            else {
                Task { @MainActor in self.parent.onCancel() }
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [parent] object, error in
                Task { @MainActor in
                    if let image = object as? UIImage {
                        parent.onImagePicked(image)
                    } else {
                        if let error {
                            print("[PICK_IMAGE] PHPicker load error:", error)
                        }
                        parent.onCancel()
                    }
                }
            }
        }
    }
}
