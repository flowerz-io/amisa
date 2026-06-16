//
//  OnboardingAuthSheetView.swift
//  Amisa
//
//  Modal auth premium — verre fumé sombre, ancré en bas, hauteur au contenu.
//

import SwiftUI

struct OnboardingAuthSheetView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var backdropVisible = false
    @State private var panelSlidIn = false
    @State private var panelHeight: CGFloat = AuthSheetMetrics.fallbackHeight

    private let bottomSafeBleed: CGFloat = 8

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(backdropVisible ? 0.52 : 0)
                .ignoresSafeArea()
                .animation(OnboardingMotion.fadeSlow, value: backdropVisible)
                .onTapGesture { dismiss() }

            panel
                .padding(.horizontal, 16)
                .padding(.bottom, bottomSafeBleed)
                .offset(y: panelSlidIn ? 0 : panelHeight + 48)
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .onAppear { present() }
        .onChange(of: model.isAuthSheetPresented) { _, visible in
            if !visible, panelSlidIn || backdropVisible {
                retractPanel(markDismissed: false)
            }
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(OnboardingTheme.warmGrayMuted.opacity(0.55))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            AuthCoordinatorCore(
                embed: .onboardingPremium(close: { dismiss() }),
                onContinueAsGuest: { @MainActor in model.continueAsGuest() },
                onAuthenticated: { @MainActor in model.completeAuth() }
            )
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .reportAuthSheetHeight()
        .onPreferenceChange(AuthSheetHeightKey.self) { measured in
            guard measured > 0 else { return }
            panelHeight = measured
        }
        .background { panelBackground }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 28, x: 0, y: 16)
        .shadow(color: OnboardingTheme.accentRed.opacity(0.08), radius: 20, x: 0, y: 4)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(OnboardingTheme.panelFill)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            .clear,
                            OnboardingTheme.accentRed.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func present() {
        withAnimation(OnboardingMotion.fadeSlow) {
            backdropVisible = true
        }
        withAnimation(OnboardingMotion.springPremium) {
            panelSlidIn = true
        }
    }

    private func dismiss() {
        retractPanel(markDismissed: true)
    }

    private func retractPanel(markDismissed: Bool) {
        withAnimation(OnboardingMotion.springSnappy) {
            panelSlidIn = false
            backdropVisible = false
        }
        guard markDismissed else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            model.isAuthSheetPresented = false
        }
    }
}
