//
//  NotificationOnboardingStepView.swift
//  Amisa
//

import SwiftUI

struct NotificationOnboardingStepView: View {
    @ObservedObject var model: OnboardingFlowModel
    @AppStorage("amisa.notification.educationCompleted") private var notificationEducationCompleted = false

    @State private var appeared = false
    @State private var requestInFlight = false
    @State private var notificationPulse = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                segment: 3,
                title: "Ne rate plus les\nmeilleures trouvailles",
                subtitle: "Amisa t’alerte quand de nouvelles annonces correspondent à tes recherches."
            )
            .padding(.top, 4)
            .onboardingStepEntrance(appeared)

            Spacer(minLength: 20)

            notificationMockup
                .padding(.horizontal, 28)
                .onboardingStaggeredEntrance(appeared, index: 1, baseDelay: 0.1)

            Spacer(minLength: 24)

            VStack(spacing: 10) {
                OnboardingPrimaryButton(
                    title: requestInFlight
                        ? String(localized: "Activation…")
                        : String(localized: "Activer les notifications"),
                    icon: requestInFlight ? nil : "bell.badge.fill"
                ) {
                    Task { await activateNotifications() }
                }
                .disabled(requestInFlight)
                .opacity(requestInFlight ? 0.85 : 1)

                OnboardingSecondaryTextButton(title: String(localized: "Plus tard")) {
                    finishStep()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .onboardingStepEntrance(appeared, delay: 0.16)
        }
        .onboardingScreen()
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.04)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                notificationPulse = true
            }
        }
    }

    private var notificationMockup: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .frame(height: 320)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)

            VStack(spacing: 14) {
                mockNotificationCard(
                    title: "Amisa",
                    body: "Nouveau maillot France 2002 trouvé à 39 €",
                    time: "À l’instant",
                    highlighted: true
                )
                .scaleEffect(notificationPulse ? 1.01 : 1)

                mockNotificationCard(
                    title: "Ta recherche",
                    body: "Une annonce correspondant à ta recherche vient d’apparaître",
                    time: "Il y a 2 min",
                    highlighted: false
                )
                .opacity(0.72)
                .scaleEffect(0.96)
                .onboardingStaggeredEntrance(appeared, index: 2, baseDelay: 0.14)
            }
            .padding(20)
        }
    }

    private func mockNotificationCard(
        title: String,
        body: String,
        time: String,
        highlighted: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(OnboardingTheme.accentRed.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accentRed)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OnboardingTheme.offWhite)
                    Spacer()
                    Text(time)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(OnboardingTheme.warmGrayMuted)
                }
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(OnboardingTheme.warmGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlighted ? OnboardingTheme.cardFillElevated : OnboardingTheme.cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(highlighted ? OnboardingTheme.accentRed.opacity(0.35) : OnboardingTheme.cardStroke, lineWidth: 1)
        }
    }

    private func activateNotifications() async {
        requestInFlight = true
        defer { requestInFlight = false }
        _ = await NotificationManager.shared.requestAuthorization()
        await NotificationManager.shared.refreshAuthorizationStatus()
        notificationEducationCompleted = true
        finishStep()
    }

    private func finishStep() {
        notificationEducationCompleted = true
        model.completeNotifications()
    }
}
