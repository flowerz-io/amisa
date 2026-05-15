//
//  GoogleLensCropView.swift
//
//  Composant partagé : app native + Share Extension.
//  • Aucun UIApplication.shared
//  • Aucune dépendance propre à l'app
//
//  Usage :
//    GoogleLensCropRepresentable(image: uiImage) { controller in
//        self.cropController = controller
//    }
//    ...
//    let cropped = cropController?.exportCroppedImage()
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Wrapper

struct GoogleLensCropRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    var onControllerReady: (GoogleLensCropViewController) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onControllerReady)
    }

    func makeUIViewController(context: Context) -> GoogleLensCropViewController {
        let vc = GoogleLensCropViewController(image: image)
        DispatchQueue.main.async { context.coordinator.onReady(vc) }
        return vc
    }

    func updateUIViewController(_ uiViewController: GoogleLensCropViewController, context: Context) {}

    final class Coordinator {
        let onReady: (GoogleLensCropViewController) -> Void
        init(onReady: @escaping (GoogleLensCropViewController) -> Void) { self.onReady = onReady }
    }
}

// MARK: - UIKit Controller

final class GoogleLensCropViewController: UIViewController {

    // MARK: Properties

    private let sourceImage: UIImage
    private let scrollView   = UIScrollView()
    private let imageView    = UIImageView()
    private let overlayView  = LensCropOverlayView()

    private var cropRect: CGRect = .zero
    private var dragMode: DragMode = .none
    private var dragStartCropRect: CGRect = .zero
    private var dragStartLocation: CGPoint = .zero
    private var didInitialLayout = false

    private enum DragMode {
        case none, move
        case resizeTL, resizeTR, resizeBL, resizeBR
    }

    private let minCropSize: CGFloat = 90

    // MARK: Init

    init(image: UIImage) {
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: View Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground   // adaptatif light/dark
        view.clipsToBounds = true

        setupScrollView()
        setupImageView()
        setupOverlayView()
        setupGestures()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        layoutImage()
    }

    // MARK: Setup

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupImageView() {
        imageView.image = sourceImage
        imageView.contentMode = .scaleToFill
        scrollView.addSubview(imageView)
    }

    private func setupOverlayView() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupGestures() {
        let cropPan = UIPanGestureRecognizer(target: self, action: #selector(handleCropPan))
        cropPan.delegate = self
        overlayView.addGestureRecognizer(cropPan)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    // MARK: Image Layout

    private func layoutImage() {
        let viewSize  = view.bounds.size
        let imgSize   = sourceImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }

        let scale   = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let fitSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)

        let sizeChanged = abs(imageView.frame.width - fitSize.width) > 0.5

        if sizeChanged || !didInitialLayout {
            imageView.frame      = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            scrollView.zoomScale   = 1.0
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 5.0
            centerImageInScrollView()
        }

        if !didInitialLayout {
            didInitialLayout = true
            applyAutomaticCenterCrop()
        }
    }

