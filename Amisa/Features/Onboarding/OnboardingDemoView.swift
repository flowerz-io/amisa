//
//  OnboardingDemoView.swift
//  Balibu
//
//  Étapes 4+5 — sélection look + scan + résultats.
//  Data : OnboardingMockData.lookOptions / fakeResults(for:)
//

import SwiftUI

// MARK: - Demo phase

private enum DemoPhase {
    case picking
    case scanning
    case results
}

// MARK: - Main view

struct OnboardingDemoView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var phase: DemoPhase = .picking
    @State private var appeared = false
    @State private var showCTA = false
    @State private var ctaPulse = false

    private var selectedLook: OnboardingLookOptionData? {
        guard let id = model.selectedLookId else { return nil }
        return OnboardingMockData.lookOptions.first { $0.id == id }
    }

    private var currentResults: [OnboardingFakeResultData] {
        let lookId = model.selectedLookId ?? OnboardingMockData.lookOptions.first?.id ?? "leather"
        return OnboardingMockData.fakeResults(for: lookId)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            switch phase {
            case .picking:
                pickerContent
                    .transition(.opacity)
            case .scanning:
                scanContent
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal:   .opacity
                    ))
            case .results:
                resultsContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .opacity
                    ))
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.52, dampingFraction: 0.84), value: phase)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Phase 1: Picking

    private var pickerContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 195) // 30% de plus, identique sur toutes les pages

            OnboardingStepHeader(
                currentStep: 3,
                title: "Choisis un look\nà analyser",
                subtitle: "Amisa va retrouver les pièces similaires pour toi."
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer(minLength: 28)

            lookGrid
                .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var lookGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.demoItems) { item in
                DemoLookCard(item: item) {
                    selectItem(item)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.76)
                        .delay(Double(model.demoItems.firstIndex(where: { $0.id == item.id }) ?? 0) * 0.07 + 0.2),
                    value: appeared
                )
            }
        }
    }

    // MARK: - Phase 2: Scanning

    private var scanContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 195)

            if let look = selectedLook {
                ScanAnimationCard(item: look)
                    .frame(width: 260, height: 300)
            }

            VStack(spacing: 6) {
                Text("Analyse en cours…")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Identification de la pièce principale")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            Spacer()
        }
    }

    // MARK: - Phase 3: Results

    private var resultsContent: some View {
        // GeometryReader pour lire safeAreaInsets et synchroniser la position du header
        // avec la barre de progression rendue par OnboardingRootView (safeAreaTop + 10).
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            // Progress bar bottom ≈ safeTop + 10 (padding) + 4 (barre height)
            let progressBarBottom = safeTop + 14
            // Texte compact sous la progress bar (aligné avec OnboardingRootView : safeTop + 10 + barre 4 pt)
            let headerTextPaddingTop = progressBarBottom + 18
            let headerHeight = max(132, headerTextPaddingTop + 52)

            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            // Trigger CTA : premier item de l'avant-dernière ligne (grille 2 col → -4)
            let penultimateTriggerIndex = max(currentResults.count - 4, 0)

            ZStack(alignment: .top) {
                // Grille scrollable — padding top = headerHeight → première carte sous le header.
                NoBounceScrollView(bounces: !showCTA) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(currentResults) { result in
                            ResultCard(result: result)
                                .onAppear {
                                    guard !showCTA else { return }
                                    if let idx = currentResults.firstIndex(where: { $0.id == result.id }),
                                       idx == penultimateTriggerIndex {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                            showCTA = true
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, headerHeight)
                    .padding(.bottom, 40)
                }

                // Header sticky — blur iOS + couche sombre ~50%.
                Text("240 annonces similaires trouvées sur ✓")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, headerTextPaddingTop)
                    .padding(.bottom, 6)
                    .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: headerHeight, alignment: .top)
                .background(
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.black.opacity(0.50)
                    }
                    .ignoresSafeArea(edges: .top)
                )
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                if showCTA {
                    ctaOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - CTA overlay (apparaît après scroll)

    private var ctaOverlay: some View {
        VStack(spacing: 0) {
            // Gradient fondu transparent → fond
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground).opacity(0),
                    Color(uiColor: .systemGroupedBackground).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            .allowsHitTesting(false)

            // Bouton sur fond mat
            analyzeButton
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 36)
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private var analyzeButton: some View {
        Button {
            model.advance(to: .paywall)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                Text("Analyser avec ma propre photo")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
        .scaleEffect(ctaPulse ? 1.035 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                ctaPulse = true
            }
        }
    }

    // MARK: - Actions

    private func selectItem(_ item: OnboardingLookOptionData) {
        showCTA = false                    // reset CTA pour la prochaine session résultats
        model.isDemoInResultsPhase = false // reset barre de progression → étape 3
        model.selectedLookId = item.id
        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
            phase = .scanning
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                phase = .results
                model.isDemoInResultsPhase = true  // → barre passe à l'étape 4
            }
        }
    }
}

