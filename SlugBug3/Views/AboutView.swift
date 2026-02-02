//
//  AboutView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 1/22/26.
//


import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            Image("slugbug1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
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

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 30)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
