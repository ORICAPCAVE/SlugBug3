//
//  RootSwitcherView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 10/2/25.
//
import SwiftUI

struct RootSwitcherView: View {
    @EnvironmentObject var session: SessionVM
    @AppStorage("didDismissLanding") private var didDismissLanding = false
    
    var body: some View {
        Group {
            if session.isAuthenticated {
                MainMenuView()                           // ← always show this when logged in
            } else if !didDismissLanding {
                LandingView(onContinue: { didDismissLanding = true })
            } else {
                LoginView()
            }
        }
        .onAppear {
            print("✅ RootSwitcherView active | auth=\(session.isAuthenticated) | didDismissLanding=\(didDismissLanding)")
        }
    }
    }
