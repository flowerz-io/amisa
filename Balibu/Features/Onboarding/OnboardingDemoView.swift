//
//  OnboardingDemoView.swift
//  Balibu
//
//  Étapes 4+5 — sélection d'un look + animation de scan premium.
//

import SwiftUI

// MARK: - Demo phase

private enum DemoPhase {
    case picking    // grille de looks
    case scanning   // animation scan sur le look sélectionné
    case results    // cartes marketplace mock
}

// MARK: - Main view

struct OnboardingDemoView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var phase: DemoPhase = .picking
    @State private var appeared = false
    @Namespace private var ns

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
            Spacer(minLength: 80)

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

            Spacer(minLength: 32)

            lookGrid
                .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var lookGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.demoItems) { item in
                DemoLookCard(item: item, namespace: ns) {
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
            Spacer(minLength: 80)

            if let selected = model.selectedDemoIndex,
               selected < model.demoItems.count {
                let item = model.demoItems[selected]

                ScanAnimationCard(item: item, namespace: ns)
                    .frame(width: 260, height: 300)
                    .padding(.horizontal, 40)
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
            Spacer(minLength: 80)

            VStack(spacing: 8) {
                Text("+240 annonces similaires\ntrouvées ✓")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Les meilleures pièces repérées sur Vinted, Grailed, eBay et Depop.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 24)

            mockResultsCarousel

            Spacer()

            analyzeButton
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
        }
    }

    private var mockResultsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(OnboardingMockListing.samples.enumerated()), id: \.element.id) { idx, listing in
                    MockResultCard(listing: listing)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.76).delay(Double(idx) * 0.08),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
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

// MARK: - Demo look card

private struct DemoLookCard: View {
    let item: OnboardingDemoItem
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Gradient simulating a lifestyle photo
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Bottom scrim for text legibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.60)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Outfit emojis layer
                outfitEmojiLayer

                // Look info at bottom
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text(item.focusPiece)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .padding(10)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: item.gradientColors.first!.opacity(0.30), radius: 12, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false }
        )
    }

    private var outfitEmojiLayer: some View {
        ZStack(alignment: .topTrailing) {
            // Main outfit piece — centred, large
            Text(item.outfitEmojis.first ?? "👗")
                .font(.system(size: 54))
                .shadow(color: .black.opacity(0.25), radius: 6)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)

            // Secondary items pill top-right
            if item.outfitEmojis.count > 1 {
                HStack(spacing: 2) {
                    ForEach(Array(item.outfitEmojis.dropFirst().enumerated()), id: \.offset) { _, emoji in
                        Text(emoji)
                            .font(.system(size: 18))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.28))
                .clipShape(Capsule())
                .padding(8)
            }
        }
    }
}

// MARK: - Scan animation card

private struct ScanAnimationCard: View {
    let item: OnboardingDemoItem
    let namespace: Namespace.ID

    @State private var scanX: CGFloat = -130
    @State private var cornersAppeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var focusVisible = false

    var body: some View {
        ZStack {
            // Same gradient as chosen look card
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: item.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Bottom scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Main outfit emoji
            Text(item.outfitEmojis.first ?? "👗")
                .font(.system(size: 96))
                .shadow(radius: 12)

            // Scan overlay
            GeometryReader { geo in
                // Vertical scan line sweeping left → right
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

                // Scan corners
                ScanCorners(visible: cornersAppeared)
                    .frame(width: geo.size.width, height: geo.size.height)
            }

            // Focus label appears mid-scan
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
            .stroke(
                Color.accentColor,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Mock result card

private struct MockResultCard: View {
    let listing: OnboardingMockListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: listing.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 148, height: 148)

                // Marketplace badge with colored dot
                HStack(spacing: 4) {
                    Circle()
                        .fill(listing.sourceColor)
                        .frame(width: 7, height: 7)
                    Text(listing.source)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.52))
                .clipShape(Capsule())
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.brand)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(listing.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(listing.price)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    if let size = listing.size {
                        Text(size)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: 148)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}
