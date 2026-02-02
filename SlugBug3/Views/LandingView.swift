//
//  LandingView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 9/30/25.
//
import SwiftUI
import FirebaseAuth

struct LandingView: View {
    enum Route: Hashable { case rules, tribute, login, app }

    @EnvironmentObject var session: SessionVM       // from earlier scaffold
    @State private var path: [Route] = []
    var onContinue: () -> Void = {}
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Background image like android:background="@drawable/slugbug1"
                Image("slugbug1")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    HStack(spacing: 24) {
                        Button("Rules") { path.append(.rules) }
                            .buttonStyle(.borderedProminent)

                        Button("Tribute") { path.append(.tribute) }
                            .buttonStyle(.borderedProminent)}
                    Button("Continue") { onContinue() }
                    Button("Log In or Register") {
                        if session.user != nil {
                            path.append(.app)   // After_Logged_in
                        } else {
                            path.append(.login) // LoginActivity
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 24) {
                        Button("Exit") {
                            // iOS cannot programmatically exit; present a tip instead.
                            // Optionally show an alert that says: "Press the Home button or swipe up to close."
                        }
                        .buttonStyle(.bordered)

                        Button("Log out!") {
                            session.signOut()
                        }
                        .buttonStyle(.bordered)
                        .disabled(session.user == nil)
                    }
                }
                .padding()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .rules:
                    RulesView()
                case .tribute:
                    TributeView()
                case .login:
                    LoginView()   // from the scaffold I gave earlier
                case .app:
                    RootView()    // your TabView for Play/Friends/Achievements/Photos
                        .environmentObject(PlayBugVM())
                        .environmentObject(FriendsVM())
                        .environmentObject(AchievementsVM())
                        .environmentObject(PhotosVM())
                }
            }
        }
    }
    
}

