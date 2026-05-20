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
    /// Distance en points entre le bord bas du contenu et le bord bas visible (plus petit = plus bas dans la scroll).
    var onDistanceFromContentBottom: ((CGFloat) -> Void)?
    let content: () -> Content

    init(
        bounces: Bool,
        onDistanceFromContentBottom: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.bounces = bounces
        self.onDistanceFromContentBottom = onDistanceFromContentBottom
        self.content = content
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content(), onDistanceFromContentBottom: onDistanceFromContentBottom)
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.bounces = bounces
        scrollView.alwaysBounceVertical = bounces
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let hostView = context.coordinator.hostingController.view!
        hostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.backgroundColor = .clear
        scrollView.addSubview(hostView)

        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.bounces = bounces
        uiView.alwaysBounceVertical = bounces
        context.coordinator.onDistanceFromContentBottom = onDistanceFromContentBottom
        context.coordinator.hostingController.rootView = content()
        DispatchQueue.main.async {
            context.coordinator.emitDistanceIfNeeded()
        }
    }

    // MARK: - Coordinator class

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        weak var scrollView: UIScrollView?
        var onDistanceFromContentBottom: ((CGFloat) -> Void)?

        init(content: Content, onDistanceFromContentBottom: ((CGFloat) -> Void)?) {
            self.hostingController = UIHostingController(rootView: content)
            self.onDistanceFromContentBottom = onDistanceFromContentBottom
            super.init()
            hostingController.view.backgroundColor = .clear
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            emitDistance(from: scrollView)
        }

        func emitDistanceIfNeeded() {
            guard let sv = scrollView else { return }
            emitDistance(from: sv)
        }

        private func emitDistance(from scrollView: UIScrollView) {
            guard let onDistanceFromContentBottom else { return }
            let inset = scrollView.adjustedContentInset
            let visibleBottomY = scrollView.contentOffset.y + scrollView.bounds.height - inset.bottom
            let contentBottom = scrollView.contentSize.height
            onDistanceFromContentBottom(contentBottom - visibleBottomY)
        }
    }
}
