//
//  OnboardingDemoView.swift
//  Balibu
//
//  look → faux analyse → faux résultats. Aucune navigation : tout passe par le modèle.

import SwiftUI

// MARK: - Fausse analyse

struct OnboardingFakeAnalyzingView: View {
    @ObservedObject var model: OnboardingFlowModel

    private var selectedLook: DemoLook? {
        model.selectedLook
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                if let look = selectedLook {
                    ScanAnimationCard(item: look)
                        .frame(width: 260, height: 300)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .padding(.top, 40)
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
        .ignoresSafeArea()
    }
}

// MARK: - Faux résultats

struct OnboardingFakeResultsView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @State private var showCTA = false

    private var selectedLook: DemoLook? {
        model.selectedLook
    }

    private var analyzedLookAssetName: String {
        selectedLook?.imageName ?? ""
    }

    private var currentResults: [OnboardingFakeResultData] {
        guard let look = selectedLook else { return [] }
        return OnboardingMockData.fakeResults(for: look.id)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if selectedLook == nil {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(String(localized: "Choix du look manquant"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ZStack {
                    resultsScrollContent
                    analyzeButtonSticky
                        .opacity(showCTA ? 1 : 0)
                        .offset(y: showCTA ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showCTA)
                        .allowsHitTesting(showCTA)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            showCTA = selectedLook != nil
            if selectedLook != nil {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.06)) {
                    appeared = true
                }
            }
        }
    }

    private var resultsScrollContent: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 10) {
                demoResultsLightHeader
                    .padding(.top, 6)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(currentResults) { result in
                        ResultCard(result: result)
                    }
                }

                Color.clear.frame(height: 112)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
    }

    private var demoResultsLightHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            OnboardingAssetImageView(imageName: analyzedLookAssetName, contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }

            Text(String(localized: "Annonces similaires trouvées"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var analyzeButtonSticky: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground).opacity(0),
                    Color(uiColor: .systemGroupedBackground).opacity(0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 48)

            analyzeButton
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private var analyzeButton: some View {
        Button {
            model.next()
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
            .background(BrandColors.primaryLinearGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: BrandColors.secondaryOrange.opacity(0.35), radius: 14, x: 0, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Scan animation

private struct ScanAnimationCard: View {
    let item: DemoLook

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

// MARK: - Carte résultat

private struct ResultCard: View {
    let result: OnboardingFakeResultData

    private let resultProviderLogoSize: CGFloat = 18

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
                        .foregroundStyle(BrandColors.primary)

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
