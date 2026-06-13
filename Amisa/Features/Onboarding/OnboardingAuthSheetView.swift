//
//  OnboardingAuthSheetView.swift
//  Amisa
//
//  Modal auth premium — verre fumé sombre, ancré en bas.
//

import SwiftUI

struct OnboardingAuthSheetView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var backdropVisible = false
    @State private var panelSlidIn = false

    /// Le bas du panneau dépasse légèrement sous l’écran (sheet physique).
    private let bottomBleed: CGFloat = 22
    private let panelSlideDistance: CGFloat = 480

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(backdropVisible ? 0.52 : 0)
                .ignoresSafeArea()
                .animation(OnboardingMotion.fadeSlow, value: backdropVisible)
                .onTapGesture { dismiss() }

            panel
                .padding(.horizontal, 16)
                .padding(.bottom, -bottomBleed)
                .offset(y: panelSlidIn ? 0 : panelSlideDistance)
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
                .padding(.bottom, 8)

            AuthCoordinatorCore(
                embed: .onboardingPremium(close: { dismiss() }),
                skipTrailing: { @MainActor in model.continueWithoutAccount() },
                onAuthenticated: { @MainActor in model.completeAuth() }
            )
            .padding(.bottom, 10 + bottomBleed)
        }
        .frame(maxWidth: .infinity)
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
