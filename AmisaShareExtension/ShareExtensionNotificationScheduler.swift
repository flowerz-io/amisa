//
//  ShareExtensionNotificationScheduler.swift
//  BalibuShareExtension
//
//  Programmation locale après enregistrement App Group (mêmes identifiants que l’app).
//

import Foundation
import UserNotifications

enum ShareNotificationScheduleOutcome: Sendable {
    /// Notification planifiée (autorisé ou provisionnel).
    case scheduled
    /// L’utilisateur a refusé ; l’app reste utilisable sans alerte locale.
    case denied
    /// Échec technique (rare).
    case failed(String)
}

enum ShareExtensionNotificationScheduler {
    private static var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    /// Pivot `sessionId` (aligné sur `AmisaNotificationIdentifiers.sessionIdUserInfoKey`).
    static func scheduleResultsReady(sessionId: String) async -> ShareNotificationScheduleOutcome {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Amisa")
        content.body = String(localized: "Touchez pour voir les résultats")
        content.sound = .default
        content.categoryIdentifier = ShareExtensionConstants.Notifications.shareResultsReadyCategory
        content.userInfo = [ShareExtensionConstants.Notifications.sessionIdUserInfoKey: sessionId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: ShareExtensionConstants.Notifications.shareResultsRequestIdentifier(sessionId: sessionId),
            content: content,
            trigger: trigger
        )

        return await addRequest(request)
    }

    /// Rétrocompat : import local uniquement (ancien flux).
    static func scheduleResultsReady(importId: UUID) async -> ShareNotificationScheduleOutcome {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Amisa")
        content.body = String(localized: "Touchez pour voir les résultats")
        content.sound = .default
        content.categoryIdentifier = ShareExtensionConstants.Notifications.shareResultsReadyCategory
        content.userInfo = [ShareExtensionConstants.Notifications.importIdUserInfoKey: importId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: ShareExtensionConstants.Notifications.shareResultsRequestIdentifier(importId: importId),
            content: content,
            trigger: trigger
        )

        return await addRequest(request)
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
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
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
