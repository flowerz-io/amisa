//
//  NotificationManager.swift
//  Amisa
//
//  Notifications locales : autorisation, programmation, paramètres.
//

import Combine
import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func notificationSettings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Notification « Résultats prêts » — session Railway terminée avec annonces.
    func notifySearchResultsReady(
        sessionId: String,
        listingsCount: Int,
        previewImageData: Data? = nil
    ) async throws {
        guard listingsCount > 0 else {
            print("[SHARE_NOTIFICATION] skipped reason = zero_listings")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Résultats prêts")
        content.body = String(
            format: String(localized: "%lld annonces Vinted trouvées"),
            Int64(listingsCount)
        )
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = AmisaNotificationIdentifiers.shareResultsReadyCategory
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
        }
        content.userInfo = [
            AmisaNotificationIdentifiers.typeUserInfoKey: AmisaNotificationIdentifiers.searchResultsReadyType,
            AmisaNotificationIdentifiers.sessionIdUserInfoKey: sessionId,
        ]

        if let previewImageData {
            let dir = FileManager.default.temporaryDirectory
            let file = dir.appendingPathComponent("share-preview-\(sessionId).jpg")
            try previewImageData.write(to: file, options: .atomic)
            if let attachment = try? UNNotificationAttachment(
                identifier: "preview",
                url: file,
                options: nil
            ) {
                content.attachments = [attachment]
            }
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: AmisaNotificationIdentifiers.shareResultsRequestIdentifier(sessionId: sessionId),
            content: content,
            trigger: trigger
        )
        try await center.add(request)
        print("[SHARE_NOTIFICATION] scheduled sessionId =", sessionId)
    }

    func cancelShareResultsNotification(sessionId: String) {
        let id = AmisaNotificationIdentifiers.shareResultsRequestIdentifier(sessionId: sessionId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelShareResultsNotification(importId: UUID) {
        let id = AmisaNotificationIdentifiers.shareResultsRequestIdentifier(importId: importId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    static func localizedDescription(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return String(localized: "Non déterminé")
        case .denied:
            return String(localized: "Refusé")
        case .authorized:
            return String(localized: "Autorisé")
        case .provisional:
            return String(localized: "Provisoire")
        case .ephemeral:
            return String(localized: "Éphémère")
        @unknown default:
            return String(localized: "Inconnu")
        }
    }
}
