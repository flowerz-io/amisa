//
//  AmisaApp.swift
//  Amisa
//

import SwiftUI
import Combine

@main
struct AmisaApp: App {
    @UIApplicationDelegateAdaptor(AmisaAppDelegate.self) private var appDelegate
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
