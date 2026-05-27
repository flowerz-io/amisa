//
//  NotificationOnboardingStepView.swift
//  Balibu
//
//  Étape onboarding — autorisation notifications après tap sur CTA (pas de popup système avant).
//

import SwiftUI

struct NotificationOnboardingStepView: View {
    @ObservedObject var model: OnboardingFlowModel
    @AppStorage("amisa.notification.educationCompleted") private var notificationEducationCompleted = false

    @State private var appeared = false
    @State private var breathe = false
    @State private var glowPulse = false
    @State private var requestInFlight = false

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 4)

                compactBellHero
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                VStack(spacing: 6) {
                    Text(String(localized: "Ne rate plus les meilleures trouvailles"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, DesignTokens.spacingM)

                    Text(String(localized: "Amisa t’alerte quand de nouvelles annonces correspondent parfaitement à tes recherches."))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .lineLimit(3)
                        .padding(.horizontal, DesignTokens.spacingM)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                VStack(spacing: 8) {
                    NotificationMockCard(
                        title: String(localized: "Amisa"),
                        message: String(localized: "Nouveau maillot France 2002 trouvé à 39€"),
                        time: String(localized: "À l’instant"),
                        compact: true
                    )
                    NotificationMockCard(
                        title: String(localized: "Ta recherche"),
                        message: String(localized: "Une annonce correspondant à ta recherche vient d’apparaître"),
                        time: String(localized: "Il y a 2 min"),
                        compact: true
                    )
                }
                .padding(.horizontal, DesignTokens.spacingM)
                .padding(.top, 12)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Button {
                        Task { await activateNotifications() }
                    } label: {
                        Group {
                            if requestInFlight {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                Text(String(localized: "Activer les notifications"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .foregroundStyle(.white)
                        .background(BrandColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: BrandColors.primary.opacity(0.35), radius: 12, x: 0, y: 5)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(requestInFlight)

                    Button {
                        skipNotifications()
                    } label: {
                        Text(String(localized: "Plus tard"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.spacingM)
                .padding(.bottom, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82).delay(0.06)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                BrandColors.primary.opacity(0.06),
                Color(uiColor: .systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var compactBellHero: some View {
        ZStack {
            Circle()
                .fill(BrandColors.primary.opacity(glowPulse ? 0.12 : 0.05))
                .frame(width: 132, height: 132)
                .blur(radius: 22)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 96, height: 96)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 8)

            Image(systemName: "bell.badge.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.primary, BrandColors.primary)
                .font(.system(size: 44, weight: .medium))
                .scaleEffect(breathe ? 1.04 : 1.0)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
    }

    private func activateNotifications() async {
        requestInFlight = true
        defer { requestInFlight = false }
        _ = await NotificationManager.shared.requestAuthorization()
        await NotificationManager.shared.refreshAuthorizationStatus()
        notificationEducationCompleted = true
        model.completeNotificationsStep(activateFlow: true)
    }

    private func skipNotifications() {
        notificationEducationCompleted = true
        model.completeNotificationsStep(activateFlow: false)
    }
}

// MARK: - Carte notification mock

private struct NotificationMockCard: View {
    let title: String
    let message: String
    let time: String
    var compact: Bool = false

    var body: some View {
        let iconSize: CGFloat = compact ? 34 : 42
        let pad: CGFloat = compact ? 10 : DesignTokens.spacingM

        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BrandColors.primary.opacity(0.18))
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: compact ? 15 : 18, weight: .semibold))
                        .foregroundStyle(BrandColors.primary)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.system(size: compact ? 12 : 13, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(time)
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Text(message)
                    .font(.system(size: compact ? 12 : 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(compact ? 2 : nil)
            }
        }
        .padding(pad)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
        }
    }
}
