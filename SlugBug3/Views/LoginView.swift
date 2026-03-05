/*
 LoginView.swift
 SlugBug

 Responsive login layout supporting iPhone and iPad portrait/landscape.

 Key layout design:
 - ScrollView used to prevent keyboard overlap in landscape.
 - GeometryReader used to determine screen size and adjust typography.
 - Login form width constrained (maxCardW) to prevent stretching on iPad.
 - Form centered horizontally and vertically for balanced presentation.

 UI Improvements:
 - Google Sign-In button redesigned to increase visibility against
   the background image using material background, border, and shadow.
 - Primary email login uses borderedProminent style for visual hierarchy.

 Visual hierarchy:
   1. Log In (primary action)
   2. Google Sign In (secondary action)
   3. Sign Up / Forgot Password
   4. Home navigation

 Development Notes:
 - ScrollView + centered card layout ensures the screen works in:
     • iPhone portrait
     • iPhone landscape
     • iPad portrait
     • iPad landscape
     • iPad Split View

 Implementation assistance:
 - Layout centering, responsive width constraints, and Google sign-in
   button visibility improvements developed with assistance from
   ChatGPT (OpenAI).
 - Final UI design tuned by Kevin Leckenby.

 Last refined: 2026
*/
import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @EnvironmentObject var session: SessionVM
    @StateObject private var vm = LoginVM()
    
    // Optional callbacks you can keep using from elsewhere
    var onRegister: () -> Void = {}
    var onForgot:   () -> Void = {}
    var onHome:     () -> Void = {}
    var onSuccess:  () -> Void = {}
    
    var body: some View {
        GeometryReader { geo in
            let maxCardW: CGFloat = min(520, geo.size.width * 0.90)
            
            ZStack {
                Image("LoginBkground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        Text("Login")
                            .font(.system(size: geo.size.width > geo.size.height ? 28 : 36, weight: .bold))
                        
                        VStack(spacing: 14) {
                            TextField("Email", text: $vm.email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .textContentType(.username)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            SecureField("Password", text: $vm.password)
                                .textContentType(.password)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            Button {
                                Task {
                                    await vm.signInEmail()
                                    if session.isAuthenticated { onSuccess() }
                                }
                            } label: {
                                Text("Log In")
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(vm.isLoading)
                        }
                        
                        if let err = vm.errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }
                        
                        HStack(spacing: 16) {
                            Button("Sign Up", action: onRegister)
                            Spacer()
                            Button("Forgot Password", action: onForgot)
                        }
                        
                        Button {
                            if let vc = topViewController() {
                                Task {
                                    await vm.signInWithGoogle(presenter: vc)
                                    if session.isAuthenticated { onSuccess() }
                                }
                            } else {
                                vm.errorMessage = "No presenter available."
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)

                                Text("Sign in with Google")
                                    .font(.headline)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(.thinMaterial) // pops more than bordered on busy images
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.85), lineWidth: 2) // strong outline
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 6) // lifts it off the background
                        }
                        .buttonStyle(.plain) // avoid SwiftUI muting it
                        .disabled(vm.isLoading)
                        
                        Button("Home", action: onHome)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: maxCardW)                 // ✅ keeps it from stretching too wide
                    .frame(minHeight: geo.size.height)         // ✅ allows true vertical centering
                    .frame(maxWidth: .infinity)                // ✅ center the whole “card”
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)        // ✅ landscape/keyboard friendly
                .safeAreaInset(edge: .bottom) {                 // ✅ breathing room above Home bar
                    Color.clear.frame(height: 12)
                }
                
                if vm.isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                }
            }
        }
    }
}

// Presenter helper for Google Sign-In
@MainActor
private func topViewController(
    base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController
) -> UIViewController? {
    if let nav = base as? UINavigationController {
        return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController {
        return topViewController(base: tab.selectedViewController)
    }
    if let presented = base?.presentedViewController {
        return topViewController(base: presented)
    }
    return base
}
