//
//  PlayBugView.swift
//  SlugBug
//
//  Created by Kevin Leckenby on November 20, 2025.
//  Concept, structure, and interface behavior collaboratively developed with assistance from ChatGPT (OpenAI).
//  This view displays the live gameplay interface for detecting and counting “Bug” calls,
//  integrating speech recognition and manual controls with animated UI feedback.
//
import SwiftUI
import Speech
import AVKit

struct PlayBugView: View {
    @ObservedObject var vm: PlayBugVM

    var body: some View {
        ZStack {
            // --- Your existing content ---
            Image("slugbug1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let isLandscape = w > h
                let bottomPad = geo.safeAreaInsets.bottom + (isLandscape ? 8 : 24)
                // 1) Set counter Y (higher in landscape)
                let counterY: CGFloat = isLandscape ? h * 0.32 : h * 0.45
                // 2) Put buttons BELOW the counter, but never below the safe bottom
                    let minGap: CGFloat = isLandscape ? 90 : 120
                    let desiredButtonsY: CGFloat = counterY + minGap
                    let maxButtonsY: CGFloat = h - bottomPad - 30
                    let buttonsY: CGFloat = min(desiredButtonsY, maxButtonsY)
                
                Text("\(vm.buggyCount)")
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .kerning(-2)
                    .foregroundStyle(.red)
                    .shadow(radius: 12)
                    .position(x: w * 0.60, y: counterY)


                HStack(spacing: 16) {
                    Button { vm.toggleListening() } label: {
                        Image(systemName: vm.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 28, weight: .bold))
                            .padding(.vertical, 9).padding(.horizontal, 22)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Button { vm.increment(by: 1) } label: {
                        Label("+1 (noisy room)", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding(.vertical, 10).padding(.horizontal, 16)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Button("Reset") { vm.reset() }
                        .buttonStyle(.bordered)
                }
                .position(x: w * 0.50, y: buttonsY)

            }

            // --- REWARD OVERLAY ---
            if vm.shouldShowAward {
                RewardVideoOverlay(
                    onDone: {
                        // video finished naturally (optional: mark completed, analytics, etc.)
                        vm.onRewardDone?()
                    },
                    onFinished: {
                        // user closed or finished => hide + resume mic
                        vm.onRewardDismiss()
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .zIndex(10)
                // prevent background taps while overlay is up
                .allowsHitTesting(true)
            }
        }
        .onChange(of: vm.shouldShowAward) { show in
            if show {
                vm.onRewardAppear()   // pause listening so reward audio isn't counted
            }
        }
        .onAppear { vm.speech.requestAuthorization() }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.buggyCount)
        .animation(.easeInOut(duration: 0.25), value: vm.shouldShowAward)
    }
}
