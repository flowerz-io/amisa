import SwiftUI

/// Bandeau recherche / refresh inséré dans le flux du `ScrollView` (effet accordéon).
struct PullSearchAccordion: View {
    let pullDistance: CGFloat
    let isPinned: Bool
    let isRefreshing: Bool
    let horizontalPadding: CGFloat
    @Binding var searchText: String
    var searchFocused: FocusState<Bool>.Binding
    var onSubmitSearch: (String) -> Void
    var onCameraTap: () -> Void

    private let revealStart: CGFloat = 8
    private let revealEnd: CGFloat = 72
    private let refreshTrigger: CGFloat = 125
    /// Hauteur zone (~ −10 % vs 76).
    private let maxHeight: CGFloat = 68
    private let barHeight: CGFloat = 49

    private var revealProgress: CGFloat {
        min(max((pullDistance - revealStart) / (revealEnd - revealStart), 0), 1)
    }

    private var refreshProgress: CGFloat {
        min(max((pullDistance - revealEnd) / (refreshTrigger - revealEnd), 0), 1)
    }

    private var effectiveProgress: CGFloat {
        isPinned || isRefreshing ? 1 : revealProgress
    }

    private var accordionHeight: CGFloat {
        maxHeight * effectiveProgress
    }

    /// Pendant pull refresh : pas de champ éditable (état message / spinner).
    private var showsEditableSearchField: Bool {
        !isRefreshing && refreshProgress <= 0.75
    }

    var body: some View {
        VStack(spacing: 0) {
            if effectiveProgress > 0.01 || isRefreshing {
                Group {
                    if showsEditableSearchField {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField(
                                String(localized: "Rechercher une pièce…"),
                                text: $searchText
                            )
                            .focused(searchFocused)
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .font(.system(size: 17, weight: .semibold))
                            .onSubmit {
                                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !q.isEmpty else { return }
                                onSubmitSearch(q)
                            }

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 17))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: onCameraTap) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel(String(localized: "Analyser une photo"))
                        }
                        .padding(.horizontal, 18)
                        .frame(height: barHeight)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                    } else {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.accentColor)

                            Text(
                                isRefreshing
                                    ? String(localized: "Actualisation…")
                                    : String(localized: "Relâche pour actualiser")
                            )
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: barHeight)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .opacity(isRefreshing ? 1 : effectiveProgress)
                .scaleEffect(0.94 + 0.06 * effectiveProgress)
                .offset(y: isRefreshing ? 0 : -10 * (1 - effectiveProgress))
            }
        }
        .frame(height: accordionHeight)
        .clipped()
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: effectiveProgress)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isRefreshing)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: refreshProgress)
        .accessibilityElement(children: .contain)
    }
}
