//
//  InitializationErrorView.swift
//  SoraPlanner
//
//  View displayed when app fails to initialize API service
//

import SwiftUI

struct InitializationErrorView: View {
    let error: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Initialization Failed")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let error = error {
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Text("Tip: Make sure you've added your OpenAI API key in the Settings tab")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    InitializationErrorView(
        error: "No API key configured. Please add your OpenAI API key in the Settings tab.",
        onRetry: {}
    )
}
