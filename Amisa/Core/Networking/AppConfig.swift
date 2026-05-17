import Foundation

enum AppConfig {
    static let backendBaseURLString = "https://amisa-production.up.railway.app"
    static var backendBaseURL: URL { URL(string: backendBaseURLString)! }
    static var analyzeSearchURL: URL { backendBaseURL.appendingPathComponent("analyze-search") }
    static var resolveSharedURLURL: URL { backendBaseURL.appendingPathComponent("resolve-shared-url") }
    static var healthURL: URL { backendBaseURL.appendingPathComponent("health") }
}
