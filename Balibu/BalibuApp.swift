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
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            AppRouter(router: router)
                .environmentObject(router)
                .onOpenURL { url in
                    router.handleIncomingURL(url)
                }
        }
    }
}
