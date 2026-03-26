//
//  ScoreView.swift
//  SlugBug3
//
//  Created by Leckenby and Associates LLC
//  Enhanced with assistance from ChatGPT (OpenAI)
//
//  Purpose:
//  Displays list of SlugBug scores retrieved from Firebase.
//
//  Notes:
//  Minor layout and debugging adjustments discussed during development,
//  including scroll positioning and landscape behavior.
//
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
            
                let deviceLandscape =
                (UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)?
                    .interfaceOrientation.isLandscape ?? false
                
                let windowLandscape = geo.size.width > geo.size.height
                let useLandscape = deviceLandscape || windowLandscape
                let scoresTopInsetPct: CGFloat = 0.80
                // ✅ increase to move scores DOWN (try 0.10–0.18)
                let linkUpPct: CGFloat = 0.28           // ✅ increase to move link UP (try 0.24–0.35)
                // Targets (Landscape)
                let scoresRegionFrac: CGFloat = 0.65   // top 65%
                let linkBottomFrac: CGFloat = 0.45
                // link sits ~20% up from bottom
                
                // Portrait fallback
                let portraitTopDropFrac: CGFloat = 0.18
                
                
                
                if useLandscape {
                    VStack(spacing: 0) {
                        Text("LANDSCAPE ✅")
                            .font(.headline.bold())
                            .padding(8)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                        
                        // rest of your landscape content here
                    }
                
                let topDrop = geo.size.height * 0.30
                let windowW = min(geo.size.width * 0.75, 620)
                let scoreH = geo.size.height * 0.25
                let linkLower: CGFloat = 2
                
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topDrop)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                    }
                    .frame(width: windowW, height: scoreH)
                    .background(Color.black.opacity(0.20))
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
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                Button(action: onHome) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.white)   // 👈 THIS fixes it
                }
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
                    Text("Your Buggy Scores")
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
