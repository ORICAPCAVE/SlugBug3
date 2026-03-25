/*
 AboutView.swift
 SlugBug

 Informational view describing the SlugBug game and credits.

 Layout improvements:
 - GeometryReader used to dynamically adjust layout on iPad landscape.
 - Vertical drop applied in landscape (~30%) to visually center content
   over the background image.
 - Horizontal shift (~10%) applied to balance layout against background art.
 - ScrollView retained so content remains accessible on smaller screens.

 Layout strategy:
 - Use transparent spacer frames inside ScrollView instead of offsets
   to avoid clipping content off-screen.
 - Avoid Spacer inside ScrollView to prevent layout compression issues.

 Visual design:
 - Semi-transparent dark card improves readability against background image.
 - Highlight sections ("How it works", "Credits") using yellow headings.

 Implementation assistance:
 - ScrollView positioning and GeometryReader layout techniques were
   developed with assistance from ChatGPT (OpenAI).
 - Final layout tuning by Kevin Leckenby.

 Last refined: 2026
*/

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private func onBack() {
        dismiss()
    }
    var body: some View {
        ZStack {
            Image("slugbug1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                let deviceLandscape =
                    (UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first(where: { $0.activationState == .foregroundActive })?
                        .interfaceOrientation.isLandscape) ?? false

                let topDrop = deviceLandscape ? geo.size.height * 0.30 : 30
                let rightShift = deviceLandscape ? geo.size.width * 0.10 : 0
                let availableWidth = max(0, geo.size.width - 32)
                let boxWidth = min(600, availableWidth)
                ScrollView {
                    // ✅ vertical drop that remains scrollable
                    Color.clear.frame(height: topDrop)

                    // ✅ horizontal shift that won't clip
                    VStack(spacing: 14) {
                        Text("About Slug Bug")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        Text("Version 3")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("How it works")
                                .font(.headline)
                                .foregroundColor(.yellow)

                            Text("Spot a Volkswagen Beetle, call “Buggy!”, and track your games, scores, and photos.")
                                .foregroundColor(.white.opacity(0.9))

                            Text("Credits")
                                .font(.headline)
                                .foregroundColor(.yellow)

                            Text("Created by Leckenby and Associates LLC.")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(.black.opacity(0.45))
                        .cornerRadius(16)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .frame(width: boxWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(x: rightShift)

                    // ✅ bottom breathing room so nothing gets hidden
                    Color.clear.frame(height: 24)
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)

        .toolbar {
            // ✅ Back button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.white)
                }
            }

            // ✅ Center title
            ToolbarItem(placement: .principal) {
                Text("About")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
    }
}
