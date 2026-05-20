//
//  RemoteAvatarCache.swift
//  Balibu
//
//  Cache mémoire + déduplication des chargements pour les avatars distants (Google, Supabase).
//

import UIKit

final actor RemoteAvatarCache {
    static let shared = RemoteAvatarCache()

    private let memory = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memory.countLimit = 80
    }

    func image(for urlString: String?) async -> UIImage? {
        guard let key = Self.normalizedKey(urlString),
              let url = URL(string: key) else { return nil }

        if let hit = memory.object(forKey: key as NSString) {
            return hit
        }

        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else { return nil }
                return img
            } catch {
                return nil
            }
        }

        inflight[key] = task
        let img = await task.value

        if let img {
            memory.setObject(img, forKey: key as NSString)
        }

        inflight[key] = nil
        return img
    }

    private static func normalizedKey(_ urlString: String?) -> String? {
        let t = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }
}
