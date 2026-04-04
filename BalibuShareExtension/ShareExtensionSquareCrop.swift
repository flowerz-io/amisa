//
//  ShareExtensionSquareCrop.swift
//  BalibuShareExtension
//
//  Copie logique alignée sur Balibu/Features/SharedImport/SquareCropEditor.swift (cadre carré + export).
//

import SwiftUI
import UIKit

struct ShareSquareCropRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    var onControllerReady: (ShareSquareCropEditorViewController) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onControllerReady)
    }

    func makeUIViewController(context: Context) -> ShareSquareCropEditorViewController {
        let vc = ShareSquareCropEditorViewController(image: image)
        DispatchQueue.main.async {
            context.coordinator.onReady(vc)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ShareSquareCropEditorViewController, context: Context) {}

    final class Coordinator {
        let onReady: (ShareSquareCropEditorViewController) -> Void
        init(onReady: @escaping (ShareSquareCropEditorViewController) -> Void) {
            self.onReady = onReady
        }
    }
}

final class ShareSquareCropEditorViewController: UIViewController {
    private let sourceImage: UIImage
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlayView = ShareCropDimmingOverlayView()

    private var cropSide: CGFloat = 280
    private var lastLaidOutSize: CGSize = .zero
    private var scrollWidthConstraint: NSLayoutConstraint!
    private var scrollHeightConstraint: NSLayoutConstraint!

    init(image: UIImage) {
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.secondarySystemGroupedBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        view.addSubview(scrollView)

        imageView.image = sourceImage
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)

        scrollWidthConstraint = scrollView.widthAnchor.constraint(equalToConstant: 280)
        scrollHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 280)
        NSLayoutConstraint.activate([
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),
            scrollWidthConstraint,
            scrollHeightConstraint,
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let padding: CGFloat = 16
        let maxSide = min(view.bounds.width - padding * 2, 320)
        let newSide = max(200, maxSide)

        if abs(newSide - cropSide) > 0.5 || view.bounds.size != lastLaidOutSize {
            cropSide = newSide
            scrollWidthConstraint.constant = newSide
            scrollHeightConstraint.constant = newSide
            scrollView.zoomScale = 1
            layoutImageForCrop()
            lastLaidOutSize = view.bounds.size
        }

        let hole = scrollView.convert(scrollView.bounds, to: view)
        overlayView.setCropHoleFrame(hole)
    }

    private func layoutImageForCrop() {
        let size = cropSide
        let imgSize = sourceImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }

        let aspect = imgSize.width / imgSize.height
        let frameSize: CGSize
        if aspect >= 1 {
            frameSize = CGSize(width: size * aspect, height: size)
        } else {
            frameSize = CGSize(width: size, height: size / aspect)
        }

        imageView.frame = CGRect(origin: .zero, size: frameSize)
        scrollView.contentSize = frameSize

        let insetW = max(0, (size - frameSize.width) / 2)
        let insetH = max(0, (size - frameSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: insetH, left: insetW, bottom: insetH, right: insetW)
        if insetW > 0 || insetH > 0 {
            scrollView.contentOffset = CGPoint(x: -insetW, y: -insetH)
        }
    }

    func exportCroppedImage() -> UIImage? {
        guard let image = imageView.image, let cgImage = image.cgImage else { return nil }

        let visibleInImageView = scrollView.convert(scrollView.bounds, to: imageView)
        let imageBounds = imageView.bounds
        let cropInView = visibleInImageView.intersection(imageBounds)
        guard cropInView.width > 0.5, cropInView.height > 0.5 else { return nil }

        let displayed = displayedImageRect(in: imageView)
        let cropInDisplayed = cropInView.intersection(displayed)
        guard cropInDisplayed.width > 0.5, cropInDisplayed.height > 0.5 else { return nil }

        let imgSize = image.size
        let scaleX = imgSize.width / displayed.width
        let scaleY = imgSize.height / displayed.height

        let cropInImagePoints = CGRect(
            x: (cropInDisplayed.minX - displayed.minX) * scaleX,
            y: (cropInDisplayed.minY - displayed.minY) * scaleY,
            width: cropInDisplayed.width * scaleX,
            height: cropInDisplayed.height * scaleY
        )

        let s = image.scale
        let px = CGRect(
            x: cropInImagePoints.origin.x * s,
            y: cropInImagePoints.origin.y * s,
            width: cropInImagePoints.width * s,
            height: cropInImagePoints.height * s
        ).integral

        let iw = CGFloat(cgImage.width)
        let ih = CGFloat(cgImage.height)
        let clamped = px.intersection(CGRect(x: 0, y: 0, width: iw, height: ih))
        guard clamped.width > 0.5, clamped.height > 0.5,
              let cropped = cgImage.cropping(to: clamped) else { return nil }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private func displayedImageRect(in imageView: UIImageView) -> CGRect {
        guard let img = imageView.image else { return imageView.bounds }
        let viewSize = imageView.bounds.size
        let imageSize = img.size
        guard imageSize.width > 0, imageSize.height > 0 else { return imageView.bounds }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (viewSize.width - displayedSize.width) / 2,
            y: (viewSize.height - displayedSize.height) / 2
        )
        return CGRect(origin: origin, size: displayedSize)
    }
}

extension ShareSquareCropEditorViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let w = imageView.frame.width
        let h = imageView.frame.height
        let offsetX = max((scrollView.bounds.width - w) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - h) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
}

private final class ShareCropDimmingOverlayView: UIView {
    private var holeFrame: CGRect = .zero
    private var shapeLayer: CAShapeLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCropHoleFrame(_ rect: CGRect) {
        holeFrame = rect
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: holeFrame).reversing())

        if shapeLayer == nil {
            let layer = CAShapeLayer()
            layer.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
            layer.fillRule = .evenOdd
            self.layer.addSublayer(layer)
            shapeLayer = layer
        }
        shapeLayer?.path = path.cgPath
        shapeLayer?.frame = bounds
    }
}
