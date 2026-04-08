//
//  InstagramPostResolver.swift
//  BalibuShareExtension
//
//  Résolution des médias à partir de l’URL du post (pas depuis des URLs CDN « copiées navigateur »).
//

import Foundation
import UIKit

/// Alias conservé pour compatibilité avec les usages existants.
enum InstagramURLDetector {
    static func isInstagram(_ url: URL) -> Bool {
        SharedSourcePlatformDetector.isInstagram(url)
    }
}

/// Charge les images du post en récupérant la page HTML puis les URLs embarquées (display_url).
struct InstagramPostResolver: ShareLinkResolving {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadCandidateImages(from pageURL: URL) async throws -> [UIImage] {
        guard let fetchURL = Self.canonicalFetchURL(from: pageURL) else {
            throw InstagramResolverError.invalidPostURL
        }
        var request = URLRequest(url: fetchURL)
        request.setValue(Self.mobileSafariUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw InstagramResolverError.network
        }
        guard (200 ... 399).contains(http.statusCode) else {
            throw InstagramResolverError.httpStatus(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw InstagramResolverError.emptyResponse
        }

        let imgIndex = Self.parseImgIndex(from: pageURL)
        var mediaURLs = Self.extractDisplayURLs(from: html)
        if mediaURLs.isEmpty, let og = Self.extractOgImageURL(from: html) {
            mediaURLs = [og]
        }
        guard !mediaURLs.isEmpty else {
            throw InstagramResolverError.noMediaInPage
        }

        let urlsToDownload: [URL]
        if let idx = imgIndex, idx >= 1, idx <= mediaURLs.count {
            urlsToDownload = [mediaURLs[idx - 1]]
        } else if mediaURLs.count > 1, imgIndex == nil {
            urlsToDownload = mediaURLs
        } else {
            urlsToDownload = [mediaURLs[0]]
        }

        var images: [UIImage] = []
        for url in urlsToDownload {
            var imgReq = URLRequest(url: url)
            imgReq.setValue(Self.mobileSafariUserAgent, forHTTPHeaderField: "User-Agent")
            let (imgData, imgResp) = try await session.data(for: imgReq)
            guard let imgHttp = imgResp as? HTTPURLResponse, (200 ... 399).contains(imgHttp.statusCode),
                  let ui = UIImage(data: imgData) else {
                continue
            }
            images.append(ui)
        }

        guard !images.isEmpty else {
            throw InstagramResolverError.downloadFailed
        }
        return images
    }

    // MARK: - URL

    private static func canonicalFetchURL(from url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        let path = (components?.path ?? url.path).lowercased()

        if let shortcode = extractShortcode(path: path, prefix: "/p/") {
            components?.scheme = "https"
            components?.host = "www.instagram.com"
            components?.path = "/p/\(shortcode)/"
            components?.query = nil
            return components?.url
        }
        if let shortcode = extractShortcode(path: path, prefix: "/reel/") {
            components?.scheme = "https"
            components?.host = "www.instagram.com"
            components?.path = "/reel/\(shortcode)/"
            components?.query = nil
            return components?.url
        }

        components?.query = nil
        components?.fragment = nil
        return components?.url ?? url
    }

    private static func extractShortcode(path: String, prefix: String) -> String? {
        guard let r = path.range(of: prefix) else { return nil }
        let rest = path[r.upperBound...]
        let token = rest.split(separator: "/").first.map(String.init) ?? ""
        return token.isEmpty ? nil : token
    }

    private static func parseImgIndex(from url: URL) -> Int? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }
        guard let raw = items.first(where: { $0.name == "img_index" })?.value,
              let i = Int(raw), i >= 1 else {
            return nil
        }
        return i
    }

    // MARK: - HTML

    private static func extractDisplayURLs(from html: String) -> [URL] {
        let marker = "\"display_url\":\""
        var urls: [URL] = []
        var searchStart = html.startIndex
        while let range = html.range(of: marker, range: searchStart ..< html.endIndex) {
            let valueStart = range.upperBound
            if let end = html[valueStart...].firstIndex(of: "\"") {
                let raw = String(html[valueStart ..< end])
                let cleaned = decodeJSONStringEscapes(raw)
                if let u = URL(string: cleaned), looksLikePostMediaURL(u) {
                    urls.append(u)
                }
            }
            searchStart = range.upperBound
        }

        var seen = Set<String>()
        var unique: [URL] = []
        for u in urls {
            let s = u.absoluteString
            if !seen.contains(s) {
                seen.insert(s)
                unique.append(u)
            }
        }
        return unique
    }

    private static func looksLikePostMediaURL(_ url: URL) -> Bool {
        let h = url.host?.lowercased() ?? ""
        let p = url.path.lowercased()
        if h.contains("cdninstagram") || h.contains("fbcdn.net") { return true }
        if p.hasSuffix(".jpg") || p.hasSuffix(".jpeg") || p.hasSuffix(".webp") { return true }
        return url.absoluteString.count > 80
    }

    private static func extractOgImageURL(from html: String) -> URL? {
        let key = "property=\"og:image\""
        guard let r0 = html.range(of: key, options: .caseInsensitive) else { return nil }
        let tail = html[r0.upperBound...]
        guard let cOpen = tail.range(of: "content=\"") else { return nil }
        let afterContent = tail[cOpen.upperBound...]
        guard let quote = afterContent.firstIndex(of: "\"") else { return nil }
        let raw = String(afterContent[..<quote])
        return URL(string: raw)
    }

    private static func decodeJSONStringEscapes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
    }

    private static let mobileSafariUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}

enum InstagramResolverError: LocalizedError {
    case invalidPostURL
    case network
    case httpStatus(Int)
    case emptyResponse
    case noMediaInPage
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidPostURL:
            return "Lien Instagram invalide."
        case .network:
            return "Réseau indisponible."
        case .httpStatus(let c):
            return "Instagram a répondu (\(c))."
        case .emptyResponse:
            return "Réponse Instagram vide."
        case .noMediaInPage:
            return "Impossible de lire les médias de ce post (page ou format non reconnu)."
        case .downloadFailed:
            return "Téléchargement de l’image impossible."
        }
    }
}
