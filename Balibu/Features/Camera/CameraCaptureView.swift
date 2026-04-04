//
//  CameraCaptureView.swift
//  Balibu
//
//  Écran plein écran : prévisualisation, réglages, bande photothèque, puis flux existant via SharedImportPayload.
//

import AVFoundation
import Photos
import SwiftUI

struct CameraCaptureView: View {
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var recentLibrary = RecentPhotosLibraryModel()

    let onCapturedImage: (SharedImportPayload) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Même opacité qu’avant pour le ruban récents (fond unifié zone basse).
    private let bottomPanelOpacity: CGFloat = 0.38

    var body: some View {
        ZStack(alignment: .bottom) {
            previewStack
                .ignoresSafeArea()

            VStack {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            bottomPanel
        }
        .background(Color.black)
        .onAppear {
            viewModel.onAppear()
            recentLibrary.requestAccessIfNeeded()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    /// Zone basse unique : zoom → Récents → obturateur + switch (fond noir semi-transparent pleine largeur).
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            if viewModel.uiState == .ready {
                zoomBadge
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            Text(String(localized: "Récents"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            RecentPhotosStrip(library: recentLibrary) { asset in
                selectFromLibrary(asset)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            bottomControls
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.black.opacity(bottomPanelOpacity)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var previewStack: some View {
        ZStack {
            Color.black
            switch viewModel.uiState {
            case .ready:
                CameraPreviewView(
                    session: viewModel.sessionController.session,
                    isMirrored: viewModel.cameraPosition == .front
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            viewModel.pinchChanged(scale: value)
                        }
                        .onEnded { _ in
                            viewModel.pinchEnded()
                        }
                )
            case .loading:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            case .denied:
                deniedState
            case .noHardware:
                noHardwareState
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Circle())
            }
            .accessibilityLabel(String(localized: "Fermer"))

            Spacer()

            if viewModel.cameraPosition == .back, viewModel.uiState == .ready {
                Button {
                    viewModel.cycleFlash()
                } label: {
                    Image(systemName: viewModel.flashIconName())
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Flash"))
            }
        }
    }

    private var zoomBadge: some View {
        Text("\(String(format: "%.1f", viewModel.zoomDisplay))×")
            .font(.system(.subheadline, design: .rounded).weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
    }

    private var bottomControls: some View {
        ZStack {
            HStack {
                Spacer()
                shutterButton
                Spacer()
            }
            HStack {
                Spacer()
                Button {
                    viewModel.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                }
                .disabled(viewModel.uiState != .ready)
                .opacity(viewModel.uiState == .ready ? 1 : 0.4)
                .accessibilityLabel(String(localized: "Changer de caméra"))
                .padding(.trailing, 28)
            }
        }
        .frame(height: 100)
    }

    private var shutterButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(Color.white)
                    .frame(width: 62, height: 62)
            }
        }
        .disabled(viewModel.uiState != .ready || viewModel.isCapturing)
        .opacity(viewModel.uiState == .ready ? 1 : 0.45)
        .accessibilityLabel(String(localized: "Prendre une photo"))
    }

    private var deniedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.85))
            Text(String(localized: "L’accès à la caméra est nécessaire pour photographier une pièce."))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 32)
            Button(String(localized: "Ouvrir Réglages")) {
                viewModel.openAppSettings()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        }
    }

    private var noHardwareState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.75))
            Text(String(localized: "La caméra n’est pas disponible sur cet appareil. Choisis une photo dans les récents ci‑dessous."))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 28)
        }
    }

    private func capturePhoto() {
        viewModel.capturePhoto { data in
            deliver(data: data)
        }
    }

    private func selectFromLibrary(_ asset: PHAsset) {
        RecentPhotosLibraryModel.loadImageData(for: asset) { data in
            deliver(data: data)
        }
    }

    private func deliver(data: Data?) {
        guard let data, let name = ImagePersistenceService.shared.saveImage(data) else { return }
        Task { @MainActor in
            onCapturedImage(SharedImportPayload(imageFileName: name))
        }
    }
}
