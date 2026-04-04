//
//  BalibuApp.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine

@main
struct BalibuApp: App {
    @UIApplicationDelegateAdaptor(BalibuAppDelegate.self) private var appDelegate
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            AppRouter(router: router, appDelegate: appDelegate)
                .environmentObject(router)
                .onOpenURL { url in
                    router.handleIncomingURL(url)
                }
        }
    }
}
