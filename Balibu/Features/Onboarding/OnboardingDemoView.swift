//
//  OnboardingDemoView.swift
//  Balibu
//
//  Étapes 4+5 — sélection look + scan + résultats.
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
    @Namespace private var ns

    private var currentResults: [OnboardingMockResult] {
        guard let idx = model.selectedDemoIndex, idx < model.demoItems.count else {
            return model.demoItems.first?.category.results ?? []
        }
        return model.demoItems[idx].category.results
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
            Spacer(minLength: 120)

            VStack(spacing: 8) {
                Text("Choisis un look\nà analyser")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Balibu va retrouver les pièces similaires pour toi.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .padding(.horizontal, 28)

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
                        .delay(Double(item.id) * 0.07 + 0.2),
                    value: appeared
                )
            }
        }
    }

    // MARK: - Phase 2: Scanning

    private var scanContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 120)

            if let idx = model.selectedDemoIndex, idx < model.demoItems.count {
                ScanAnimationCard(item: model.demoItems[idx])
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
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 6) {
                Text("+240 annonces similaires\ntrouvées ✓")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Les meilleures pièces sur Vinted, Grailed, eBay et Depop.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 120)
            .padding(.bottom, 16)

            // Scrollable 2-column grid
            ScrollView(showsIndicators: false) {
                let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(currentResults) { result in
                        ResultCard(result: result)
                            .opacity(1)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.76)
                                    .delay(Double(result.id % 8) * 0.04),
                                value: phase
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // space for pinned CTA
            }

            // Pinned CTA
            analyzeButton
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
                .background(
                    LinearGradient(
                        colors: [Color(uiColor: .systemGroupedBackground).opacity(0), Color(uiColor: .systemGroupedBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
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
    }

    // MARK: - Actions

    private func selectItem(_ item: OnboardingDemoItem) {
        model.selectedDemoIndex = item.id
        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
            phase = .scanning
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                phase = .results
            }
        }
    }
}

// MARK: - Demo look card (clean — image only, no emojis)

private struct DemoLookCard: View {
    let item: OnboardingDemoItem
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Look asset image with gradient fallback
                OnboardingAssetImage(
                    name: item.imageName,
                    fallbackColors: item.gradientColors
                )
                .frame(height: 170)
                .clipped()

                // Bottom scrim
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text(item.focusPiece)
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

// MARK: - Scan animation card (uses selected look's asset)

private struct ScanAnimationCard: View {
    let item: OnboardingDemoItem

    @State private var scanX: CGFloat = -130
    @State private var cornersAppeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var focusVisible = false

    var body: some View {
        ZStack {
            // Selected look photo (same as the card)
            OnboardingAssetImage(
                name: item.imageName,
                fallbackColors: item.gradientColors
            )
            .clipped()

            // Bottom scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.40)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Scan overlay
            GeometryReader { geo in
                // Vertical scan line
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

            // Focus label mid-scan
            VStack {
                Spacer()
                if focusVisible {
                    HStack(spacing: 5) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 11, weight: .semibold))
                        Text(item.focusPiece)
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

// MARK: - Result card (2-column grid)

private struct ResultCard: View {
    let result: OnboardingMockResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product image
            OnboardingAssetImage(
                name: result.imageName,
                fallbackColors: [Color(red: 0.18, green: 0.18, blue: 0.22), Color(red: 0.24, green: 0.22, blue: 0.28)]
            )
            .frame(height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Info block
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

                    // Marketplace badge
                    HStack(spacing: 3) {
                        Circle()
                            .fill(result.sourceColor)
                            .frame(width: 5, height: 5)
                        Text(result.source)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}
