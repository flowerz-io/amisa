//
//  AmisaAppDelegate.swift
//  Balibu
//
//  Délégation UserNotifications : tap sur la notification + présentation en foreground.
//

import UIKit
import UserNotifications

final class AmisaAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var router: Router?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LegacyAmisaStorageMigration.runAtLaunch()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        guard category == AmisaNotificationIdentifiers.shareResultsReadyCategory else {
            completionHandler()
            return
        }
        Task { @MainActor in
            router?.handleShareResultsNotificationResponse(userInfo: response.notification.request.content.userInfo)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier
        guard category == AmisaNotificationIdentifiers.shareResultsReadyCategory else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound])
    }
}
