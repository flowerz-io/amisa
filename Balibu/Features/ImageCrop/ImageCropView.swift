//
//  ImageCropView.swift
//  Balibu
//
//  Écran de focus/crop MVP : zone carrée fixe au centre, pan + zoom sur l'image.
//

import SwiftUI
import UIKit

struct ImageCropView: View {
    let payload: SharedImagePayload
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ImageCropRepresentable(
                        image: image,
                        onConfirm: onConfirm,
                        onCancel: onCancel
                    )
                }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: DesignTokens.spacingM) {
                        ProgressView()
                            .tint(.white)
                        Text("Chargement…")
                            .font(DesignTokens.bodyFont)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            onCancel()
            return
        }
        print("[IMAGE_CROP_PRESENTED] originalSize=\(image.size.width)x\(image.size.height)")
        loadedImage = image
    }
}

// MARK: - UIKit wrapper (UIScrollView pour pan/zoom fiable)

private struct ImageCropRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> ImageCropViewController {
        ImageCropViewController(
            image: image,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    func updateUIViewController(_ uiViewController: ImageCropViewController, context: Context) {}
}

private final class ImageCropViewController: UIViewController {
    private let image: UIImage
    private let onConfirm: (UIImage) -> Void
    private let onCancel: () -> Void

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var overlayView: CropOverlayView!
    private var cropSize: CGFloat = 0

    init(image: UIImage, onConfirm: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScrollView()
        setupOverlay()
        setupToolbar()
        configureZoom()
    }

    private func setupScrollView() {
        let w = view.bounds.width
        let h = view.bounds.height
        cropSize = min(w, max(0, h - 120))
        if cropSize <= 0 { cropSize = 300 }

        scrollView = UIScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        view.addSubview(scrollView)

        imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: cropSize),
            scrollView.heightAnchor.constraint(equalToConstant: cropSize),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if scrollView != nil {
            layoutImageView()
        }
    }

    private func layoutImageView() {
        let sv = scrollView!
        let img = imageView!
        let size = cropSize

        let imgSize = image.size
        let aspect = imgSize.width / imgSize.height
        var frameSize: CGSize
        if aspect >= 1 {
            frameSize = CGSize(width: size * aspect, height: size)
        } else {
            frameSize = CGSize(width: size, height: size / aspect)
        }

        img.frame = CGRect(origin: .zero, size: frameSize)
        sv.contentSize = frameSize
        sv.contentInset = .zero

        let insetW = max(0, (size - frameSize.width) / 2)
        let insetH = max(0, (size - frameSize.height) / 2)
        sv.contentInset = UIEdgeInsets(top: insetH, left: insetW, bottom: insetH, right: insetW)
        if insetW > 0 || insetH > 0 {
            sv.contentOffset = CGPoint(x: -insetW, y: -insetH)
        }
    }

    private func setupOverlay() {
        overlayView = CropOverlayView(cropSize: cropSize)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        overlayView.updateCropSize(cropSize)
    }

    private func setupToolbar() {
        let cancelBtn = UIBarButtonItem(
            title: "Annuler",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        cancelBtn.tintColor = .white

        let spacer = UIBarButtonItem(systemItem: .flexibleSpace)

        let confirmBtn = UIBarButtonItem(
            title: "Utiliser cette sélection",
            style: .done,
            target: self,
            action: #selector(confirmTapped)
        )
        confirmBtn.tintColor = .white

        let toolBar = UIToolbar()
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.barTintColor = UIColor(white: 0.08, alpha: 1)
        toolBar.isTranslucent = false
        toolBar.setItems([cancelBtn, spacer, confirmBtn], animated: false)
        view.addSubview(toolBar)

        NSLayoutConstraint.activate([
            toolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolBar.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func configureZoom() {
        scrollView.zoomScale = 1.0
    }

    @objc private func cancelTapped() {
        print("[IMAGE_CROP_CANCELLED]")
        onCancel()
    }

    @objc private func confirmTapped() {
        let cropped = cropVisibleArea()
        print("[IMAGE_CROP_CONFIRMED] croppedSize=\(cropped.size.width)x\(cropped.size.height)")
        onConfirm(cropped)
    }

    private func cropVisibleArea() -> UIImage {
        let sv = scrollView!
        let zoomScale = sv.zoomScale
        let contentOffset = sv.contentOffset
        let imgViewSize = imageView.frame.size

        let visibleInContentView = CGRect(
            x: contentOffset.x,
            y: contentOffset.y,
            width: cropSize,
            height: cropSize
        )

        let scaleX = image.size.width / imgViewSize.width
        let scaleY = image.size.height / imgViewSize.height

        let cropRectInImage = CGRect(
            x: visibleInContentView.origin.x * scaleX / zoomScale,
            y: visibleInContentView.origin.y * scaleY / zoomScale,
            width: visibleInContentView.width * scaleX / zoomScale,
            height: visibleInContentView.height * scaleY / zoomScale
        )

        let clampedRect = cropRectInImage.intersection(CGRect(origin: .zero, size: image.size))

        guard !clampedRect.isEmpty, let cgImage = image.cgImage else {
            return image
        }

        let scale = image.scale
        let scaledRect = CGRect(
            x: clampedRect.origin.x * scale,
            y: clampedRect.origin.y * scale,
            width: clampedRect.width * scale,
            height: clampedRect.height * scale
        ).integral

        guard let croppedCG = cgImage.cropping(to: scaledRect) else {
            return image
        }

        return UIImage(cgImage: croppedCG, scale: scale, orientation: image.imageOrientation)
    }
}

extension ImageCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}

// MARK: - Overlay (zone sombre avec fenêtre carrée au centre)

private final class CropOverlayView: UIView {
    private var cropSize: CGFloat
    private var shapeLayer: CAShapeLayer?

    init(cropSize: CGFloat) {
        self.cropSize = cropSize
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCropSize(_ size: CGFloat) {
        cropSize = size
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateMask()
    }

    private func updateMask() {
        let path = UIBezierPath(rect: bounds)
        let centerX = bounds.midX
        let centerY = bounds.midY
        let cropRect = CGRect(
            x: centerX - cropSize / 2,
            y: centerY - cropSize / 2,
            width: cropSize,
            height: cropSize
        )
        path.append(UIBezierPath(rect: cropRect).reversing())

        if shapeLayer == nil {
            let layer = CAShapeLayer()
            layer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
            layer.fillRule = .evenOdd
            self.layer.addSublayer(layer)
            shapeLayer = layer
        }
        shapeLayer?.path = path.cgPath
        shapeLayer?.frame = bounds
    }
}
