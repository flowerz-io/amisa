//
//  NotificationOnboardingSheet.swift
//  Balibu
//
//  Première explication des notifications (partage → résultats, futures alertes annonces).
//

import SwiftUI
import UserNotifications

struct NotificationOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var educationCompleted: Bool

    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var requestInFlight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                    Text(String(localized: "Reste informé"))
                        .font(DesignTokens.titleFont)
                        .foregroundStyle(DesignTokens.textPrimary)

                    Text(String(localized: "Les notifications permettent de :"))
                        .font(DesignTokens.bodyFont)
                        .foregroundStyle(DesignTokens.textPrimary)

                    VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                        bullet(String(localized: "recevoir un raccourci vers tes résultats après un partage depuis une autre app"))
                        bullet(String(localized: "être alerté plus tard lorsque de nouvelles annonces correspondront mieux à ta recherche"))
                    }
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(DesignTokens.textSecondary)

                    if status == .denied {
                        Text(String(localized: "Sans autorisation, tu n’auras pas ce raccourci immédiat après un partage, et les alertes d’annonces ne fonctionneront pas. Tu peux toujours ouvrir Balibu manuellement : ton analyse enregistrée t’y attend."))
                            .font(DesignTokens.bodyFont)
                            .foregroundStyle(DesignTokens.textSecondary)
                    } else {
                        Text(String(localized: "Tu peux refuser : l’app continue de fonctionner, mais l’expérience sera moins fluide."))
                            .font(DesignTokens.bodyFont)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                .padding(DesignTokens.spacingL)
            }
            .background(DesignTokens.backgroundColor)
            .navigationTitle(String(localized: "Notifications"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Plus tard")) {
                        educationCompleted = true
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DesignTokens.spacingM) {
                    if status == .denied {
                        Button(String(localized: "Ouvrir Réglages")) {
                            NotificationManager.shared.openSystemNotificationSettings()
                        }
                        .buttonStyle(BalibuButtonStyle())
                    } else {
                        Button {
                            Task {
                                requestInFlight = true
                                _ = await NotificationManager.shared.requestAuthorization()
                                await NotificationManager.shared.refreshAuthorizationStatus()
                                await MainActor.run {
                                    requestInFlight = false
                                    educationCompleted = true
                                    dismiss()
                                }
                            }
                        } label: {
                            if requestInFlight {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(String(localized: "Activer les notifications"))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(BalibuButtonStyle())
                        .disabled(requestInFlight)
                    }

                    Button(String(localized: "Compris")) {
                        educationCompleted = true
                        dismiss()
                    }
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(DesignTokens.accent)
                }
                .padding(DesignTokens.spacingL)
                .background(DesignTokens.backgroundColor)
            }
        }
        .task {
            await refreshStatus()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingS) {
            Text("•")
            Text(text)
        }
    }

    private func refreshStatus() async {
        let s = await NotificationManager.shared.currentAuthorizationStatus()
        await MainActor.run { status = s }
    }
}
