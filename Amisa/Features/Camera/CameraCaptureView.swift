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

            bottomPanelVisualOverlay
                .allowsHitTesting(false)
                .zIndex(1)

            bottomPanelInteractive
                .zIndex(100)
        }
        .overlay(alignment: .top) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
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

    // MARK: - Panel bas (fond décoratif)

    private var bottomPanelVisualOverlay: some View {
        Color.black.opacity(bottomPanelOpacity)
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Panel bas (contrôles + récents, tappable)

    private var bottomPanelInteractive: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                bottomControls
            }
            .zIndex(0)

            VStack(spacing: 0) {
                if viewModel.uiState == .ready {
                    zoomBadge
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                }

                Text(String(localized: "Récents"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)

                RecentPhotosStrip(
                    library: recentLibrary,
                    onSelectAsset: { asset in
                        await handleRecentAssetSelection(asset)
                    },
                    onOpenLibrary: { showLibraryPicker = true }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .zIndex(100)

                Color.clear
                    .frame(height: bottomControlsHeight)
                    .allowsHitTesting(false)
            }
            .zIndex(100)
            .allowsHitTesting(true)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private var bottomControlsHeight: CGFloat { 100 }

    // MARK: - Preview

    private var previewStack: some View {
        ZStack {
            Color.black
                .allowsHitTesting(false)
            switch viewModel.uiState {
            case .ready:
                CameraPreviewView(
                    session: viewModel.sessionController.session,
                    isMirrored: viewModel.cameraPosition == .front
                )
                .allowsHitTesting(false)
            case .loading:
                ProgressView().tint(.white).scaleEffect(1.2)
                    .allowsHitTesting(false)
            case .denied:
                deniedState
                    .allowsHitTesting(false)
            case .noHardware:
                noHardwareState
                    .allowsHitTesting(false)
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
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .accessibilityLabel(String(localized: "Ouvrir la photothèque"))

            Spacer(minLength: 0)

            shutterButton

            Spacer(minLength: 0)

            Button { viewModel.flipCamera() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .disabled(viewModel.uiState != .ready)
            .opacity(viewModel.uiState == .ready ? 1 : 0.4)
            .accessibilityLabel(String(localized: "Changer de caméra"))
        }
        .padding(.horizontal, 28)
        .frame(height: bottomControlsHeight)
        .allowsHitTesting(true)
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
        .frame(width: 74, height: 74)
        .contentShape(Circle())
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

    @MainActor
    private func handleRecentAssetSelection(_ asset: PHAsset) async {
        print("[RECENTS] start loading image:", asset.localIdentifier)
        guard !isProcessingPick else { return }
        isProcessingPick = true

        guard let image = await RecentPhotosLibraryModel.loadUIImage(from: asset) else {
            print("[RECENTS] failed to load UIImage")
            isProcessingPick = false
            pickErrorMessage = String(localized: "Impossible de charger cette photo depuis ta bibliothèque.")
            return
        }

        print("[RECENTS] UIImage loaded:", image.size)
        applyPickedImage(image)
        isProcessingPick = false
    }

    /// Pipeline commun galerie / récents / capture.
    private func applyPickedImage(_ image: UIImage) {
        showLibraryPicker = false
        print("[RECENTS] calling handlePickedImage — same flow as gallery")
        if !PickedImageAnalysisHandler.handlePickedImage(image, router: router) {
            pickErrorMessage = String(localized: "Impossible d’enregistrer cette photo. Réessaie ou choisis une autre image.")
        }
    }

    private func handlePickedImage(_ image: UIImage) {
        guard !isProcessingPick else { return }
        isProcessingPick = true
        defer { isProcessingPick = false }
        applyPickedImage(image)
    }

    private func capturePhoto() {
        viewModel.capturePhoto { data in
            guard let data, let image = UIImage(data: data) else { return }
            Task { @MainActor in
                handlePickedImage(image)
            }
        }
    }
}
