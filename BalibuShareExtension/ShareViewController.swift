//
//  ShareViewController.swift
//  BalibuShareExtension
//
//  Share Extension : récupère l'image, la sauvegarde dans l'App Group, ouvre l'app principale.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let openURLScheme = "balibu://shared"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        processSharedContent()
    }

    private func processSharedContent() {
        Task {
            let imageData = await ShareItemExtractor.extractImage(from: extensionContext)
            await MainActor.run {
                if let data = imageData, ShareExtensionStorage.saveImage(data) != nil {
                    openMainApp()
                } else {
                    showError()
                }
            }
        }
    }

    private func openMainApp() {
        guard let url = URL(string: openURLScheme) else {
            finish()
            return
        }
        var responder: UIResponder? = self
        while let r = responder {
            if let selector = NSSelectorFromString("openURL:") as Selector?,
               r.responds(to: selector) {
                r.perform(selector, with: url)
                break
            }
            responder = r.next
        }
        finish()
    }

    private func showError() {
        let alert = UIAlertController(
            title: "Image requise",
            message: "Veuillez partager une image.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.finish()
        })
        present(alert, animated: true)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
