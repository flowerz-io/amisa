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

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                Image(systemName: "bell.badge.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.primary, BrandColors.primary)
                    .font(.system(size: 48))
                    .padding(.bottom, 16)

                OnboardingStepHeader(
                    segment: 3,
                    title: "Ne rate plus les\nmeilleures trouvailles",
                    subtitle: "Amisa t’alerte quand de nouvelles annonces correspondent à tes recherches."
                )

                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    Button {
                        Task { await activateNotifications() }
                    } label: {
                        Group {
                            if requestInFlight {
                                ProgressView().tint(.white)
                            } else {
                                Text("Activer les notifications")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(BrandColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(requestInFlight)

                    Button {
                        finishStep()
                    } label: {
                        Text("Plus tard")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.06)) {
                appeared = true
            }
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
