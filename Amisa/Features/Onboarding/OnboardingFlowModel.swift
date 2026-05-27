//
//  OnboardingFlowModel.swift
//  Balibu
//
//  Moteur onboarding : une seule source de vérité (`currentStep`), transitions contrôlées.
//

import Combine
import SwiftUI

// MARK: - Modèle look (alias demandé « DemoLook »)

typealias DemoLook = OnboardingLookOptionData

// MARK: - Étapes

enum OnboardingStep: Int, CaseIterable {
    case hero = 0
    case gender
    case country
    case notifications
    case look
    case fakeAnalyzing
    case fakeResults
    case paywall
    case completed

    /// Segments progress (1…5). `0` = pas de segment affiché pour cette étape.
    var progressSegmentFilled: Int {
        switch self {
        case .gender: return 1
        case .country: return 2
        case .notifications: return 3
        case .look: return 4
        case .fakeResults: return 5
        default: return 0
        }
    }

    /// Barre visible uniquement sur ces étapes (pas hero, paywall, completed, fakeAnalyzing).
    var showsProgressBar: Bool {
        switch self {
        case .gender, .country, .notifications, .look, .fakeResults:
            return true
        default:
            return false
        }
    }

    static let progressSegmentsCount: Int = 5
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

// MARK: - Origine d’une transition (évite doubles chemins fantômes)

private enum TransitionOrigin {
    /// `goTo(_:)` public depuis une action utilisateur générique (très restreint).
    case userGoTo
    /// Actions dédiées du flow (genre, pays, notifications, look, résultats…).
    case flowAction
    case userBack
    case userProgressTap
    /// Après OAuth / lien mail — hero → genre uniquement.
    case authSuccess
    /// Fin du délai d’analyse — fakeAnalyzing → fakeResults uniquement.
    case analyzeTimer
    /// Fin onboarding — paywall → completed uniquement.
    case completePipeline
    /// Réparation : selectedLook nil en fin de timer.
    case recoverInvalidState
}

@MainActor
final class OnboardingFlowModel: ObservableObject {
    /// Source unique de vérité.
    @Published private(set) var currentStep: OnboardingStep = .hero

    @Published var isAuthSheetPresented: Bool = false

    @Published var gender: OnboardingGender?
    @Published var country: OnboardingCountry?

    /// Look choisi pour la séquence analyse / résultats (obligatoire pour fakeResults).
    @Published private(set) var selectedLook: DemoLook?

    private var analyzeTask: Task<Void, Never>?

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        logCurrentStep()
    }

    var demoLooks: [DemoLook] {
        OnboardingMockData.lookOptions
    }

    // MARK: - API publique (aucune mutation de `currentStep` hors fichier)

    /// Point d’entrée unique « aller à » depuis l’UI (transitions très encadrées).
    func goTo(_ step: OnboardingStep, animated: Bool = true) {
        applyTransition(to: step, origin: .userGoTo, animated: animated)
    }

    func next(animated: Bool = true) {
        switch currentStep {
        case .fakeResults:
            applyTransition(to: .paywall, origin: .flowAction, animated: animated)
        default:
            print("[FLOW] next() ignored at step", currentStep)
        }
    }

    func previous(animated: Bool = true) {
        guard let target = backTarget(from: currentStep) else {
            print("[FLOW] previous() ignored at step", currentStep)
            return
        }
        applyTransition(to: target, origin: .userBack, animated: animated)
    }

    func completeOnboarding(animated: Bool = false) {
        applyTransition(to: .completed, origin: .completePipeline, animated: animated)
    }

    // MARK: - Auth (pas une étape)

    func presentAuthSheet() {
        guard currentStep == .hero else { return }
        isAuthSheetPresented = true
    }

    func dismissAuthSheet() {
        isAuthSheetPresented = false
    }

