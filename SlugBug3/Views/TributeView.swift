// TributeView
// Landscape layout refined with ChatGPT assistance on 2026-01-27.
// Implemented a fixed reading container for ScrollView so memorial text
// is immediately visible in landscape on all devices without user dragging.
// – Kevin Leckenby

import SwiftUI

struct TributeView: View {
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

            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                let topPad = isLandscape ? geo.size.height * 0.22 : geo.size.height * 0.32

                ScrollView {
                    VStack(spacing: 24) {
                        Text("In Loving Memory of")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Gracie Annette Leckenby")
                            .font(.title.weight(.semibold))
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)

                        Text("""
Annette was an avid Buggy player.
While out on family trips, or at home outside, or watching her favorite TV shows, she would shout “Buggy!” announcing a friendly competition.

She was really good at it!
And she would usually win the games she announced.
""")
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, topPad)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Tribute")
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
                Text("Tribute")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
