import SwiftUI
import UIKit

extension UIView {
    /// Remonte la hiérarchie jusqu’à trouver un ancêtre du type demandé.
    func findSuperview<T: UIView>(of type: T.Type) -> T? {
        var view = superview
        while let current = view {
            if let typed = current as? T { return typed }
            view = current.superview
        }
        return nil
    }
}

/// Lit `contentOffset` + état de traction sur le `UIScrollView` parent (SwiftUI `ScrollView`).
struct ScrollViewOffsetReader: UIViewRepresentable {
    let onOffsetChange: (CGFloat, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear

        DispatchQueue.main.async {
            context.coordinator.tryAttach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.tryAttach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let onOffsetChange: (CGFloat, Bool) -> Void
        weak var scrollView: UIScrollView?
        weak var originalDelegate: UIScrollViewDelegate?

        init(onOffsetChange: @escaping (CGFloat, Bool) -> Void) {
            self.onOffsetChange = onOffsetChange
        }

        func tryAttach(from view: UIView) {
            guard let scrollView = view.findSuperview(of: UIScrollView.self) else { return }
            attach(to: scrollView)
        }

        func attach(to scrollView: UIScrollView) {
            guard self.scrollView !== scrollView else {
                emit(scrollView)
                return
            }

            detach()

            self.scrollView = scrollView
            originalDelegate = scrollView.delegate
            scrollView.delegate = self
            scrollView.alwaysBounceVertical = true

            emit(scrollView)
        }

        func detach() {
            guard let scrollView else { return }
            if scrollView.delegate === self {
                scrollView.delegate = originalDelegate
            }
            self.scrollView = nil
            originalDelegate = nil
        }

        private func emit(_ scrollView: UIScrollView) {
            let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            let dragging = scrollView.isDragging || scrollView.isTracking
            onOffsetChange(y, dragging)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            emit(scrollView)
            originalDelegate?.scrollViewDidScroll?(scrollView)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            emit(scrollView)
            originalDelegate?.scrollViewWillBeginDragging?(scrollView)
        }

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            emit(scrollView)
            originalDelegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            onOffsetChange(y, false)
            originalDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            emit(scrollView)
            originalDelegate?.scrollViewDidEndDecelerating?(scrollView)
        }

        func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
            emit(scrollView)
            originalDelegate?.scrollViewDidScrollToTop?(scrollView)
        }

        func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
            originalDelegate?.scrollViewShouldScrollToTop?(scrollView) ?? true
        }
    }
}
