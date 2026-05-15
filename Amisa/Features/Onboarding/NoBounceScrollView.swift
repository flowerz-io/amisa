//
//  NoBounceScrollView.swift
//  Balibu
//
//  Wrapper UIKit permettant de désactiver dynamiquement le bounce
//  d'un ScrollView SwiftUI via UIScrollView.bounces.
//

import SwiftUI

struct NoBounceScrollView<Content: View>: UIViewRepresentable {

    var bounces: Bool
    let content: () -> Content

    init(bounces: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.bounces = bounces
        self.content = content
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content())
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.bounces = bounces
        scrollView.alwaysBounceVertical = bounces
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let hostView = context.coordinator.hostingController.view!
        hostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.backgroundColor = .clear
        scrollView.addSubview(hostView)

        // contentLayoutGuide pour la taille du contenu scrollable,
        // frameLayoutGuide pour fixer la largeur au frame du scrollView.
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.bounces = bounces
        uiView.alwaysBounceVertical = bounces
        context.coordinator.hostingController.rootView = content()
    }

    // MARK: - Coordinator class

    final class Coordinator {
        let hostingController: UIHostingController<Content>

        init(content: Content) {
            hostingController = UIHostingController(rootView: content)
            hostingController.view.backgroundColor = .clear
        }
    }
}
