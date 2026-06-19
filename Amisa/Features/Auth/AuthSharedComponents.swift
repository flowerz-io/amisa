//
//  AuthSharedComponents.swift
//  Amisa
//
//  Styles et composants partagés pour le flux d'authentification.
//

import SwiftUI

// MARK: - Logs

enum AuthSheetLog {
    static func sheet(_ message: String) {
        print("[AUTH_SHEET] \(message)")
    }

    static func emailLogin(_ message: String) {
        print("[EMAIL_LOGIN] \(message)")
    }

    static func keyboard(_ message: String) {
        print("[KEYBOARD] \(message)")
    }
}

// MARK: - Hauteur sheet (fixe — pas de remesure au clavier)

enum AuthSheetMetrics {
    /// Marge sous le dernier élément (ex. « Continuer en tant qu’invité »).
    static let bottomInset: CGFloat = 28
    /// Hauteur fixe du sheet — le contenu défile à l’intérieur si le clavier est ouvert.
    static let fixedSheetHeight: CGFloat = 560
    /// Hauteur du handle onboarding (capsule + padding).
    static let onboardingHandleHeight: CGFloat = 28
}

// MARK: - Conteneur formulaire (scroll interne, sheet fixe)

struct AuthSheetFormScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            content()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Thème

struct AuthTheme {
    let isPremium: Bool

    var accent: Color {
        isPremium ? OnboardingTheme.accentRed : BrandColors.primaryRed
    }

    var primaryText: Color {
        isPremium ? OnboardingTheme.offWhite : Color.primary
    }

    var secondaryText: Color {
        isPremium ? OnboardingTheme.warmGray : Color.secondary
    }

    var mutedText: Color {
        isPremium ? OnboardingTheme.warmGrayMuted : Color.secondary.opacity(0.85)
    }

    var fieldBackground: Color {
        isPremium
            ? OnboardingTheme.cardFillElevated
            : Color(.systemGray6)
    }

    var fieldStroke: Color {
        isPremium ? OnboardingTheme.cardStroke : Color.clear
    }

    var fieldFocusedStroke: Color {
        accent
    }

    var closeButtonFill: Color {
        isPremium ? OnboardingTheme.cardFillElevated : Color.primary.opacity(0.08)
    }

    var closeButtonStroke: Color {
        isPremium ? OnboardingTheme.cardStroke : Color.primary.opacity(0.06)
    }
}

// MARK: - Validation

enum AuthFormValidator {
    static func isValidEmail(_ raw: String) -> Bool {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.count >= 5 else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        return parts[1].contains(".")
    }

    static func isValidPassword(_ raw: String) -> Bool {
        raw.count >= 8
    }
}

// MARK: - Chrome

struct AuthModalHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.bottom, 4)
    }
}

struct AuthAmisaMark: View {
    let theme: AuthTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(0.12))
                .frame(width: 48, height: 48)
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.accent)
        }
    }
}

struct AuthCloseButton: View {
    let theme: AuthTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.closeButtonFill)
                    .overlay(Circle().stroke(theme.closeButtonStroke, lineWidth: 1))
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.primaryText)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }
}

struct AuthRedBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BrandColors.primaryRed)
                .padding(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Champs avec icône

struct AuthIconEmailField: View {
    let theme: AuthTheme
    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var focused: Bool
    var onFocusChange: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .frame(width: 22)

            TextField(placeholder, text: $text)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(theme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(theme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused ? theme.fieldFocusedStroke : theme.fieldStroke, lineWidth: focused ? 1.5 : 1)
        )
        .focused($focused)
        .onChange(of: focused) { _, isFocused in
            onFocusChange?(isFocused)
        }
    }
}

struct AuthIconPasswordField: View {
    let theme: AuthTheme
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    @FocusState.Binding var focused: Bool
    var onFocusChange: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .frame(width: 22)

            SecureField(placeholder, text: $text)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(theme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(theme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused ? theme.fieldFocusedStroke : theme.fieldStroke, lineWidth: focused ? 1.5 : 1)
        )
        .focused($focused)
        .onChange(of: focused) { _, isFocused in
            onFocusChange?(isFocused)
        }
    }
}

// MARK: - Boutons

struct AuthPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isEnabled ? Color.black : Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

enum AuthSocialKind {
    case apple
    case google
    case email
}

struct AuthSocialSquareButton: View {
    let kind: AuthSocialKind
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch kind {
                case .apple:
                    Image(systemName: "apple.logo")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.black)
                case .google:
                    Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                case .email:
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(isDisabled)
    }
}

struct AuthInlineErrorText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(DesignTokens.error)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

struct AuthSuccessText: View {
    let message: String
    let theme: AuthTheme

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(theme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

struct AuthGuestContinueButton: View {
    let theme: AuthTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(localized: "Continuer en tant qu’invité"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .buttonStyle(AuthGuestPressButtonStyle())
    }
}

private struct AuthGuestPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .underline(configuration.isPressed, color: configuration.isPressed ? Color.secondary.opacity(0.55) : Color.clear)
    }
}

struct AuthLegalFooter: View {
    let theme: AuthTheme

    var body: some View {
        let secondary = theme.mutedText
        let text = Text("En continuant, tu acceptes les ").foregroundStyle(secondary)
            + Text("Conditions d'utilisation").foregroundStyle(secondary).underline()
            + Text(" et la ").foregroundStyle(secondary)
            + Text("Politique de confidentialité").foregroundStyle(secondary).underline()
            + Text(".").foregroundStyle(secondary)
        return text
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}
