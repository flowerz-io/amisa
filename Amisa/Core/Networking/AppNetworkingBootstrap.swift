import Foundation

/// Point d’entrée réseau au lancement (une seule exécution en DEBUG par process).
///
/// Peut être invoqué depuis `AmisaApp.init()`, `AppRouter`, ou `AmisaAppDelegate`.
enum AppNetworkingBootstrap {
    private static let lock = NSLock()
    private static var didRun = false

    static func onAppLaunch() {
#if DEBUG
        lock.lock()
        defer { lock.unlock() }
        guard !didRun else { return }
        didRun = true
        DebugBackendHealthPing.fireAndForget()
#endif
    }
}
