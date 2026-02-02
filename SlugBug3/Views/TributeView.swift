// TributeView
// Landscape layout refined with ChatGPT assistance on 2026-01-27.
// Implemented a fixed reading container for ScrollView so memorial text
// is immediately visible in landscape on all devices without user dragging.
// – Kevin Leckenby

import SwiftUI

struct TributeView: View {

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

                if isLandscape {

                    // -------- LANDSCAPE LAYOUT --------
                    let windowWidth  = min(geo.size.width * 0.75, 700)
                    let windowHeight = geo.size.height * 0.70

                    VStack {
                        Spacer().frame(height: geo.size.height * 0.10)   // 👈 push container down

                        ScrollView {
                            tributeContent
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(width: windowWidth, height: windowHeight)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(20)

                        Spacer()
                    }

                } else {

                    // -------- PORTRAIT LAYOUT --------
                    ScrollView {
                        tributeContent
                            .padding(.top, geo.size.height * 0.22)   // your existing portrait drop
                            .padding(.horizontal, 24)
                            .padding(.bottom, 80)
                    }
                }
            }
        }
    }

    // Extracted content so both layouts share it
    private var tributeContent: some View {
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
        .padding(.horizontal, 24)
    }
}
