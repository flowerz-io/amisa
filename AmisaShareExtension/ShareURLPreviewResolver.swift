//
//  ShareURLPreviewResolver.swift
//  AmisaShareExtension
//
//  Aperçu pour partage URL : image directe → LinkPresentation → meta og/twitter.
//

import Foundation
import LinkPresentation
import UIKit
import UniformTypeIdentifiers

enum ShareURLPreviewResolver {
    /// Chaîne locale uniquement (sans backend). Retourne `nil` si aucune image exploitable.
    static func resolvePreview(for pageURL: URL) async -> UIImage? {
        let sanitized = pageURL.sanitizedForFetch
        print(
            "[ShareExtension] url detected=\(sanitized.absoluteString.prefix(min(200, sanitized.absoluteString.count)))"
        )

        if let img = await loadDirectImageIfApplicable(from: sanitized) {
            return img
        }

        if let img = await loadFromLinkPresentation(pageURL: sanitized) {
            return img
        }

        if let img = await loadFromHTMLMetaTags(pageURL: sanitized) {
            return img
        }

        return nil
    }

    // MARK: - Image directe (extension, Content-Type, sniff)

    private static func loadDirectImageIfApplicable(from url: URL) async -> UIImage? {
        let ext = url.pathExtension.lowercased()
        let knownExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "bmp", "heic", "heif"]
        if knownExtensions.contains(ext) {
            print("[ShareExtension] direct image url detected")
            return await downloadAndDecodeImage(from: url)
        }

        if await headIndicatesImage(url) {
            print("[ShareExtension] direct image url detected")
            return await downloadAndDecodeImage(from: url)
        }

