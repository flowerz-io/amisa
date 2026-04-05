//
//  CameraViewModel.swift
//  Balibu
//
//  État UI caméra (permissions, zoom, flash, bascule) ; délègue la session à CameraSessionController.
//

import AVFoundation
import Combine
import Photos
import SwiftUI
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    enum CameraUIState: Equatable {
        case loading
        case ready
        case denied
        case noHardware
    }

    @Published var uiState: CameraUIState = .loading
    @Published var cameraAuth: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryAuth: PHAuthorizationStatus = .notDetermined
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var zoomDisplay: CGFloat = 1
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var isCapturing = false

    let sessionController = CameraSessionController()

    private var pinchStartZoom: CGFloat = 1
    private var isPinching = false

    func onAppear() {
        cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryAuth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        refreshPhotoLibraryAuthorization()

        guard sessionController.isHardwareAvailable else {
            uiState = .noHardware
            return
        }

        switch cameraAuth {
        case .authorized:
            startSessionAfterConfig()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let model = self else { return }
                Task { @MainActor in
                    model.cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
                    if granted {
                        model.startSessionAfterConfig()
                    } else {
                        model.uiState = .denied
                    }
                }
            }
        default:
            uiState = .denied
        }
    }

    func refreshPhotoLibraryAuthorization() {
        photoLibraryAuth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if photoLibraryAuth == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                guard let model = self else { return }
                Task { @MainActor in
                    model.photoLibraryAuth = status
                }
            }
        }
    }

    func onDisappear() {
        sessionController.stopRunning()
    }

    private func startSessionAfterConfig() {
        uiState = .loading
        sessionController.configureSession { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.cameraPosition = self.sessionController.currentPosition
                    self.zoomDisplay = 1
                    self.pinchStartZoom = 1
                    self.sessionController.startRunning()
                    self.uiState = .ready
                } else {
                    self.uiState = .noHardware
                }
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func cycleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    func flashIconName() -> String {
        switch flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    func flipCamera() {
        sessionController.switchCamera { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.cameraPosition = self.sessionController.currentPosition
                self.zoomDisplay = 1
                self.pinchStartZoom = 1
                self.sessionController.setZoomFactor(1)
            }
        }
    }

    func pinchChanged(scale: CGFloat) {
        if !isPinching {
            pinchStartZoom = zoomDisplay
            isPinching = true
        }
        let next = max(1, min(pinchStartZoom * scale, 10))
        zoomDisplay = next
        sessionController.setZoomFactor(next)
    }

    func pinchEnded() {
        isPinching = false
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard uiState == .ready else { return }
        isCapturing = true
        sessionController.capturePhoto(flashMode: flashMode) { [weak self] data in
            guard let model = self else { return }
            Task { @MainActor in
                model.isCapturing = false
                completion(data)
            }
        }
    }
}
