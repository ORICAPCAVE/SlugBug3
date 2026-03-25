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
                // ✅ Background
                Image("slugbug1")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.35))

                // ✅ Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let err = vm.error {
                            Text(err)
                                .foregroundStyle(.red)
                                .padding(.vertical, 8)
                        } else if vm.text.isEmpty {
                            ProgressView("Loading rules…")
                                .padding()
                        } else if let attributed = try? AttributedString(markdown: vm.text) {
                            Text(attributed)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.08)))
                                .shadow(radius: 8, y: 4)
                        } else {
                            Text(vm.text)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.08)))
                                .shadow(radius: 8, y: 4)
                        }
                    }
                    // 👇 Move content down a bit (about 18% of screen height)
                    .padding(.top, max(80, geo.size.height * 0.18))
                    .padding(.horizontal)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity, alignment: .top)
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
}