        do {
            var req = URLRequest(url: url)
            req.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return nil }
            let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            if mime.contains("image/") || (data.count >= 12 && looksLikeImageData(data)) {
                print("[ShareExtension] direct image url detected")
                print("[ShareExtension] preview image downloaded bytes=\(data.count)")
                return imageFromData(data)
            }
        } catch {
            print("[ShareExtension] error=\(error.localizedDescription)")
        }
        return nil
    }

    private static func headIndicatesImage(_ url: URL) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("image/") ?? false
        } catch {
            return false
        }
    }

    private static func looksLikeImageData(_ data: Data) -> Bool {
        if data.count >= 3, data[0] == 0xFF, data[1] == 0xD8, data[2] == 0xFF { return true }
        if data.count >= 8, data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return true }
        if data.count >= 12 {
            let prefix = String(data: data.prefix(12), encoding: .ascii) ?? ""
            if prefix.hasPrefix("RIFF"), prefix.dropFirst(8).prefix(4) == "WEBP" { return true }
        }
        if data.count >= 6, data.starts(with: [0x47, 0x49, 0x46, 0x38]) { return true }
        return false
    }

    private static func downloadAndDecodeImage(from url: URL) async -> UIImage? {
        do {
            var req = URLRequest(url: url)
            req.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, _) = try await URLSession.shared.data(for: req)
            print("[ShareExtension] preview image downloaded bytes=\(data.count)")
            guard let img = imageFromData(data) else {
                if data.count > 12, String(data: data.prefix(12), encoding: .ascii)?.contains("WEBP") == true {
                    print("[ShareExtension] error=WebP non décodable avec UIImage(data:) sur cette build")
                }
                return nil
            }
            return img
        } catch {
            print("[ShareExtension] error=\(error.localizedDescription)")
            return nil
        }
    }

    private static func imageFromData(_ data: Data) -> UIImage? {
        if let img = UIImage(data: data) { return img }
        return nil
    }

    // MARK: - LinkPresentation

    private static func loadFromLinkPresentation(pageURL: URL) async -> UIImage? {
        print("[ShareExtension] lp metadata started")
        let provider = LPMetadataProvider()
        provider.shouldFetchSubresources = true

        let metadata: LPLinkMetadata? = await withCheckedContinuationV2 { resume in
            provider.startFetchingMetadata(for: pageURL) { meta, error in
                if let error {
                    print("[ShareExtension] error=\(error.localizedDescription)")
                    resume(nil)
                    return
                }
                resume(meta)
            }
        }

        guard let metadata else { return nil }

        if let imageProvider = metadata.imageProvider {
            print("[ShareExtension] lp imageProvider found")
            if let img = await loadUIImage(from: imageProvider) {
                return img
            }
        }
        if let iconProvider = metadata.iconProvider {
            print("[ShareExtension] lp iconProvider fallback found")
            if let img = await loadUIImage(from: iconProvider) {
                return img
            }
        }
        return nil
    }

    private static func loadUIImage(from itemProvider: NSItemProvider) async -> UIImage? {
        if let img = await loadUIImageObject(from: itemProvider) { return img }
        return await loadUIImageViaItemTypes(from: itemProvider)
    }

    private static func loadUIImageObject(from itemProvider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuationV2 { resume in
            _ = itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                resume(object as? UIImage)
            }
        }
    }

    private static func loadUIImageViaItemTypes(from itemProvider: NSItemProvider) async -> UIImage? {
        let types = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.webP.identifier,
            "public.image",
            "public.jpeg",
            "public.png",
        ]
        for typeId in types where itemProvider.hasItemConformingToTypeIdentifier(typeId) {
            let item: NSSecureCoding? = await withCheckedContinuationV2 { resume in
                itemProvider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                    resume(item)
                }
            }
            if let img = secureCodingToImage(item) { return img }
        }
        return nil
    }

    private static func secureCodingToImage(_ item: NSSecureCoding?) -> UIImage? {
        if let image = item as? UIImage { return image }
        if let data = item as? Data { return UIImage(data: data) }
        if let url = item as? URL,
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    // MARK: - HTML og:image / twitter:image

    private static func loadFromHTMLMetaTags(pageURL: URL) async -> UIImage? {
        print("[ShareExtension] html fallback started")
        do {
            var request = URLRequest(url: pageURL)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("text/html,application/xhtml+xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            let cap = min(data.count, 800_000)
            let snippet = data.prefix(cap)
            guard let html = String(data: snippet, encoding: .utf8)
                    ?? String(data: snippet, encoding: .isoLatin1) else { return nil }

            let urls = extractMetaImageCandidates(from: html, base: pageURL)
            for candidate in urls {
                if let img = await downloadAndDecodeImage(from: candidate) {
                    return img
                }
            }
        } catch {
            print("[ShareExtension] error=\(error.localizedDescription)")
        }
        return nil
    }

    static func extractMetaImageCandidates(from html: String, base: URL) -> [URL] {
        var ordered: [URL] = []
        var seen = Set<String>()
        let options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]

        let patterns: [(log: String, pattern: String)] = [
            ("og", #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#),
            ("og_rev", #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#),
            ("tw", #"<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']"#),
            ("tw_src", #"<meta[^>]+name=["']twitter:image:src["'][^>]+content=["']([^"']+)["']"#),
            ("tw_rev", #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["']"#),
            ("tw_src_rev", #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image:src["']"#),
        ]

        for tuple in patterns {
            guard let regex = try? NSRegularExpression(pattern: tuple.pattern, options: options) else { continue }
            let range = NSRange(location: 0, length: (html as NSString).length)
            for match in regex.matches(in: html, options: [], range: range) {
                guard match.numberOfRanges > 1,
                      let swiftRange = Range(match.range(at: 1), in: html) else { continue }
                let raw = String(html[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { continue }
                guard let absolute = resolveHref(raw, base: base) else { continue }
                let key = absolute.absoluteString
                if seen.insert(key).inserted {
                    switch tuple.log {
                    case "og", "og_rev":
                        print("[ShareExtension] og:image found=\(key.prefix(120))")
                    case "tw", "tw_src", "tw_rev", "tw_src_rev":
                        print("[ShareExtension] twitter:image found=\(key.prefix(120))")
                    default: break
                    }
                    ordered.append(absolute)
                }
            }
        }
        return ordered
    }

    private static func resolveHref(_ href: String, base: URL) -> URL? {
        let t = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let u = URL(string: t), u.scheme == "http" || u.scheme == "https" { return u }
        if t.hasPrefix("//"), let u = URL(string: "https:" + t) { return u }
        return URL(string: t, relativeTo: base)?.absoluteURL
    }
}

// MARK: - URL helpers

private extension URL {
    var sanitizedForFetch: URL {
        guard var c = URLComponents(url: self, resolvingAgainstBaseURL: true) else { return self }
        c.fragment = nil
        return c.url ?? self
    }
}

// MARK: - Continuation (non-throwing)

private func withCheckedContinuationV2<T>(
    _ body: (@escaping (T) -> Void) -> Void
) async -> T {
    await withCheckedContinuation { (checked: CheckedContinuation<T, Never>) in
        body { checked.resume(returning: $0) }
    }
}