    /// Succès auth ou « continuer sans compte » : fermer la sheet puis hero → gender.
    func notifyAuthSuccessAndGoToGender(animated: Bool = true) {
        print("[FLOW] auth success")
        dismissAuthSheet()
        applyTransition(to: .gender, origin: .authSuccess, animated: animated)
    }

    // MARK: - Saisies (appellent `applyTransition`, jamais `currentStep` directement)

    func submitGenderAndContinue(_ value: OnboardingGender, animated: Bool = true) {
        guard currentStep == .gender else { return }
        gender = value
        print("[FLOW] gender = \(value.rawValue)")
        applyTransition(to: .country, origin: .flowAction, animated: animated)
    }

    func submitCountryAndContinue(_ value: OnboardingCountry, animated: Bool = true) {
        guard currentStep == .country else { return }
        country = value
        print("[FLOW] country = \(value.rawValue)")
        applyTransition(to: .notifications, origin: .flowAction, animated: animated)
    }

    func skipCountry(animated: Bool = true) {
        guard currentStep == .country else { return }
        applyTransition(to: .notifications, origin: .flowAction, animated: animated)
    }

    func completeNotificationsStep(activateFlow: Bool, animated: Bool = true) {
        guard currentStep == .notifications else { return }
        print("[FLOW] notification choice = \(activateFlow ? "activate" : "later")")
        selectedLook = nil
        print("[FLOW] selectedLook = \(selectedLook?.id ?? "nil")")
        applyTransition(to: .look, origin: .flowAction, animated: animated)
    }

    func selectLook(_ look: DemoLook, animated: Bool = true) {
        guard currentStep == .look else {
            print("[FLOW] selectLook ignored at step", currentStep)
            return
        }

        print("[FLOW] TAP LOOK =", look.id, "from step =", currentStep)
        selectedLook = look
        print("[FLOW] selectedLook =", look.id)

        applyTransition(to: .fakeAnalyzing, origin: .flowAction, animated: animated)
    }

    // MARK: - Barre de progression

    func tapProgressSegment(_ segment: Int) {
        guard segment >= 1, segment <= OnboardingStep.progressSegmentsCount else { return }
        guard currentStep.showsProgressBar else { return }

        if currentStep == .look || currentStep == .fakeAnalyzing {
            print("[FLOW] progress tap ignored during look/analyzing")
            return
        }

        let target: OnboardingStep
        switch segment {
        case 1: target = .gender
        case 2: target = .country
        case 3: target = .notifications
        case 4: target = .look
        case 5: target = (selectedLook != nil) ? .fakeResults : .look
        default: return
        }

        applyTransition(to: target, origin: .userProgressTap, animated: true)
    }

    // MARK: - Moteur

    private func applyTransition(to dest: OnboardingStep, origin: TransitionOrigin, animated: Bool) {
        let from = currentStep

        guard from != dest else {
            print("[FLOW] transition noop", from, "→", dest)
            return
        }

        guard isAllowedTransition(from: from, to: dest, origin: origin) else {
            print("[FLOW] transition REJECTED", from, "→", dest)
            return
        }

        sideEffectsLeaving(from: from, to: dest, origin: origin)
        cancelAnalyzeTaskIfLeavingAnalyzing(from: from, to: dest)

        print("[FLOW] transition", from, "→", dest)

        if animated {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                currentStep = dest
            }
        } else {
            currentStep = dest
        }

        logCurrentStep()

        if origin == .analyzeTimer {
            cancelAnalyzeTask()
        }

        if dest == .fakeAnalyzing {
            startFakeAnalyzingSequence()
        }

        if dest == .completed {
            finalizeCompleted()
        }

