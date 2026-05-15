//
//  TabBarIconComposer.swift
//  Balibu
//
//  Compose deux UIImages en une icône de tab bar façon "fan de cartes" :
//  carte gauche inclinée à -8°, carte droite à +6°, coins arrondis,
//  contour blanc fin, ombre douce. Rendu @3x pour la netteté retina.
//

import UIKit

enum TabBarIconComposer {

    // MARK: - Public API

    /// Génère une UIImage carrée 26×26 pt (@3x) à partir de deux images source.
    /// Les images sont affichées en aspect fill dans deux cartes portait qui se chevauchent.
    static func compose(leading: UIImage, trailing: UIImage) -> UIImage {
        let scale: CGFloat = 3
        let logicalSide: CGFloat = 26
        let px = logicalSide * scale // 78 px

        let pxSize = CGSize(width: px, height: px)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1        // on contrôle manuellement l'échelle
        format.opaque = false
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: pxSize, format: format)
        let composite = renderer.image { _ in
            // La carte trailing est dessinée en premier (derrière)
            drawCard(image: trailing, pxSize: pxSize,
                     xFraction: 0.63, yFraction: 0.50,
                     angle: 6 * .pi / 180)
            // La carte leading est dessinée par-dessus
            drawCard(image: leading, pxSize: pxSize,
                     xFraction: 0.37, yFraction: 0.50,
                     angle: -8 * .pi / 180)
        }

        return UIImage(cgImage: composite.cgImage!, scale: scale, orientation: .up)
    }

    // MARK: - Private drawing

    private static func drawCard(
        image: UIImage,
        pxSize: CGSize,
        xFraction: CGFloat,
        yFraction: CGFloat,
        angle: CGFloat
    ) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let cardW: CGFloat = pxSize.width  * 0.56   // ~44 px
        let cardH: CGFloat = pxSize.height * 0.74   // ~58 px
        let cr:    CGFloat = 5.0
        let borderW: CGFloat = 1.5

        let cx = pxSize.width  * xFraction
        let cy = pxSize.height * yFraction

        // Rect centré sur l'origine locale après transformation
        let rect = CGRect(x: -cardW / 2, y: -cardH / 2, width: cardW, height: cardH)

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: angle)

        // ── Ombre douce (dessinée avant le clip, donc non masquée) ──────────
        let shadowRect = rect.insetBy(dx: -0.5, dy: -0.5).offsetBy(dx: 0, dy: 2)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
        let shadowPath = UIBezierPath(roundedRect: shadowRect, cornerRadius: cr + 0.5)
        ctx.addPath(shadowPath.cgPath)
        ctx.fillPath()

        // ── Clip au contour arrondi de la carte ──────────────────────────────
        let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cr)
        ctx.addPath(clipPath.cgPath)
        ctx.clip()

        // Fond blanc (évite la transparence si l'image a un canal alpha)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(rect)

        // ── Image en aspect fill ─────────────────────────────────────────────
        let imgPxW = image.size.width  * image.scale
        let imgPxH = image.size.height * image.scale

        if imgPxW > 0, imgPxH > 0 {
            let fillScale = max(cardW / imgPxW, cardH / imgPxH)
            let drawW = imgPxW * fillScale
            let drawH = imgPxH * fillScale
            let drawRect = CGRect(x: -drawW / 2, y: -drawH / 2, width: drawW, height: drawH)
            image.draw(in: drawRect)
        }

        // ── Contour blanc (après clip retiré) ───────────────────────────────
        ctx.resetClip()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.88).cgColor)
        ctx.setLineWidth(borderW)
        let borderRect = rect.insetBy(dx: borderW / 2, dy: borderW / 2)
        let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: cr - borderW / 2)
        ctx.addPath(borderPath.cgPath)
        ctx.strokePath()

        ctx.restoreGState()
    }
}
