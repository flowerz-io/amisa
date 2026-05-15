//
//  PrimaryActionButton.swift
//  Balibu
//
//  Bouton principal aligné sur `.borderedProminent` (même intention que la Share Extension).
//

import SwiftUI

struct PrimaryActionButton: View {
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
