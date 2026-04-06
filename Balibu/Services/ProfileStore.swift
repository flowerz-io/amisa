import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var firstName: String
    @Published var lastName: String
    @Published var avatarFileName: String?

    private let firstKey = "balibu.profile.firstName"
    private let lastKey = "balibu.profile.lastName"
    private let avatarKey = "balibu.profile.avatarFileName"

    private init() {
        let d = UserDefaults.standard
        firstName = d.string(forKey: firstKey) ?? ""
        lastName = d.string(forKey: lastKey) ?? ""
        avatarFileName = d.string(forKey: avatarKey)
    }

    var displayName: String {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if f.isEmpty && l.isEmpty { return String(localized: "Utilisateur") }
        if l.isEmpty { return f }
        if f.isEmpty { return l }
        return "\(f) \(l)"
    }

    func save(firstName: String, lastName: String, avatarFileName: String?) {
        self.firstName = firstName
        self.lastName = lastName
        self.avatarFileName = avatarFileName
        let d = UserDefaults.standard
        d.set(firstName, forKey: firstKey)
        d.set(lastName, forKey: lastKey)
        if let avatarFileName {
            d.set(avatarFileName, forKey: avatarKey)
        } else {
            d.removeObject(forKey: avatarKey)
        }
    }

    func avatarImage() -> UIImage? {
        guard let name = avatarFileName else { return nil }
        return ImagePersistenceService.shared.loadUIImage(fileName: name)
    }
}
