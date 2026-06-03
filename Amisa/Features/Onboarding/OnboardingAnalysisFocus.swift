//
//  OnboardingAnalysisFocus.swift
//  Amisa
//

import SwiftUI
import UIKit

// MARK: - Manual focus tuning
// Coordonnées normalisées 0…1 relatives à l’IMAGE AFFICHÉE (pas l’écran).
// Origine : coin supérieur gauche de la photo visible (après crop .fill).

struct FocusPreset: Equatable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let detectedLabel: String

    var normalizedRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func rect(in imageFrame: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + imageFrame.width * x,
            y: imageFrame.minY + imageFrame.height * y,
            width: imageFrame.width * width,
            height: imageFrame.height * height
        )
    }
}

enum OnboardingAnalysisFocusPresets {

    /// Sneakers — look féminin (cadrage serré sur les pieds.
    static let female = FocusPreset(
        x: 0.45,
        y: 0.785,
        width: 0.29,
        height: 0.14,
        detectedLabel: "Onitsuka Tiger détectée"
    )

    /// Casquette — look masculin (cadrage tête).
    static let male = FocusPreset(
        x: 0.48,
        y: 0.055,
        width: 0.17,
        height: 0.12,
        detectedLabel: "Casquette NY Yankees détectée"
    )

    static func preset(for lookId: String) -> FocusPreset {
        switch lookId {
        case "feminine": female
        case "masculine": male
        default:
            FocusPreset(x: 0.25, y: 0.35, width: 0.5, height: 0.4, detectedLabel: "Pièce détectée")
        }
    }
}

// MARK: - Image affichée (.fill) dans le conteneur

enum DisplayedImageLayout {
    static func frame(imageName: String, in containerSize: CGSize) -> CGRect {
        guard let image = UIImage(named: imageName), image.size.width > 0, image.size.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        return frame(imageSize: image.size, in: containerSize)
    }

    static func frame(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else { return .zero }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let height = containerSize.height
            let width = height * imageAspect
            let x = (containerSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        } else {
            let width = containerSize.width
            let height = width / imageAspect
            let y = (containerSize.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        }
    }
}

// MARK: - Crop focus (aperçu résultats)

struct OnboardingFocusCropThumbnail: View {
    let imageName: String
    let normalizedFocus: CGRect
    var zoomScale: CGFloat = 1

    var body: some View {
        FocusCroppedFillImage(
            imageName: imageName,
            focusRect: normalizedFocus,
            zoomScale: zoomScale
        )
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct FocusCroppedFillImage: View {
    let imageName: String
    let focusRect: CGRect
    var zoomScale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if let uiImage = UIImage(named: imageName) {
                let offset = FocusImageCrop.offset(
                    container: size,
                    imageSize: uiImage.size,
                    focusRect: focusRect,
                    zoomScale: zoomScale
                )
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(zoomScale)
                    .frame(width: size.width, height: size.height)
                    .offset(offset)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
        }
    }
}

enum FocusImageCrop {
    private static let focusBiasY: CGFloat = -0.07

    static func offset(
        container: CGSize,
        imageSize: CGSize,
        focusRect: CGRect,
        zoomScale: CGFloat = 1
    ) -> CGSize {
        guard container.width > 0, container.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let zoom = max(1, zoomScale)
        let viewAspect = container.width / container.height
        let imageAspect = imageSize.width / imageSize.height

        let scaledWidth: CGFloat
        let scaledHeight: CGFloat
        if imageAspect > viewAspect {
            scaledHeight = container.height * zoom
            scaledWidth = scaledHeight * imageAspect
        } else {
            scaledWidth = container.width * zoom
            scaledHeight = scaledWidth / imageAspect
        }

        let focusX = focusRect.midX * scaledWidth
        let focusY = (focusRect.midY + focusBiasY) * scaledHeight

        var offsetX = container.width * 0.5 - focusX
        var offsetY = container.height * 0.5 - focusY

        let maxOffsetX = max(0, (scaledWidth - container.width) * 0.5)
        let maxOffsetY = max(0, (scaledHeight - container.height) * 0.5)
        offsetX = min(maxOffsetX, max(-maxOffsetX, offsetX))
        offsetY = min(maxOffsetY, max(-maxOffsetY, offsetY))

        return CGSize(width: offsetX, height: offsetY)
    }
}

// MARK: - Calcul unique du focus (image → écran)

enum AnalysisFocusLayout {
    static func focusRect(imageName: String, preset: FocusPreset, containerSize: CGSize) -> CGRect {
        let imageFrame = DisplayedImageLayout.frame(imageName: imageName, in: containerSize)
        return preset.rect(in: imageFrame)
    }
}

// MARK: - Overlay analyse

struct AnalysisFocusOverlay: View {
    let containerSize: CGSize
    let focusRect: CGRect
    let isVisible: Bool
    let scanProgress: CGFloat
    let pulseOpacity: Double
    let breathingScale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            dimmingMask

