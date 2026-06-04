//
//  CameraCaptureView.swift
//  Balibu
//
//  Écran plein écran : prévisualisation, réglages, bande photothèque, obturateur + pellicule.
//

import AVFoundation
import Photos
import SwiftUI

struct CameraCaptureView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var recentLibrary = RecentPhotosLibraryModel()

    @Environment(\.dismiss) private var dismiss

    @State private var showLibraryPicker = false
    @State private var isProcessingPick = false
    @State private var pickErrorMessage: String?

    private let bottomPanelOpacity: CGFloat = 0.38

    var body: some View {
        ZStack(alignment: .bottom) {
            previewStack
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(0)

            VStack {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .zIndex(2)

            bottomPanel
                .zIndex(3)
        }
        .background(Color.black)
        .onAppear {
            viewModel.onAppear()
            recentLibrary.requestAccessIfNeeded()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $showLibraryPicker) {
            PhotoLibraryPicker(
                onImagePicked: { image in
                    showLibraryPicker = false
                    handlePickedImage(image)
                },
                onCancel: {
                    showLibraryPicker = false
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            String(localized: "Photo indisponible"),
            isPresented: Binding(
                get: { pickErrorMessage != nil },
                set: { if !$0 { pickErrorMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(pickErrorMessage ?? "")
        }
    }

    // MARK: - Panel bas

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

            RecentPhotosStrip(
                library: recentLibrary,
                onSelectAsset: { selectFromLibrary($0) },
                onOpenLibrary: { showLibraryPicker = true }
            )
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
        .contentShape(Rectangle())
    }

    // MARK: - Preview

    private var previewStack: some View {
        ZStack {
            Color.black
            switch viewModel.uiState {
            case .ready:
                CameraPreviewView(
                    session: viewModel.sessionController.session,
                    isMirrored: viewModel.cameraPosition == .front
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in viewModel.pinchChanged(scale: value) }
                        .onEnded { _ in viewModel.pinchEnded() }
                )
            case .loading:
                ProgressView().tint(.white).scaleEffect(1.2)
            case .denied:
                deniedState
            case .noHardware:
                noHardwareState
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
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
                Button { viewModel.cycleFlash() } label: {
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
        .allowsHitTesting(true)
    }

    // MARK: - Zoom

    private var zoomBadge: some View {
        Text("\(String(format: "%.1f", viewModel.zoomDisplay))×")
            .font(.system(.subheadline, design: .rounded).weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Contrôles bas

    private var bottomControls: some View {
        HStack(spacing: 0) {
            Button {
                showLibraryPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(String(localized: "Ouvrir la photothèque"))

            shutterButton
                .frame(maxWidth: .infinity)

            Button { viewModel.flipCamera() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .disabled(viewModel.uiState != .ready)
            .opacity(viewModel.uiState == .ready ? 1 : 0.4)
            .accessibilityLabel(String(localized: "Changer de caméra"))
            .frame(maxWidth: .infinity)
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
            Text(String(localized: "L'accès à la caméra est nécessaire pour photographier une pièce."))
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
            Text(String(localized: "La caméra n'est pas disponible sur cet appareil. Choisis une photo dans les récents ci‑dessous."))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 28)
        }
    }

    // MARK: - Actions

    private func handlePickedImage(_ image: UIImage) {
        guard !isProcessingPick else { return }
        isProcessingPick = true
        defer { isProcessingPick = false }

        if !PickedImageAnalysisHandler.handlePickedImage(image, router: router) {
            pickErrorMessage = String(localized: "Impossible d’enregistrer cette photo. Réessaie ou choisis une autre image.")
        }
    }

    private func capturePhoto() {
        viewModel.capturePhoto { data in
            guard let data, let image = UIImage(data: data) else { return }
            Task { @MainActor in
                handlePickedImage(image)
            }
        }
    }

    private func selectFromLibrary(_ asset: PHAsset) {
        guard !isProcessingPick else { return }
        isProcessingPick = true
        RecentPhotosLibraryModel.loadFullImage(for: asset) { image in
            Task { @MainActor in
                defer { isProcessingPick = false }
                guard let image else {
                    pickErrorMessage = String(localized: "Impossible de charger cette photo depuis ta bibliothèque.")
                    return
                }
                handlePickedImage(image)
            }
        }
    }
}
