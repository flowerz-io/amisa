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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 175)

                    bellHero
                        .padding(.vertical, 28)

                    VStack(spacing: 12) {
                        Text(String(localized: "Ne rate plus les meilleures trouvailles"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.spacingL)

                        Text(String(localized: "Amisa t’alerte quand de nouvelles annonces correspondent parfaitement à tes recherches."))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, DesignTokens.spacingL)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)

                    VStack(spacing: DesignTokens.spacingM) {
                        NotificationMockCard(
                            title: String(localized: "Amisa"),
                            message: String(localized: "Nouveau maillot France 2002 trouvé à 39€"),
                            time: String(localized: "À l’instant")
                        )
                        NotificationMockCard(
                            title: String(localized: "Ta recherche"),
                            message: String(localized: "Une annonce correspondant à ta recherche vient d’apparaître"),
                            time: String(localized: "Il y a 2 min")
                        )
                    }
                    .padding(.horizontal, DesignTokens.spacingL)
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)

                    Spacer(minLength: 36)

                    VStack(spacing: DesignTokens.spacingM) {
                        Button {
                            Task { await activateNotifications() }
                        } label: {
                            Group {
                                if requestInFlight {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DesignTokens.spacingS)
                                } else {
                                    Text(String(localized: "Activer les notifications"))
                                        .font(.system(size: 17, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DesignTokens.spacingM)
                                }
                            }
                            .foregroundStyle(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 14, x: 0, y: 6)
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(requestInFlight)

                        Button {
                            skipNotifications()
                        } label: {
                            Text(String(localized: "Plus tard"))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.spacingS)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DesignTokens.spacingL)
                    .padding(.bottom, 44)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                }
            }
        }
        .ignoresSafeArea()
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
                Color.accentColor.opacity(0.06),
                Color(uiColor: .systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var bellHero: some View {
        ZStack {
            Circle()
                .fill(BrandColors.primary.opacity(glowPulse ? 0.14 : 0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 28)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 148, height: 148)
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
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)

            Image(systemName: "bell.badge.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.primary, BrandColors.primary)
                .font(.system(size: 56, weight: .medium))
                .scaleEffect(breathe ? 1.045 : 1.0)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
    }

    private func activateNotifications() async {
        requestInFlight = true
        defer { requestInFlight = false }
        _ = await NotificationManager.shared.requestAuthorization()
        await NotificationManager.shared.refreshAuthorizationStatus()
        notificationEducationCompleted = true
        model.advance()
    }

    private func skipNotifications() {
        notificationEducationCompleted = true
        model.advance()
    }
}

// MARK: - Carte notification mock

private struct NotificationMockCard: View {
    let title: String
    let message: String
    let time: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.22))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(time)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.spacingM)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
        }
    }
}