    private func centerImageInScrollView() {
        let viewSize  = view.bounds.size
        let imgFrame  = imageView.frame
        let insetX    = max(0, (viewSize.width  - imgFrame.width)  / 2)
        let insetY    = max(0, (viewSize.height - imgFrame.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    /// Crop centré avec marge sur le plus petit côté affiché — défaut rapide avant ajustement manuel.
    func applyAutomaticCenterCrop() {
        let imgFrame = displayedImageFrame()
        guard imgFrame.width > 2, imgFrame.height > 2 else { return }

        let maxSide = min(imgFrame.width, imgFrame.height)
        let marginFraction: CGFloat = 0.09
        let side = max(minCropSize, maxSide * (1 - 2 * marginFraction))
        let bounds = view.bounds.insetBy(dx: 8, dy: 8)

        var r = CGRect(
            x: imgFrame.midX - side / 2,
            y: imgFrame.midY - side / 2,
            width: side,
            height: side
        )
        r = r.intersection(bounds)

        guard r.width >= minCropSize - 0.5, r.height >= minCropSize - 0.5 else { return }
        cropRect = r
        overlayView.setCropRect(cropRect)
    }

    // MARK: Gestures

    @objc private func handleCropPan(_ gesture: UIPanGestureRecognizer) {
        let loc = gesture.location(in: view)
        switch gesture.state {
        case .began:
            dragStartCropRect  = cropRect
            dragStartLocation  = loc
            dragMode           = resolveDragMode(at: loc)
        case .changed:
            guard dragMode != .none else { return }
            let dx = loc.x - dragStartLocation.x
            let dy = loc.y - dragStartLocation.y
            applyDrag(dx: dx, dy: dy)
        case .ended, .cancelled, .failed:
            dragMode = .none
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.scrollView.zoomScale = 1.0
            self.centerImageInScrollView()
            let inset = self.scrollView.contentInset
            self.scrollView.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
        }
    }

    private func resolveDragMode(at point: CGPoint) -> DragMode {
        let cr     = cropRect
        let radius = overlayView.cornerHitRadius
        let corners: [(CGPoint, DragMode)] = [
            (.init(x: cr.minX, y: cr.minY), .resizeTL),
            (.init(x: cr.maxX, y: cr.minY), .resizeTR),
            (.init(x: cr.minX, y: cr.maxY), .resizeBL),
            (.init(x: cr.maxX, y: cr.maxY), .resizeBR),
        ]
        for (cp, mode) in corners {
            if hypot(point.x - cp.x, point.y - cp.y) < radius { return mode }
        }
        return cr.contains(point) ? .move : .none
    }

    private func applyDrag(dx: CGFloat, dy: CGFloat) {
        var r     = dragStartCropRect
        let b     = view.bounds
        let minS  = minCropSize

        func cl(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

        switch dragMode {
        case .none: return
        case .move:
            r.origin.x = cl(r.origin.x + dx, 0, b.width  - r.width)
            r.origin.y = cl(r.origin.y + dy, 0, b.height - r.height)

        case .resizeTL:
            let nx = cl(r.minX + dx, 0, r.maxX - minS)
            let ny = cl(r.minY + dy, 0, r.maxY - minS)
            r.size.width  += r.origin.x - nx
            r.size.height += r.origin.y - ny
            r.origin.x = nx
            r.origin.y = ny

        case .resizeTR:
            let nmx = cl(r.maxX + dx, r.minX + minS, b.width)
            let ny  = cl(r.minY + dy, 0, r.maxY - minS)
            r.size.width  = nmx - r.minX
            r.size.height += r.origin.y - ny
            r.origin.y = ny

        case .resizeBL:
            let nx  = cl(r.minX + dx, 0, r.maxX - minS)
            let nmy = cl(r.maxY + dy, r.minY + minS, b.height)
            r.size.width  += r.origin.x - nx
            r.size.height  = nmy - r.minY
            r.origin.x = nx

        case .resizeBR:
            r.size.width  = cl(r.maxX + dx, r.minX + minS, b.width)  - r.minX
            r.size.height = cl(r.maxY + dy, r.minY + minS, b.height) - r.minY
        }

        cropRect = r
        overlayView.setCropRect(r)
    }

    // MARK: Export

    /// Retourne l'image recadrée selon la zone sélectionnée à l'écran.
    func exportCroppedImage() -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }

        let imageFrame   = displayedImageFrame()
        let intersection = cropRect.intersection(imageFrame)
        guard intersection.width > 1, intersection.height > 1 else { return nil }

        let pixW = CGFloat(cgImage.width)
        let pixH = CGFloat(cgImage.height)
        let scaleX = pixW / imageFrame.width
        let scaleY = pixH / imageFrame.height

        let pixRect = CGRect(
            x: (intersection.minX - imageFrame.minX) * scaleX,
            y: (intersection.minY - imageFrame.minY) * scaleY,
            width:  intersection.width  * scaleX,
            height: intersection.height * scaleY
        ).integral

        let clamped = pixRect.intersection(CGRect(x: 0, y: 0, width: pixW, height: pixH))
        guard clamped.width > 0.5, clamped.height > 0.5,
              let cropped = cgImage.cropping(to: clamped) else { return nil }

        return UIImage(cgImage: cropped, scale: sourceImage.scale,
                       orientation: sourceImage.imageOrientation)
    }

    // MARK: - Normalized Crop Rect (0–1)

    /// CGRect normalisé 0-1 correspondant à la zone sélectionnée dans l'image originale.
    func normalizedCropRect() -> CGRect {
        let frame = displayedImageFrame()
        guard frame.width > 0, frame.height > 0 else { return .init(x: 0, y: 0, width: 1, height: 1) }
        let inter = cropRect.intersection(frame)
        return CGRect(
            x: (inter.minX - frame.minX) / frame.width,
            y: (inter.minY - frame.minY) / frame.height,
            width:  inter.width  / frame.width,
            height: inter.height / frame.height
        )
    }

    // MARK: Helpers

    /// Cadre affiché de l'image dans le système de coordonnées du view controller.
    private func displayedImageFrame() -> CGRect {
        imageView.convert(imageView.bounds, to: view)
    }
}

// MARK: - UIScrollViewDelegate

extension GoogleLensCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let w = imageView.frame.width
        let h = imageView.frame.height
        let bw = scrollView.bounds.width
        let bh = scrollView.bounds.height
        let ox = max((bw - w) / 2, 0)
        let oy = max((bh - h) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: oy, left: ox, bottom: oy, right: ox)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension GoogleLensCropViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let loc = gestureRecognizer.location(in: view)
        return resolveDragMode(at: loc) != .none
    }
}

