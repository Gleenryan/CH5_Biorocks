//
//  onBoardingView.swift
//  CH5_Biorocks
//
//  Created by Gleenryan on 12/08/26.
//

import SwiftUI

struct onBoardingView: View {
    var onStart: () -> Void = {}

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "water.waves")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 72, height: 72)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reef Monitor")
                        .font(.system(size: 52, weight: .bold, design: .rounded))

                    Text("Organize reef Sites, place hydrophones, and verify connected microphone inputs from one native macOS workspace.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Get Started", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(56)
        }
    }
}

#Preview {
    onBoardingView()
        .frame(width: 900, height: 650)
}
