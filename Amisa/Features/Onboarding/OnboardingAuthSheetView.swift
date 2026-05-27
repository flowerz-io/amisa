//
//  OnboardingAuthSheetView.swift
//  Amisa
//
//  Auth en bottom sheet depuis le hero — jamais plein écran dans le flow.
//

import SwiftUI

struct OnboardingAuthSheetView: View {
    @ObservedObject var model: OnboardingFlowModel

    var body: some View {
        AuthBottomSheet(
            onSignedIn: { model.completeAuth() },
            onSkip: { model.continueWithoutAccount() }
        )
    }
}
