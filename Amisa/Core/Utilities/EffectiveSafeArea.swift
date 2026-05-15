import SwiftUI
import UIKit

/// Safe area supérieure fiable sous SwiftUI + `GeometryReader` avec `.ignoresSafeArea(edges: .top)`.
enum EffectiveSafeArea {
    static func topInset(proxy: GeometryProxy) -> CGFloat {
        let fromProxy = proxy.safeAreaInsets.top
        /// Évite un « double » safe area quand le proxy est déjà correct : `max` avec la fenêtre descendait trop le chrome flottant.
        if fromProxy > 0.5 { return fromProxy }
        return windowSafeAreaTopInset()
    }

    private static func windowSafeAreaTopInset() -> CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return 59
        }
        let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        let top = window?.safeAreaInsets.top ?? 0
        return top > 0 ? top : 59
    }
}
