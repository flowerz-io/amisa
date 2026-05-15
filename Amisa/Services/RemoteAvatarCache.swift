//
//  RemoteAvatarCache.swift
//  Balibu
//
//  Cache mémoire + déduplication des chargements pour les avatars distants (Google, Supabase).
//

import UIKit

final class RemoteAvatarCache: @unchecked Sendable {
    static let shared = RemoteAvatarCache()

    private let memory = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memory.countLimit = 80
    }

    func cachedImage(for urlString: String?) -> UIImage? {
        guard let key = Self.normalizedKey(urlString) else { return nil }
        return memory.object(forKey: key as NSString)
    }

    func image(for urlString: String?) async -> UIImage? {
        guard let key = Self.normalizedKey(urlString), let url = URL(string: key) else { return nil }

        if let hit = memory.object(forKey: key as NSString) {
            return hit
        }

        lock.lock()
        if let existing = inflight[key] {
            lock.unlock()
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else { return nil }
                memory.setObject(img, forKey: key as NSString)
                return img
            } catch {
                return nil
            }
        }

        inflight[key] = task
        lock.unlock()

        let img = await task.value

        lock.lock()
        inflight[key] = nil
        lock.unlock()

        return img
    }

    private static func normalizedKey(_ urlString: String?) -> String? {
        let t = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }
}