        sideEffectsEntering(dest: dest, origin: origin)
    }

    private func finalizeCompleted() {
        cancelAnalyzeTask()
        dismissAuthSheet()
        print("[FLOW] completed")
        onComplete()
    }

    private func logCurrentStep() {
        print("[FLOW] currentStep = \(currentStep)")
        print("[FLOW] selectedLook = \(selectedLook?.id ?? "nil")")
    }

    // MARK: - Règles de validité

    private func isAllowedTransition(from: OnboardingStep, to: OnboardingStep, origin: TransitionOrigin) -> Bool {
        switch origin {
        case .authSuccess:
            return from == .hero && to == .gender

        case .analyzeTimer:
            return from == .fakeAnalyzing && to == .fakeResults && selectedLook != nil

        case .completePipeline:
            return from == .paywall && to == .completed

        case .recoverInvalidState:
            return from == .fakeAnalyzing && to == .look

        case .userBack:
            return backTarget(from: from) == to

        case .flowAction:
            switch (from, to) {
            case (.gender, .country): return true
            case (.country, .notifications): return true
            case (.notifications, .look): return true
            case (.look, .fakeAnalyzing): return selectedLook != nil
            case (.fakeAnalyzing, .fakeResults): return false /// uniquement via timer
            case (.fakeResults, .paywall): return selectedLook != nil
            default: return false
            }

        case .userGoTo:
            /// Très peu de sauts directs autorisés ; `look → fakeAnalyzing` uniquement via `selectLook` (flowAction).
            switch (from, to) {
            case (.fakeResults, .paywall): return selectedLook != nil
            default: return false
            }

        case .userProgressTap:
            guard from.showsProgressBar else { return false }
            switch to {
            case .gender, .country, .notifications, .look: return true
            case .fakeResults: return selectedLook != nil && from.rawValue >= OnboardingStep.look.rawValue
            default: return false
            }
        }
    }

    private func backTarget(from: OnboardingStep) -> OnboardingStep? {
        switch from {
        case .gender: return .hero
        case .country: return .gender
        case .notifications: return .country
        case .look: return .notifications
        case .fakeAnalyzing: return .look
        case .fakeResults: return .look
        case .paywall: return .fakeResults
        default:
            return nil
        }
    }

    private func sideEffectsLeaving(from: OnboardingStep, to: OnboardingStep, origin: TransitionOrigin) {
        switch (from, to) {
        case (.fakeResults, .look), (.fakeAnalyzing, .look):
            if origin == .userBack || origin == .recoverInvalidState {
                selectedLook = nil
                print("[FLOW] selectedLook =", selectedLook?.id ?? "nil")
            }
        case (.notifications, .look):
            if origin != .userBack {
                selectedLook = nil
                print("[FLOW] selectedLook =", selectedLook?.id ?? "nil")
            }
        default:
            break
        }
    }

    private func sideEffectsEntering(dest: OnboardingStep, origin: TransitionOrigin) {
        _ = dest
        _ = origin
    }

    // MARK: - Analyse fictive

    private func cancelAnalyzeTaskIfLeavingAnalyzing(from: OnboardingStep, to: OnboardingStep) {
        if from == .fakeAnalyzing && to != .fakeResults {
            cancelAnalyzeTask()
        }
    }

    private func cancelAnalyzeTask() {
        analyzeTask?.cancel()
        analyzeTask = nil
    }

    private func startFakeAnalyzingSequence() {
        cancelAnalyzeTask()
        guard currentStep == .fakeAnalyzing else { return }
        guard selectedLook != nil else {
            applyTransition(to: .look, origin: .recoverInvalidState, animated: true)
            return
        }

        print("[FLOW] fake analyzing start")

        analyzeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard self.currentStep == .fakeAnalyzing else { return }
                if self.selectedLook == nil {
                    print("[FLOW] fake analyzing end → abort (nil look)")
                    self.applyTransition(to: .look, origin: .recoverInvalidState, animated: true)
                    return
                }
                print("[FLOW] fake analyzing end")
                self.applyTransition(to: .fakeResults, origin: .analyzeTimer, animated: true)
            }
        }
    }
}

// MARK: - Image asset helper

/// Charge une image depuis Assets.xcassets.
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
