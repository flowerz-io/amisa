//
//  SharedSessionResumeFailedView.swift
//  Balibu
//

import SwiftUI

struct SharedSessionResumeFailedView: View {
    let message: String
    @EnvironmentObject private var router: Router

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button(String(localized: "OK")) {
                router.dismissCurrentRoute()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.backgroundColor)
    }
}
