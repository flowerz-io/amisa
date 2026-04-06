//
//  ShareExtensionPrimaryActionButton.swift
//  BalibuShareExtension
//
//  Même intention que `PrimaryActionButton` (app native).
//

import SwiftUI

struct ShareExtensionPrimaryActionButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
    }
}
