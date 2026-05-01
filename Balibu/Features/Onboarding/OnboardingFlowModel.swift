//
//  OnboardingFlowModel.swift
//  Balibu
//

import SwiftUI
import Combine

// MARK: - Enums

enum OnboardingStep: Int, CaseIterable {
    case hero
    case gender
    case country
    case demo
    case paywall
}

enum OnboardingGender: String {
    case female, male

    var displayName: String { self == .female ? "Femme" : "Homme" }

    var icon: String { self == .female ? "figure.stand.dress" : "figure.stand" }

    var outfitEmojis: [String] {
        self == .female
            ? ["🧥", "👜", "👠"]
            : ["🧥", "👟", "🧢"]
    }

    var gradientColors: [Color] {
        self == .female
            ? [Color(red: 0.95, green: 0.72, blue: 0.80), Color(red: 0.88, green: 0.50, blue: 0.65)]
            : [Color(red: 0.20, green: 0.35, blue: 0.60), Color(red: 0.10, green: 0.22, blue: 0.45)]
    }
}

enum OnboardingCountry: String, CaseIterable, Identifiable {
    case france, uk, europe, us, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .france: "France"
        case .uk:     "Royaume-Uni"
        case .europe: "Europe"
        case .us:     "États-Unis"
        case .other:  "Autre"
        }
    }

    var flag: String {
        switch self {
        case .france: "🇫🇷"
        case .uk:     "🇬🇧"
        case .europe: "🇪🇺"
        case .us:     "🇺🇸"
        case .other:  "🌍"
        }
    }
}

// MARK: - Mock data for demo

struct OnboardingMockListing: Identifiable {
    let id = UUID()
    let title: String
    let brand: String
    let price: String
    let size: String?
    let source: String
    let sourceColor: Color
    let gradientColors: [Color]
}

extension OnboardingMockListing {
    static let samples: [OnboardingMockListing] = [
        OnboardingMockListing(
            title: "Veste biker cuir",
            brand: "Schott NYC",
            price: "89 €",
            size: "M",
            source: "Vinted",
            sourceColor: Color(red: 0.13, green: 0.73, blue: 0.50),
            gradientColors: [Color(red: 0.18, green: 0.15, blue: 0.12), Color(red: 0.35, green: 0.28, blue: 0.22)]
        ),
        OnboardingMockListing(
            title: "Air Force 1 '07",
            brand: "Nike",
            price: "120 €",
            size: "42",
            source: "Grailed",
            sourceColor: Color(red: 0.97, green: 0.33, blue: 0.18),
            gradientColors: [Color(red: 0.88, green: 0.86, blue: 0.82), Color(red: 0.76, green: 0.74, blue: 0.70)]
        ),
        OnboardingMockListing(
            title: "Trench coat classique",
            brand: "Burberry",
            price: "185 €",
            size: "S",
            source: "eBay",
            sourceColor: Color(red: 0.23, green: 0.49, blue: 0.96),
            gradientColors: [Color(red: 0.82, green: 0.74, blue: 0.60), Color(red: 0.68, green: 0.58, blue: 0.44)]
        ),
        OnboardingMockListing(
            title: "Casquette 6-panel",
            brand: "Supreme",
            price: "55 €",
            size: nil,
            source: "Depop",
            sourceColor: Color(red: 0.96, green: 0.22, blue: 0.38),
            gradientColors: [Color(red: 0.82, green: 0.10, blue: 0.10), Color(red: 0.58, green: 0.08, blue: 0.08)]
        ),
        OnboardingMockListing(
            title: "Manteau laine camel",
            brand: "Sandro",
            price: "95 €",
            size: "38",
            source: "Vinted",
            sourceColor: Color(red: 0.13, green: 0.73, blue: 0.50),
            gradientColors: [Color(red: 0.80, green: 0.68, blue: 0.52), Color(red: 0.65, green: 0.54, blue: 0.38)]
        ),
    ]
}

// MARK: - Demo items

struct OnboardingDemoItem: Identifiable {
    let id: Int
    let label: String
    let focusPiece: String
    let outfitEmojis: [String]
    let gradientColors: [Color]
}

extension OnboardingDemoItem {
    static let female: [OnboardingDemoItem] = [
        OnboardingDemoItem(
            id: 0,
            label: "Look Parisienne",
            focusPiece: "Manteau camel",
            outfitEmojis: ["🧥", "👜", "👠"],
            gradientColors: [Color(red: 0.85, green: 0.72, blue: 0.58), Color(red: 0.70, green: 0.56, blue: 0.40)]
        ),
        OnboardingDemoItem(
            id: 1,
            label: "Street Chic",
            focusPiece: "Sneakers",
            outfitEmojis: ["🥼", "👟", "🕶️"],
            gradientColors: [Color(red: 0.14, green: 0.14, blue: 0.18), Color(red: 0.28, green: 0.26, blue: 0.34)]
        ),
        OnboardingDemoItem(
            id: 2,
            label: "Summer Luxe",
            focusPiece: "Robe midi",
            outfitEmojis: ["👗", "🌿", "💫"],
            gradientColors: [Color(red: 0.90, green: 0.82, blue: 0.72), Color(red: 0.78, green: 0.68, blue: 0.56)]
        ),
        OnboardingDemoItem(
            id: 3,
            label: "Dark Academia",
            focusPiece: "Veste en cuir",
            outfitEmojis: ["🧥", "👖", "🎒"],
            gradientColors: [Color(red: 0.18, green: 0.28, blue: 0.42), Color(red: 0.12, green: 0.20, blue: 0.35)]
        ),
    ]

    static let male: [OnboardingDemoItem] = [
        OnboardingDemoItem(
            id: 0,
            label: "Leather Edge",
            focusPiece: "Veste en cuir",
            outfitEmojis: ["🧥", "👖", "👟"],
            gradientColors: [Color(red: 0.14, green: 0.13, blue: 0.11), Color(red: 0.30, green: 0.25, blue: 0.20)]
        ),
        OnboardingDemoItem(
            id: 1,
            label: "Sneakerhead",
            focusPiece: "Nike Dunk Low",
            outfitEmojis: ["👕", "🩳", "👟"],
            gradientColors: [Color(red: 0.16, green: 0.22, blue: 0.58), Color(red: 0.28, green: 0.36, blue: 0.78)]
        ),
        OnboardingDemoItem(
            id: 2,
            label: "Urban Cool",
            focusPiece: "Casquette",
            outfitEmojis: ["🧢", "🧥", "👟"],
            gradientColors: [Color(red: 0.78, green: 0.10, blue: 0.10), Color(red: 0.55, green: 0.08, blue: 0.08)]
        ),
        OnboardingDemoItem(
            id: 3,
            label: "Smart Casual",
            focusPiece: "Chemise oxford",
            outfitEmojis: ["👔", "🧥", "⌚"],
            gradientColors: [Color(red: 0.32, green: 0.35, blue: 0.40), Color(red: 0.22, green: 0.25, blue: 0.30)]
        ),
    ]
}

// MARK: - Model

@MainActor
final class OnboardingFlowModel: ObservableObject {
    @Published var step: OnboardingStep = .hero
    @Published var gender: OnboardingGender?
    @Published var country: OnboardingCountry?
    @Published var selectedDemoIndex: Int?

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var demoItems: [OnboardingDemoItem] {
        gender == .male ? OnboardingDemoItem.male : OnboardingDemoItem.female
    }

    func advance() {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: step), idx + 1 < all.count else {
            onComplete(); return
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            step = all[idx + 1]
        }
    }

    func advance(to target: OnboardingStep) {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            step = target
        }
    }

    func complete() { onComplete() }
}
