//
//  OnboardingMotion.swift
//  Amisa
//
//  Motion design premium — springs, grain, parallaxe, respiration.
//

import Combine
import CoreMotion
import SwiftUI
import UIKit

// MARK: - Timings

enum OnboardingMotion {
    static let springPremium = Animation.spring(response: 0.62, dampingFraction: 0.84)
    static let springSnappy = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let springBouncy = Animation.spring(response: 0.52, dampingFraction: 0.72)
    static let fadeSlow = Animation.easeInOut(duration: 0.55)
    static let breatheDuration: Double = 5.5
    static let floatDuration: Double = 3.4
}

// MARK: - Grain (cache statique)

enum OnboardingFilmGrain {
    private static let tile: UIImage = {
        let size = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            for _ in 0..<2_800 {
                let x = CGFloat.random(in: 0..<CGFloat(size))
                let y = CGFloat.random(in: 0..<CGFloat(size))
                let a = CGFloat.random(in: 0.15...0.55)
                UIColor.white.withAlphaComponent(a).setFill()
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }()

    static var tiled: Image {
        Image(uiImage: tile).resizable(resizingMode: .tile)
    }
}

struct OnboardingFilmGrainOverlay: View {
    var opacity: Double = 0.045

    var body: some View {
        OnboardingFilmGrain.tiled
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}

// MARK: - Parallaxe gyroscope

@MainActor
final class OnboardingParallaxMotion: ObservableObject {
    @Published private(set) var offset: CGSize = .zero

    private let manager = CMMotionManager()
    private var isRunning = false

    func start() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        isRunning = true
        manager.deviceMotionUpdateInterval = 1 / 24
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            let roll = max(-0.35, min(0.35, attitude.roll))
            let pitch = max(-0.35, min(0.35, attitude.pitch))
            let target = CGSize(width: CGFloat(roll) * 22, height: CGFloat(pitch) * 16)
            let blend = 0.14
            self.offset = CGSize(
                width: self.offset.width + (target.width - self.offset.width) * blend,
                height: self.offset.height + (target.height - self.offset.height) * blend
            )
        }
    }

    func stop() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
        withAnimation(OnboardingMotion.fadeSlow) {
            offset = .zero
        }
    }
}

// MARK: - Modifiers

struct OnboardingBreathingGlowModifier: ViewModifier {
    @State private var phase = false
    var color: Color
    var minOpacity: Double
    var maxOpacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(phase ? maxOpacity : minOpacity),
                radius: phase ? 22 : 14,
                x: 0,
                y: phase ? 12 : 8
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: OnboardingMotion.breatheDuration)
                        .repeatForever(autoreverses: true)
                ) {
                    phase = true
                }
            }
    }
}

struct OnboardingShimmerModifier: ViewModifier {
    @State private var travel: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.12),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: geo.size.width * travel)
                    .blendMode(.overlay)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 4.8)
                        .repeatForever(autoreverses: false)
                ) {
                    travel = 1.35
                }
            }
    }
}

extension View {
    func onboardingBreathingGlow(
        color: Color = OnboardingTheme.accentRed,
        minOpacity: Double = 0.18,
        maxOpacity: Double = 0.38
    ) -> some View {
        modifier(OnboardingBreathingGlowModifier(color: color, minOpacity: minOpacity, maxOpacity: maxOpacity))
    }

    func onboardingSubtleShimmer() -> some View {
        modifier(OnboardingShimmerModifier())
    }

    func onboardingStaggeredEntrance(_ active: Bool, index: Int, baseDelay: Double = 0.04) -> some View {
        opacity(active ? 1 : 0)
            .offset(y: active ? 0 : 18)
            .scaleEffect(active ? 1 : 0.96)
            .animation(
                OnboardingMotion.springPremium.delay(baseDelay + Double(index) * 0.045),
                value: active
            )
    }

    func onboardingStepTransition(active: Bool) -> some View {
        opacity(active ? 1 : 0)
            .scaleEffect(active ? 1 : 0.98)
            .animation(OnboardingMotion.springPremium, value: active)
    }

    /// Transition cinématique entre étapes onboarding (insertion / sortie).
    func onboardingStepChangeTransition() -> some View {
        transition(.asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.985))
                .combined(with: .offset(y: 20)),
            removal: .opacity
                .combined(with: .scale(scale: 1.012))
                .combined(with: .offset(y: -14))
        ))
    }
}

// MARK: - Sélection tactile

struct OnboardingSelectablePressStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isSelected ? 1.01 : 1))
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(OnboardingMotion.springSnappy, value: configuration.isPressed)
            .animation(OnboardingMotion.springPremium, value: isSelected)
    }
}

struct OnboardingSelectionGlowModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isSelected ? OnboardingTheme.accentRed.opacity(0.18) : .black.opacity(0.25),
                radius: isSelected ? 12 : 8,
                x: 0,
                y: isSelected ? 6 : 4
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(OnboardingTheme.accentRed.opacity(0.35), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func onboardingSelectionGlow(isSelected: Bool) -> some View {
        modifier(OnboardingSelectionGlowModifier(isSelected: isSelected))
    }
}
