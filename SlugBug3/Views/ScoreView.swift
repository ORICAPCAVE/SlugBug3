//
//  ScoreView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 2025-10-09.
//  Some portions of this file were generated or adapted
//  with assistance from OpenAI’s ChatGPT (GPT-5) to illustrate
//  Firebase data display using SwiftUI (List / ScrollView patterns).
//  All subsequent modifications and integrations are by
//  Leckenby and Associates LLC.
//
// AI-assisted development note:
// The initial Firebase-List view pattern was suggested by OpenAI’s ChatGPT.
// Implementation reviewed and customized by Kevin Leckenby, Leckenby & Associates LLC.
import SwiftUI

struct ScoreView: View {
    let onHome: () -> Void
    @StateObject private var vm: ScoresVM
    @State private var pendingDelete: Score? = nil
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    init(onHome: @escaping () -> Void = {}, vm: ScoresVM = ScoresVM()) {
        self.onHome = onHome
        _vm = StateObject(wrappedValue: vm)
    }
    var body: some View {
        ZStack {
            // Background
            Image("slugbug1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        
                

            
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                let scoresTopInsetPct: CGFloat = 0.80
                // ✅ increase to move scores DOWN (try 0.10–0.18)
                let linkUpPct: CGFloat = 0.28           // ✅ increase to move link UP (try 0.24–0.35)
                // Targets (Landscape)
                let scoresRegionFrac: CGFloat = 0.65   // top 65%
                let linkBottomFrac: CGFloat = 0.45
                // link sits ~20% up from bottom
                
                // Portrait fallback
                let portraitTopDropFrac: CGFloat = 0.18
                
                if isLandscape {
                    let scrollTopDropPct: CGFloat = 0.18  // try 0.12 – 0.18
                    let scrollTopDrop = geo.size.height * scrollTopDropPct

                    let topInset = geo.safeAreaInsets.top
                    let bottomInset = geo.safeAreaInsets.bottom
                    let windowW = min(geo.size.width * 0.75, 620)
                    let linkLower: CGFloat = 120
                    let linkGap: CGFloat = 20
                    let scrollDrop: CGFloat = 800
                    let linkHeight: CGFloat = 52
                    let gapUnderScroll: CGFloat = 20
                    let scoreH = max(200, geo.size.height - geo.safeAreaInsets.top
                                     - scrollTopDrop
                                     - gapUnderScroll
                                     - linkHeight
                                     - geo.safeAreaInsets.bottom
                                     - 24
                             )

                    
                    VStack(spacing: 0) {
                        Spacer().frame(height: geo.safeAreaInsets.top + scrollTopDrop)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                Color.clear.frame(height: 12)

                                ForEach(vm.items) { s in
                                    Text(s.dateLabel)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                        .contentShape(Rectangle())
                                        .onTapGesture { pendingDelete = s }
                                }
                                Color.clear.frame(height: 24)
                            }
                            .padding(.top, 0)
                        }
                
                        .frame(width: windowW, height: scoreH)
                        .clipped()
                        
                       
                        
                        Spacer().frame(height: linkLower)

                
                        Link(destination: URL(string: "https://steamintegrator.net/HighScores.html")!) {
                            Label("View High Scorers", systemImage: "trophy.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .frame(width: windowW)

                                Spacer(minLength: bottomInset + 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .overlay(alignment: .topLeading) {
                                Text("isLandscape = \(geo.size.width > geo.size.height ? "true" : "false")")
                                    .font(.title.bold())
                                    .padding(10)
                                    .background(Color.mint.opacity(0.9))
                                    .cornerRadius(10)
                                    .padding(.top, geo.safeAreaInsets.top + 8)
                                    .padding(.leading, 12)
                                    .zIndex(9999)
                            }
                        }

 else {
                    // PORTRAIT: scroll + link overlay
                    ZStack {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.items) { s in
                                    Text(s.dateLabel)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                        .contentShape(Rectangle())
                                        .onTapGesture { pendingDelete = s }
                                }
                                
                                // Extra bottom space so last row doesn't hide behind the link
                                Color.clear.frame(height: geo.size.height * 0.24)
                            }
                            .padding(.top, geo.size.height * portraitTopDropFrac)
                        }
                        
                        VStack {
                            Spacer()
                            Link(destination: URL(string: "https://steamintegrator.net/HighScores.html")!) {
                                Label("View High Scorers", systemImage: "trophy.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .padding(.horizontal)
                            .padding(.top,600)
                            .padding(.bottom, geo.size.height * 0.20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scores")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onHome) { Label("Home", systemImage: "house") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .alert(
            "Delete this score?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let s = pendingDelete {
                    vm.delete(score: s) { _ in pendingDelete = nil }
                }
            }
        } message: {
            Text(pendingDelete?.dateLabel ?? "")
        }
        .onAppear {
            guard !isPreview else { return }
            vm.start()
        }
        .onDisappear {
            guard !isPreview else { return }
            vm.stop()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Buggy Photos")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
    }
    
}
#if DEBUG
#Preview("ScoreView (Forced Landscape Size)") {
    NavigationStack {
        ScoreView(onHome: {}, vm: ScoresVM.preview)
    }
    .previewLayout(.fixed(width: 852, height: 393)) // landscape-ish iPhone
}
#endif
