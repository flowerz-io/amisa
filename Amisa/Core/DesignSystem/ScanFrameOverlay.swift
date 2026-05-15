//
//  ScanFrameOverlay.swift
//  Balibu
//
//  Cadre type « scan » : uniquement les coins, voile très léger (réutilisable).
//

import SwiftUI

enum ScanFrameGeometry {
    static func cornerLength(forSide side: CGFloat) -> CGFloat {
        min(28, max(18, side * 0.12))
    }
}

// MARK: - SwiftUI (prévisualisation / overlays)

/// Trace uniquement les quatre coins d’un rectangle (coordonnées locales).
struct ScanFrameCornersShape: Shape {
    var rect: CGRect
    var cornerLength: CGFloat

    func path(in _: CGRect) -> Path {
        cornerPath(in: rect, length: cornerLength)
    }

    private func cornerPath(in r: CGRect, length: CGFloat) -> Path {
        var p = Path()
        let L = length
        p.move(to: CGPoint(x: r.minX, y: r.minY + L))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + L, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - L, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + L))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - L))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - L, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + L, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - L))
        return p
    }
}

// MARK: - UIKit (recadrage image)

/// Remplace l’ancien voile noir : voile léger + coins uniquement.
final class ScanCropFrameOverlayView: UIView {
    private var holeFrame: CGRect = .zero
    private let dimLayer = CAShapeLayer()
    private let cornersLayer = CAShapeLayer()
    private var didRegisterTraitChanges = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.06).cgColor
        dimLayer.fillRule = .evenOdd
        layer.addSublayer(dimLayer)
        cornersLayer.fillColor = UIColor.clear.cgColor
        cornersLayer.lineWidth = 5
        cornersLayer.lineCap = .round
        cornersLayer.lineJoin = .round
        layer.addSublayer(cornersLayer)
        applyCropCornerStrokeColor()
        registerForUserInterfaceStyleChangesIfNeeded()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCropHoleFrame(_ rect: CGRect) {
        holeFrame = rect
        setNeedsLayout()
    }

    private func registerForUserInterfaceStyleChangesIfNeeded() {
        guard !didRegisterTraitChanges else { return }
        didRegisterTraitChanges = true
        guard #available(iOS 17.0, *) else { return }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyCropCornerStrokeColor()
        }
    }

    private func applyCropCornerStrokeColor() {
        let dark = traitCollection.userInterfaceStyle == .dark
        cornersLayer.strokeColor = (dark ? UIColor.white : UIColor.black).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: holeFrame).reversing())
        dimLayer.path = path.cgPath
        dimLayer.frame = bounds

        let L = ScanFrameGeometry.cornerLength(forSide: min(holeFrame.width, holeFrame.height))
        let r = holeFrame
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: r.minX, y: r.minY + L))
        cgPath.addLine(to: CGPoint(x: r.minX, y: r.minY))
        cgPath.addLine(to: CGPoint(x: r.minX + L, y: r.minY))
        cgPath.move(to: CGPoint(x: r.maxX - L, y: r.minY))
        cgPath.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        cgPath.addLine(to: CGPoint(x: r.maxX, y: r.minY + L))
        cgPath.move(to: CGPoint(x: r.maxX, y: r.maxY - L))
        cgPath.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        cgPath.addLine(to: CGPoint(x: r.maxX - L, y: r.maxY))
        cgPath.move(to: CGPoint(x: r.minX + L, y: r.maxY))
        cgPath.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        cgPath.addLine(to: CGPoint(x: r.minX, y: r.maxY - L))
        cornersLayer.path = cgPath
        cornersLayer.frame = bounds
    }
}
