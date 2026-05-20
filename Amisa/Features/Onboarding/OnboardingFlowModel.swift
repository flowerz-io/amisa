//
//  OnboardingFlowModel.swift
//  Balibu
//
//  Flux de navigation et états de l'onboarding.
//  Toute la data fake est dans OnboardingMockData.swift.
//

import SwiftUI
import Combine

// MARK: - Enums

enum OnboardingStep: Int, CaseIterable {
    case hero, gender, country, notifications, demo, paywall
}

enum OnboardingGender: String {
    case female, male

    var displayName: String { self == .female ? "Femme" : "Homme" }
    var icon: String { self == .female ? "figure.stand.dress" : "figure.stand" }

    var gradientColors: [Color] {
        self == .female
            ? [Color(red: 0.95, green: 0.78, blue: 0.82), Color(red: 0.86, green: 0.42, blue: 0.55)]
            : [Color(red: 0.26, green: 0.17, blue: 0.14), Color(red: 0.50, green: 0.30, blue: 0.20)]
    }
}

enum OnboardingCountry: String, CaseIterable, Identifiable {
    case france, belgique, suisse, germany, uk, italie, espagne, portugal, netherlands, europe, us, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .france:      "France"
        case .belgique:    "Belgique"
        case .suisse:      "Suisse"
        case .germany:     "Allemagne"
        case .uk:          "Royaume-Uni"
        case .italie:      "Italie"
        case .espagne:     "Espagne"
        case .portugal:    "Portugal"
        case .netherlands: "Pays-Bas"
        case .europe:      "Europe"
        case .us:          "États-Unis"
        case .other:       "Autre"
        }
    }

    var flag: String {
        switch self {
        case .france:      "🇫🇷"
        case .belgique:    "🇧🇪"
        case .suisse:      "🇨🇭"
        case .germany:     "🇩🇪"
        case .uk:          "🇬🇧"
        case .italie:      "🇮🇹"
        case .espagne:     "🇪🇸"
        case .portugal:    "🇵🇹"
        case .netherlands: "🇳🇱"
        case .europe:      "🇪🇺"
        case .us:          "🇺🇸"
        case .other:       "🌍"
        }
    }
}

// MARK: - Flow model

@MainActor
final class OnboardingFlowModel: ObservableObject {
    @Published var step: OnboardingStep = .hero
    @Published var gender: OnboardingGender?
    @Published var country: OnboardingCountry?

    /// ID du look sélectionné dans la démo (ex: "leather", "sneaker")
    @Published var selectedLookId: String?

    /// Vrai quand la démo affiche la grille résultats → 5ᵉ segment de la barre rempli.
    @Published var isDemoInResultsPhase: Bool = false

    /// Incrémenté à chaque tap sur la barre de progression (y compris sur l’étape déjà affichée) pour resynchroniser la démo.
    @Published private(set) var progressTapStamp: Int = 0

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    /// Looks disponibles (identiques pour tous les genres)
    var demoItems: [OnboardingLookOptionData] {
        OnboardingMockData.lookOptions
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

    /// Barre de progression : segments 1…5 = genre / zone / notifs / démo (look+scan) / démo résultats.
    func jumpToProgressSegment(_ segment: Int) {
        guard segment >= 1, segment <= 5 else { return }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            progressTapStamp += 1
            switch segment {
            case 1:
                step = .gender
            case 2:
                step = .country
            case 3:
                step = .notifications
            case 4:
                step = .demo
                isDemoInResultsPhase = false
            case 5:
                step = .demo
                isDemoInResultsPhase = true
                if selectedLookId == nil {
                    selectedLookId = OnboardingMockData.lookOptions.first?.id
                }
            default:
                break
            }
        }
    }

    func complete() { onComplete() }
}

// MARK: - OnboardingAssetImageView

/// Charge une image depuis Assets.xcassets.
/// Si l'asset est absent, affiche un placeholder propre (sans crash).
struct OnboardingAssetImageView: View {
    let imageName: String
    var contentMode: ContentMode = .fill

    var body: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                Text(imageName)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(uiColor: .quaternaryLabel))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
            }
        }
    }
}
