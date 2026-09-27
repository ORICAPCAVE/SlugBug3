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
import UIKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionVM
    @State private var confirmDeleteAccount = false
    @State private var showPasswordPrompt = false
    @State private var deletePassword = ""
    @State private var deleteError: String?
    
    
    private func onBack() {
        dismiss()
    }
    var body: some View {
        ZStack {
            
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geo in
                
                let deviceLandscape =
                geo.size.width > geo.size.height
                
                let topDrop =
                deviceLandscape
                ? geo.size.height * 0.30
                : 30
                
                let rightShift =
                deviceLandscape
                ? geo.size.width * 0.10
                : 0
                
                let availableWidth =
                max(0, geo.size.width - 32)
                
                let boxWidth =
                min(600, availableWidth)
                
                ZStack {
                    
                    Image("slugbug1")
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height
                        )
                        .clipped()
                        .allowsHitTesting(false)
                    
                    ScrollView {
                        
                        // vertical drop that remains scrollable
                        Color.clear
                        .frame(height: topDrop)}
                    
                    // ✅ horizontal shift that won't clip
                    VStack(spacing: 14) {
                        Text("About Slug Bug")
                            .font(.largeTitle.bold())
                            .foregroundColor(.yellow)
                        
                        Text("Version 3")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How it works")
                                .font(.headline)
                                .foregroundColor(.yellow)
                            
                            Text("Spot a Volkswagen Beetle, call “Buggy!”, and track your games, scores, and photos.")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("Credits")
                                .font(.headline)
                                .foregroundColor(.yellow)
                            
                            Text("Created by Leckenby and Associates LLC.")
                                .foregroundColor(.white)
                                .font(.headline)
                            Divider()
                                .background(Color.white.opacity(0.5))
                                .padding(.vertical, 6)
                            
                            Button(role: .destructive) {
                                confirmDeleteAccount = true
                            } label: {
                                Label("Delete Account", systemImage: "trash")
                                    .font(.headline)
                            }
                            .padding()
                            .background(.black.opacity(0.80))
                            .cornerRadius(16)
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .frame(width: boxWidth)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(x: rightShift)
                        // ✅ bottom breathing room so nothing gets hidden
                        Color.clear.frame(height: 24)
                    }
                }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $confirmDeleteAccount,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {

                    if session.currentSignInProvider == "apple.com" {

                        Task {
                            let authenticated =
                                await session.reauthenticateWithApple()

                            if authenticated {
                                await session.deleteAccount()
                            } else {
                                deleteError = session.errorMessage
                            }
                        }

                    } else if session.currentSignInProvider == "google.com" {

                        if let vc = topViewController() {
                            Task {
                                let authenticated =
                                    await session.reauthenticateWithGoogle(
                                        presenter: vc
                                    )

                                if authenticated {
                                    await session.deleteAccount()
                                } else {
                                    deleteError = session.errorMessage
                                }
                            }
                        } else {
                            deleteError = "Unable to display Google Sign-In."
                        }

                    } else {

                        // Email/password account
                        deletePassword = ""
                        showPasswordPrompt = true
                    }
                }

                Button("Cancel", role: .cancel) { }

            } message: {
                Text(
                    "This will permanently delete your Slug Bug account and associated data. This action cannot be undone."
                )
            }
                .alert("Confirm Your Password", isPresented: $showPasswordPrompt) {
                    
                    SecureField("Password", text: $deletePassword)
                    
                    Button("Delete Account", role: .destructive) {
                        Task {
                            let authenticated =
                            await session.reauthenticate(password: deletePassword)
                            
                            if authenticated {
                                await session.deleteAccount()
                            } else {
                                deleteError = session.errorMessage
                            }
                            
                            deletePassword = ""
                        }
                    }
                
                    
                    Button("Cancel", role: .cancel) {
                        deletePassword = ""
                    }
                    
                } message: {
                    Text("Enter your password to permanently delete your account.")
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
        private func topViewController() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let root = scene.windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {
                return nil
            }
            
            var top = root
            
            while let presented = top.presentedViewController {
                top = presented
            }
            
            return top
        }
    }

