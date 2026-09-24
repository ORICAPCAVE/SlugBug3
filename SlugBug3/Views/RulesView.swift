//
//  RulesView.swift
//  SlugBug
//
//  Created by Kevin Leckenby on [11/20/25].
//  Concept and layout collaboratively developed with assistance from ChatGPT (OpenAI).
//  This view displays Markdown-formatted gameplay rules with styled background,
//  scrollable layout, and adaptive top padding for dynamic screen sizes.
//

//
import SwiftUI

struct RulesView: View {
    @StateObject private var vm = StaticTextVM()
    @Environment(\.dismiss) private var dismiss
    
    private func onBack() {
        dismiss()
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                
                // Base background keeps the ZStack constrained
                Color.blue
                    .ignoresSafeArea()
                
                // Background image constrained to the screen
                Image("slugbug1")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height
                    )
                    .clipped()
                    .allowsHitTesting(false)
                    .overlay(Color.black.opacity(0.35))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let err = vm.error {
                            Text(err)
                                .foregroundStyle(.red)
                                .padding(.vertical, 8)
                        } else if vm.text.isEmpty {
                            ProgressView("Loading rules…")
                                .padding()
                        } else {
                            
                            rulesContent(vm.text)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(
                                    .ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.08))
                                )
                                .shadow(radius: 8, y: 4)
                        }
                            
                        }
                        // 👇 Move content down a bit (about 18% of screen height)
                            .padding(.top, max(80, geo.size.height * 0.18))
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .navigationTitle("Rules")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                
                .toolbar {
                    // ✅ Back button (same as ScoreView / PlayBugView)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    
                    // ✅ Center title (optional but recommended for consistency)
                    ToolbarItem(placement: .principal) {
                        Text("Rules")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    
                    // ✅ Your existing Share button (moved into same toolbar)
                    if !vm.text.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ShareLink(item: vm.text) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .onAppear { vm.load(resource: "Rules", ext: "md") }
            }
        }
        @ViewBuilder
        private func rulesContent(_ markdown: String) -> some View {
            
            let lines = markdown.components(separatedBy: .newlines)
            
            VStack(alignment: .leading, spacing: 10) {
                
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    
                    if trimmed.isEmpty {
                        
                        Spacer()
                            .frame(height: 4)
                        
                    } else if trimmed == "---" {
                        
                        Divider()
                            .overlay(.white.opacity(0.35))
                            .padding(.vertical, 4)
                        
                    } else if trimmed.hasPrefix("# ") {
                        
                        Text(trimmed.dropFirst(2))
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding(.bottom, 6)
                        
                    } else if trimmed.hasPrefix("### ") {
                        
                        Text(trimmed.dropFirst(4))
                            .font(.headline.bold())
                            .foregroundStyle(.yellow)
                            .padding(.top, 8)
                    
                        
                    } else {
                        
                        if let attributed =
                            try? AttributedString(markdown: trimmed) {

                            Text(attributed)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                                .tint(.yellow)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                        } else {
                            
                            Text(trimmed)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

