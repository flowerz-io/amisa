//
//  OnboardingFlowModel.swift
//  Amisa
//
//  Moteur onboarding — une seule source de vérité : `step`.
//

import Combine
import SwiftUI

// MARK: - Étapes

enum OnboardingStep: Equatable, CustomStringConvertible {
    case hero
    case gender
    case country
    case notifications
    case look
    case fakeAnalysis
    case fakeResults
    case paywall

    var description: String {
        switch self {
        case .hero: return "hero"
        case .gender: return "gender"
        case .country: return "country"
        case .notifications: return "notifications"
        case .look: return "look"
        case .fakeAnalysis: return "fakeAnalysis"
        case .fakeResults: return "fakeResults"
        case .paywall: return "paywall"
        }
    }

    /// Segments remplis (1…5) pour la barre de progression.
    var progressSegment: Int {
        switch self {
        case .gender: return 1
        case .country: return 2
        case .notifications: return 3
        case .look: return 4
        case .fakeResults: return 5
        default: return 0
        }
    }

    var showsProgressBar: Bool {
        switch self {
        case .gender, .country, .notifications, .look, .fakeResults:
            return true
        default:
            return false
        }
    }
}

// MARK: - Modèle

@MainActor
final class OnboardingFlowModel: ObservableObject {
    @Published var step: OnboardingStep = .hero
    @Published var selectedLook: DemoLook?
    @Published var selectedGender: String?
    @Published var selectedCountry: String?
    @Published var isAuthSheetPresented: Bool = false

    let onComplete: () -> Void

    static let progressSegmentCount = 5

    var demoLooks: [DemoLook] { OnboardingMockData.demoLooks }

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        logState()
    }

    // MARK: - Navigation publique

    func goTo(_ newStep: OnboardingStep) {
        let oldStep = step
        guard oldStep != newStep else { return }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            step = newStep
        }

        print("[ONBOARDING] transition", oldStep, "→", newStep)
        logState()
    }

    func next() {
        guard step == .fakeResults else { return }
        goTo(.paywall)
    }

    func back() {
        switch step {
        case .gender:
            goTo(.hero)
        case .country:
            goTo(.gender)
        case .notifications:
            goTo(.country)
        case .look:
            goTo(.notifications)
        case .fakeAnalysis:
            selectedLook = nil
            goTo(.look)
        case .fakeResults:
            selectedLook = nil
            goTo(.look)
        case .paywall:
            goTo(.fakeResults)
        case .hero:
            break
        }
    }

    func openAuthSheet() {
        guard step == .hero else { return }
        isAuthSheetPresented = true
        print("[ONBOARDING] auth sheet opened")
    }

    func completeAuth() {
        isAuthSheetPresented = false
        print("[ONBOARDING] auth completed")
        goTo(.gender)
    }

    func continueWithoutAccount() {
        isAuthSheetPresented = false
        print("[ONBOARDING] auth completed")
        goTo(.gender)
    }

    func selectGender(_ gender: String) {
        guard step == .gender else { return }
        selectedGender = gender
        goTo(.country)
    }

    func selectCountry(_ country: String) {
        guard step == .country else { return }
        selectedCountry = country.isEmpty ? nil : country
        goTo(.notifications)
    }

    func completeNotifications() {
        guard step == .notifications else { return }
        selectedLook = nil
        goTo(.look)
    }

    func selectLook(_ look: DemoLook) {
        guard step == .look else { return }
        selectedLook = look
        goTo(.fakeAnalysis)
    }

    func completeFakeAnalysis() {
        guard step == .fakeAnalysis else { return }
        guard selectedLook != nil else { return }
        print("[ONBOARDING] fake analysis completed")
        goTo(.fakeResults)
    }

    func completeOnboarding() {
        print("[ONBOARDING] completed")
        onComplete()
    }

    // MARK: - Logs

    private func logState() {
        print("[ONBOARDING] step =", step)
        print("[ONBOARDING] selectedGender =", selectedGender ?? "nil")
        print("[ONBOARDING] selectedCountry =", selectedCountry ?? "nil")
        print("[ONBOARDING] selectedLook =", selectedLook?.id ?? "nil")
    }
}