            FocusDetectionBox(
                focusRect: focusRect,
                scanProgress: scanProgress,
                isActive: isVisible,
                pulseOpacity: pulseOpacity
            )
            .opacity(isVisible ? 1 : 0)
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .scaleEffect(breathingScale, anchor: motionAnchor)
        .animation(.easeOut(duration: 0.45), value: isVisible)
    }

    private var motionAnchor: UnitPoint {
        guard containerSize.width > 0, containerSize.height > 0 else { return .center }
        return UnitPoint(
            x: focusRect.midX / containerSize.width,
            y: focusRect.midY / containerSize.height
        )
    }

    private var dimmingMask: some View {
        Rectangle()
            .fill(Color.black.opacity(isVisible ? 0.44 : 0.5))
            .frame(width: containerSize.width, height: containerSize.height)
            .mask {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .frame(width: containerSize.width, height: containerSize.height)
                    focusCutoutShape
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .allowsHitTesting(false)
    }

    private var focusCutoutShape: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .frame(width: focusRect.width, height: focusRect.height)
            .offset(x: focusRect.minX, y: focusRect.minY)
    }
}

// MARK: - Boîte de détection (source de vérité unique)

struct FocusDetectionBox: View {
    let focusRect: CGRect
    let scanProgress: CGFloat
    let isActive: Bool
    let pulseOpacity: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: focusRect.width, height: focusRect.height)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                .frame(width: focusRect.width, height: focusRect.height)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(OnboardingTheme.accentRed.opacity(pulseOpacity * 0.35), lineWidth: 1)
                .blur(radius: 2)
                .frame(width: focusRect.width, height: focusRect.height)

            FocusCorners()
                .frame(width: focusRect.width, height: focusRect.height)

            horizontalScanBeam
                .opacity(isActive ? 1 : 0)
        }
        .frame(width: focusRect.width, height: focusRect.height, alignment: .topLeading)
        .offset(x: focusRect.minX, y: focusRect.minY)
    }

    private var horizontalScanBeam: some View {
        let beamY = focusRect.height * scanProgress

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        OnboardingTheme.accentRed.opacity(0.15),
                        OnboardingTheme.accentRed.opacity(0.85),
                        OnboardingTheme.accentRed.opacity(0.15),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: focusRect.width * 0.92, height: 1.5)
            .shadow(color: OnboardingTheme.accentRed.opacity(0.55), radius: 6, x: 0, y: 0)
            .offset(y: max(0, beamY - 0.75))
    }
}

// MARK: - Coins rouges (angles exacts du rectangle)

struct FocusCorners: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let arm = min(w, h) * 0.22

            ZStack(alignment: .topLeading) {
                bracketPath(width: w, height: h, arm: arm)
                    .stroke(
                        OnboardingTheme.accentRed.opacity(0.55),
                        style: StrokeStyle(lineWidth: 5, lineCap: .square)
                    )
                    .blur(radius: 3)

                bracketPath(width: w, height: h, arm: arm)
                    .stroke(
                        OnboardingTheme.accentRed.opacity(0.95),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .square)
                    )
            }
        }
    }

    private func bracketPath(width w: CGFloat, height h: CGFloat, arm: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: arm))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: arm, y: 0))

            path.move(to: CGPoint(x: w - arm, y: 0))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: arm))

            path.move(to: CGPoint(x: 0, y: h - arm))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: arm, y: h))

            path.move(to: CGPoint(x: w - arm, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: w, y: h - arm))
        }
    }
}

// MARK: - Position du texte statut (sans chevauchement)

enum AnalysisStatusTextLayout {
    static func centerY(
        focusRect: CGRect,
        containerSize: CGSize,
        textBlockHeight: CGFloat,
        gap: CGFloat = 28,
        safeBottom: CGFloat = 40
    ) -> CGFloat {
        let belowCenter = focusRect.maxY + gap + textBlockHeight / 2
        let belowBottom = belowCenter + textBlockHeight / 2

        if belowBottom <= containerSize.height - safeBottom {
            return belowCenter
        }

        let aboveCenter = focusRect.minY - gap - textBlockHeight / 2
        let aboveTop = aboveCenter - textBlockHeight / 2
        if aboveTop >= 16 {
            return aboveCenter
        }

        return containerSize.height - safeBottom - textBlockHeight / 2
    }
}
