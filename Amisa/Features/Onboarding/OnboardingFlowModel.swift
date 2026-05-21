//
//  OnboardingFlowModel.swift
//  Balibu
//
//  Source unique de vérité — flux strict : hero → (sheet auth) → gender → … → paywall.
//

import Combine
import SwiftUI

// MARK: - Étapes (ordre strict, linéaire)

enum OnboardingStep: Int, CaseIterable {
    case hero = 0
    case gender
    case country
    case notifications
    case look
    case fakeAnalyzing
    case fakeResults
    case paywall

    /// Barre de progression : gender…fakeResults — 5 segments (sans hero / paywall / phase analyse).
    static let progressSegmentsCount: Int = 5

    /// Segment rempli 1…5 ; 0 si pas de barre.
    func progressSegmentFilled() -> Int {
        switch self {
        case .hero, .paywall: return 0
        case .gender: return 1
        case .country: return 2
        case .notifications: return 3
        case .look, .fakeAnalyzing: return 4
        case .fakeResults: return 5
        }
    }
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
    @Published private(set) var currentStep: OnboardingStep = .hero

    /// Sheet auth sur l’écran hero uniquement.
    @Published var isAuthSheetPresented: Bool = false

    @Published var gender: OnboardingGender?
    @Published var country: OnboardingCountry?

    @Published private(set) var selectedLookId: String?

    private var fakeAnalysisTask: Task<Void, Never>?

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        logStep()
    }

    var lookOptions: [OnboardingLookOptionData] {
        OnboardingMockData.lookOptions
    }

    // MARK: - Auth (sheet)

    func presentAuthSheet() {
        print("[Onboarding] auth sheet opened")
        guard currentStep == .hero else { return }
        isAuthSheetPresented = true
    }

    func closeAuthSheetAndContinueToGender() {
        isAuthSheetPresented = false
        guard currentStep == .hero else {
            print("[Onboarding] closeAuthSheet ignored step=\(currentStep)")
            return
        }
        goTo(.gender, animated: true, context: "auth sheet → gender")
    }

    // MARK: - Étapes explicites (pas de navigation locale dans les vues)

    func userSelectedGender(_ value: OnboardingGender) {
        gender = value
        print("[Onboarding] selectedGender=\(value.rawValue)")
        guard currentStep == .gender else { return }
        goTo(.country, animated: true, context: "gender selected")
    }

    func userCommittedCountry(_ value: OnboardingCountry) {
        country = value
        print("[Onboarding] selectedCountry=\(value.rawValue)")
        guard currentStep == .country else { return }
        goTo(.notifications, animated: true, context: "country committed")
    }

    func userSkippedCountryStep() {
        print("[Onboarding] selectedCountry=skipped")
        guard currentStep == .country else { return }
        goTo(.notifications, animated: true, context: "country skipped")
    }

    func notificationChoiceCompleted(userChoseActivateFlow: Bool) {
        let label = userChoseActivateFlow ? "activate" : "later"
        print("[Onboarding] notification choice=\(label)")
        guard currentStep == .notifications else { return }
        selectedLookId = nil
        cancelFakeAnalysisTask()
        goTo(.look, animated: true, context: "notifications → look")
    }

    func userSelectedLook(_ lookId: String) {
        guard currentStep == .look else { return }
        selectedLookId = lookId
        print("[Onboarding] selectedLook=\(lookId)")
        goTo(.fakeAnalyzing, animated: true, context: "look → fake analyzing", preservePendingAnalysis: true)
        startFakeAnalysisSequence()
    }

    func userRequestedPaywallFromFakeResults() {
        guard currentStep == .fakeResults else { return }
        goTo(.paywall, animated: true, context: "fake results → paywall")
    }

    func finishPaywallContinue() {
        print("[Onboarding] completed")
        cancelFakeAnalysisTask()
        onComplete()
    }

    // MARK: - Progress bar (tap)

    func goToProgressSegment(_ segment: Int) {
        guard segment >= 1, segment <= OnboardingStep.progressSegmentsCount else { return }
        print("[Onboarding] progress tap segment=\(segment)")
        cancelFakeAnalysisTask()

        switch segment {
        case 1:
            goTo(.gender, animated: true, context: "progress→gender")
        case 2:
            goTo(.country, animated: true, context: "progress→country")
        case 3:
            goTo(.notifications, animated: true, context: "progress→notifications")
        case 4:
            selectedLookId = nil
            goTo(.look, animated: true, context: "progress→look")
        case 5:
            if let id = selectedLookId, !id.isEmpty {
                goTo(.fakeResults, animated: true, context: "progress→fakeResults")
            } else {
                goTo(.look, animated: true, context: "progress→look (no look)")
            }
        default:
            break
        }
    }

    // MARK: - Retour linéaire

    func previous() {
        cancelFakeAnalysisTask()
        let from = currentStep
        print("[Onboarding] previous from=\(from)")

        switch currentStep {
        case .hero:
            return
        case .gender:
            goTo(.hero, animated: true, context: "back→hero")
        case .country:
            goTo(.gender, animated: true, context: "back→gender")
        case .notifications:
            goTo(.country, animated: true, context: "back→country")
        case .look:
            goTo(.notifications, animated: true, context: "back→notifications")
        case .fakeAnalyzing:
            goTo(.look, animated: true, context: "back→look from analyzing")
        case .fakeResults:
            cancelFakeAnalysisTask()
            goTo(.look, animated: true, context: "back→look from results")
        case .paywall:
            goTo(.fakeResults, animated: true, context: "back→fakeResults")
        }
    }

    // MARK: - Navigation interne

    private func goTo(
        _ step: OnboardingStep,
        animated: Bool,
        context: String,
        preservePendingAnalysis: Bool = false
    ) {
        let from = currentStep
        if step == currentStep {
            print("[Onboarding] goTo noop already at \(step) (\(context))")
            return
        }

        if !(from == .look && step == .fakeAnalyzing && preservePendingAnalysis) {
            cancelFakeAnalysisTask()
        }

        print("[Onboarding] next from=\(from) to=\(step) (\(context))")

        if animated {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                currentStep = step
            }
        } else {
            currentStep = step
        }

        switch step {
        case .paywall:
            print("[Onboarding] paywall shown")
        default:
            break
        }

        logStep()
    }

    private func logStep() {
        print("[Onboarding] step=\(currentStep)")
    }

    // MARK: - Fake analyse

    private func cancelFakeAnalysisTask() {
        fakeAnalysisTask?.cancel()
        fakeAnalysisTask = nil
    }

    private func startFakeAnalysisSequence() {
        cancelFakeAnalysisTask()
        guard currentStep == .fakeAnalyzing else { return }
        print("[Onboarding] fake analysis started")

        fakeAnalysisTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard self.currentStep == .fakeAnalyzing else { return }
                print("[Onboarding] fake analysis completed")
                self.goTo(.fakeResults, animated: true, context: "analysis done → fake results")
            }
        }
    }
}

// MARK: - Image asset helper

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
