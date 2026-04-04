//
//  CameraSessionController.swift
//  Balibu
//
//  Session AVCapture : prévisualisation, zoom, flash (photo), bascule caméra, capture JPEG.
//

import AVFoundation
import Foundation
import UIKit

/// Contrôleur session hors MainActor : configuration et `startRunning` sur une file dédiée.
final class CameraSessionController: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "io.balibu.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?

    private(set) var currentPosition: AVCaptureDevice.Position = .back
    private(set) var currentDevice: AVCaptureDevice?

    private var photoCompletion: ((Data?) -> Void)?

    /// Facteur demandé (1…max device, plafonné).
    private var pendingZoomFactor: CGFloat = 1

    var isRunning: Bool { session.isRunning }

    /// `true` si aucune caméra (ex. simulateur).
    var isHardwareAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func configureSession(completion: @escaping (Bool, String?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isHardwareAvailable else {
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            if let existing = self.videoInput {
                self.session.removeInput(existing)
                self.videoInput = nil
            }
            if self.session.outputs.contains(self.photoOutput) {
                self.session.removeOutput(self.photoOutput)
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion(false, String(localized: "Caméra indisponible.")) }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                    self.currentDevice = device
                }
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                self.photoOutput.isHighResolutionCaptureEnabled = true
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
                return
            }

            self.session.commitConfiguration()
            self.applyZoomLocked()
            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func switchCamera(completion: (() -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let next: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            self.currentPosition = next
            self.session.beginConfiguration()
            if let input = self.videoInput {
                self.session.removeInput(input)
                self.videoInput = nil
            }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: next) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion?() }
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                    self.currentDevice = device
                }
                self.pendingZoomFactor = 1
                self.applyZoomLocked()
            } catch {
                // ignore
            }
            self.session.commitConfiguration()
            DispatchQueue.main.async { completion?() }
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        pendingZoomFactor = factor
        sessionQueue.async { [weak self] in
            self?.applyZoomLocked()
        }
    }

    private func applyZoomLocked() {
        guard let device = currentDevice else { return }
        let maxZ = min(device.activeFormat.videoMaxZoomFactor, 10)
        let clamped = max(1, min(pendingZoomFactor, maxZ))
        pendingZoomFactor = clamped
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            // ignore
        }
    }

    /// Capture JPEG ; flash appliqué sur la caméra arrière si disponible.
    func capturePhoto(flashMode: AVCaptureDevice.FlashMode, completion: @escaping (Data?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.currentPosition == .back, self.currentDevice?.hasFlash == true {
                settings.flashMode = flashMode
            }
            self.photoCompletion = completion
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        let callback = photoCompletion
        photoCompletion = nil
        DispatchQueue.main.async {
            callback?(data)
        }
    }
}