// MARK: - Overlay View

private final class LensCropOverlayView: UIView {
    private(set) var cropRect: CGRect = .zero
    let cornerHitRadius: CGFloat = 44

    private let dimLayer     = CAShapeLayer()
    private let cornersLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque        = false

        dimLayer.fillColor  = UIColor.black.withAlphaComponent(0.45).cgColor
        dimLayer.fillRule   = .evenOdd
        layer.addSublayer(dimLayer)

        cornersLayer.fillColor    = UIColor.clear.cgColor
        cornersLayer.strokeColor  = UIColor.white.cgColor
        cornersLayer.lineWidth    = 5
        cornersLayer.lineCap      = .round
        cornersLayer.lineJoin     = .round
        cornersLayer.shadowColor  = UIColor.black.cgColor
        cornersLayer.shadowOpacity = 0.55
        cornersLayer.shadowRadius = 2.5
        cornersLayer.shadowOffset = .zero
        layer.addSublayer(cornersLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setCropRect(_ rect: CGRect) {
        cropRect = rect
        setNeedsLayout()
    }

    // MARK: Hit-test — passe les touches extérieures au scroll view

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let cr     = cropRect
        let radius = cornerHitRadius
        let corners: [CGPoint] = [
            .init(x: cr.minX, y: cr.minY), .init(x: cr.maxX, y: cr.minY),
            .init(x: cr.minX, y: cr.maxY), .init(x: cr.maxX, y: cr.maxY),
        ]
        for cp in corners {
            if hypot(point.x - cp.x, point.y - cp.y) < radius { return self }
        }
        return cr.contains(point) ? self : nil
    }

    // MARK: Layout (CALayer rendering)

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        // Voile sombre avec trou
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: cropRect).reversing())
        dimLayer.path  = path.cgPath
        dimLayer.frame = bounds

        // Poignées de coin (style Google Lens)
        let L: CGFloat = 34
        let r = cropRect
        let cp = CGMutablePath()
        // TL
        cp.move(to:    .init(x: r.minX,         y: r.minY + L))
        cp.addLine(to: .init(x: r.minX,         y: r.minY))
        cp.addLine(to: .init(x: r.minX + L,     y: r.minY))
        // TR
        cp.move(to:    .init(x: r.maxX - L,     y: r.minY))
        cp.addLine(to: .init(x: r.maxX,         y: r.minY))
        cp.addLine(to: .init(x: r.maxX,         y: r.minY + L))
        // BR
        cp.move(to:    .init(x: r.maxX,         y: r.maxY - L))
        cp.addLine(to: .init(x: r.maxX,         y: r.maxY))
        cp.addLine(to: .init(x: r.maxX - L,     y: r.maxY))
        // BL
        cp.move(to:    .init(x: r.minX + L,     y: r.maxY))
        cp.addLine(to: .init(x: r.minX,         y: r.maxY))
        cp.addLine(to: .init(x: r.minX,         y: r.maxY - L))

        cornersLayer.path  = cp
        cornersLayer.frame = bounds
    }
}
