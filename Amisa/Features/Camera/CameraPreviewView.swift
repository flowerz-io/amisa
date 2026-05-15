//
//  CameraPreviewView.swift
//  Balibu
//
//  Couche de prévisualisation AVCaptureVideoPreviewLayer pour SwiftUI.
//

import AVFoundation
import SwiftUI
import UIKit

/// Vue UIKit dont la couche est un `AVCaptureVideoPreviewLayer`.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func configure(session: AVCaptureSession, mirrored: Bool) {
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill

        if let conn = videoPreviewLayer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = mirrored
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let v = CameraPreviewUIView()
        v.configure(session: session, mirrored: isMirrored)
        return v
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.configure(session: session, mirrored: isMirrored)
    }
}
