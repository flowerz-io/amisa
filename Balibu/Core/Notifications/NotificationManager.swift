//
//  NotificationManager.swift
//  Balibu
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

    /// Met à jour le statut publié (à appeler après demande ou au lancement).
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Statut courant.
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Paramètres complets (alertes, son, badge, etc.).
    func notificationSettings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }

    /// Demande d’autorisation (alertes, son, badge).
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Programmation côté app (même contenu que l’extension) — ex. relance ou tests.
    func scheduleShareResultsReadyNotification(importId: UUID) async throws {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Balibu")
        content.body = String(localized: "Touchez pour voir les résultats")
        content.sound = .default
        content.categoryIdentifier = BalibuNotificationIdentifiers.shareResultsReadyCategory
        content.userInfo = [BalibuNotificationIdentifiers.importIdUserInfoKey: importId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: BalibuNotificationIdentifiers.shareResultsRequestIdentifier(importId: importId),
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    /// Annule la notification programmée / livrée pour cet import.
    func cancelShareResultsNotification(importId: UUID) {
        let id = BalibuNotificationIdentifiers.shareResultsRequestIdentifier(importId: importId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Libellé lisible pour debug / UI secondaire.
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