// MARK: - Demo look card

private struct DemoLookCard: View {
    let item: OnboardingLookOptionData
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                OnboardingAssetImageView(imageName: item.imageName)
                    .frame(height: 170)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(10)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded   { _ in isPressed = false }
        )
    }
}

// MARK: - Scan animation card
// Utilise item.scanLabel (champ indépendant de subtitle)

private struct ScanAnimationCard: View {
    let item: OnboardingLookOptionData

    @State private var scanX: CGFloat = -130
    @State private var cornersAppeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var focusVisible = false

    var body: some View {
        ZStack {
            OnboardingAssetImageView(imageName: item.imageName)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.40)],
                startPoint: .center,
                endPoint: .bottom
            )

            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.accentColor.opacity(0.90), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .blur(radius: 2)
                    .offset(x: geo.size.width / 2 + scanX)

                ScanCorners(visible: cornersAppeared)
                    .frame(width: geo.size.width, height: geo.size.height)
            }

            VStack {
                Spacer()
                if focusVisible {
                    // Pastille avec scanLabel (pas subtitle)
                    HStack(spacing: 5) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 11, weight: .semibold))
                        Text(item.scanLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.88))
                    .clipShape(Capsule())
                    .padding(.bottom, 14)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .scaleEffect(pulseScale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2)) {
                cornersAppeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3)) {
                scanX = 130
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.015
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.2)) {
                focusVisible = true
            }
        }
    }
}

// MARK: - Scan corners

private struct ScanCorners: View {
    let visible: Bool
    private let size: CGFloat = 24
    private let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            cornerPath(corner: .topLeft)
            cornerPath(corner: .topRight)
            cornerPath(corner: .bottomLeft)
            cornerPath(corner: .bottomRight)
        }
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.75)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: visible)
    }

    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    private func cornerPath(corner: Corner) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let m: CGFloat = 12

            Path { path in
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: m, y: m + size))
                    path.addLine(to: CGPoint(x: m, y: m))
                    path.addLine(to: CGPoint(x: m + size, y: m))
                case .topRight:
                    path.move(to: CGPoint(x: w - m - size, y: m))
                    path.addLine(to: CGPoint(x: w - m, y: m))
                    path.addLine(to: CGPoint(x: w - m, y: m + size))
                case .bottomLeft:
                    path.move(to: CGPoint(x: m, y: h - m - size))
                    path.addLine(to: CGPoint(x: m, y: h - m))
                    path.addLine(to: CGPoint(x: m + size, y: h - m))
                case .bottomRight:
                    path.move(to: CGPoint(x: w - m - size, y: h - m))
                    path.addLine(to: CGPoint(x: w - m, y: h - m))
                    path.addLine(to: CGPoint(x: w - m, y: h - m - size))
                }
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Result card (non cliquable)

private struct ResultCard: View {
    let result: OnboardingFakeResultData

    private let resultProviderLogoSize: CGFloat = 18  // 12 × 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingAssetImageView(imageName: result.imageName)
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.brand)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(result.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 4) {
                    Text(result.price)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    if let size = result.size {
                        Text(size)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                    }

                    Spacer()
                    providerLogo
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var providerLogo: some View {
        if UIImage(named: result.providerLogoName) != nil {
            Image(result.providerLogoName)
                .resizable()
                .scaledToFit()
                .frame(height: resultProviderLogoSize)
                .opacity(0.72)
        } else {
            Text(result.providerLogoName.replacingOccurrences(of: "provider_", with: ""))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
