//
//  ShareExtensionNotificationScheduler.swift
//  AmisaShareExtension
//
//  Notification locale uniquement quand la recherche est terminée avec des résultats.
//

import Foundation
import UserNotifications

enum ShareNotificationScheduleOutcome: Sendable {
    case scheduled
    case denied
    case skipped(String)
    case failed(String)
}

enum ShareExtensionNotificationScheduler {
    private static let typeSearchResultsReady = "search_results_ready"

    private static var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    /// Notification « Résultats prêts » — uniquement si `listingsCount > 0`.
    static func notifySearchResultsReady(
        sessionId: String,
        listingsCount: Int,
        previewImageData: Data? = nil
    ) async -> ShareNotificationScheduleOutcome {
        guard listingsCount > 0 else {
            print("[SHARE_NOTIFICATION] skipped reason = zero_listings")
            return .skipped("zero_listings")
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Résultats prêts")
        content.body = String(
            format: String(localized: "%lld annonces Vinted trouvées"),
            Int64(listingsCount)
        )
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = ShareExtensionConstants.Notifications.shareResultsReadyCategory
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
        }
        content.userInfo = [
            ShareExtensionConstants.Notifications.typeUserInfoKey: typeSearchResultsReady,
            ShareExtensionConstants.Notifications.sessionIdUserInfoKey: sessionId,
        ]

        if let previewImageData,
           let attachment = makePreviewAttachment(data: previewImageData, sessionId: sessionId) {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: ShareExtensionConstants.Notifications.shareResultsRequestIdentifier(sessionId: sessionId),
            content: content,
            trigger: trigger
        )

        let outcome = await addRequest(request)
        if case .scheduled = outcome {
            print("[SHARE_NOTIFICATION] scheduled sessionId =", sessionId)
        }
        return outcome
    }

    private static func makePreviewAttachment(data: Data, sessionId: String) -> UNNotificationAttachment? {
        let dir = FileManager.default.temporaryDirectory
        let file = dir.appendingPathComponent("share-preview-\(sessionId).jpg")
        do {
            try data.write(to: file, options: .atomic)
            return try UNNotificationAttachment(
                identifier: "preview",
                url: file,
                options: nil
            )
        } catch {
            return nil
        }
    }

    private static func addRequest(_ request: UNNotificationRequest) async -> ShareNotificationScheduleOutcome {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            do {
                try await center.add(request)
                return .scheduled
            } catch {
                return .failed(error.localizedDescription)
            }

        case .denied:
            return .denied

        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    try await center.add(request)
                    return .scheduled
                }
                return .denied
            } catch {
                return .failed(error.localizedDescription)
            }

        @unknown default:
            return .failed(String(localized: "Statut inconnu"))
        }
    }
}
