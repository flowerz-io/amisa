import Foundation

#if DEBUG
enum DebugBackendHealthPing {
    /// Requête GET non bloquante au lancement (DEBUG uniquement).
    static func fireAndForget() {
        Task(priority: .background) {
            let url = AppConfig.healthURL
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? "<non-UTF-8, \(data.count) octets>"
                print("[Health] GET \(url.absoluteString) status=\(status) body=\(body)")
            } catch {
                print("[Health] GET \(url.absoluteString) échec: \(error)")
            }
        }
    }
}
#endif
