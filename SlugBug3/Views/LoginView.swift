//
//  LoginView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 9/30/25.
//
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
        ZStack {
            Image("LoginBkground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Text("Login")
                        .font(.system(size: 36, weight: .bold))

                    VStack(spacing: 14) {
                        TextField("Email", text: $vm.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        SecureField("Password", text: $vm.password)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button {
                            Task {
                                await vm.signInEmail()
                                if session.isAuthenticated { onSuccess() } // optional
                            }
                        } label: {
                            Text("Log In")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(vm.isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    if let err = vm.errorMessage {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    HStack(spacing: 16) {
                        Button("Sign Up", action: onRegister)
                        Spacer()
                        Button("Forgot Password", action: onForgot)
                    }
                    .padding(.horizontal, 24)

                    // Google Sign-In
                    Button {
                        if let vc = topViewController() {
                            Task {
                                await vm.signInWithGoogle(presenter: vc)
                                if session.isAuthenticated { onSuccess() } // optional
                            }
                        } else {
                            vm.errorMessage = "No presenter available."
                        }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(vm.isLoading)
                    .padding(.horizontal, 24)

                    Button("Home", action: onHome)
                        .padding(.top, 8)
                }
                .padding(.vertical, 24)
            }

            if vm.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
            }
        }
        // removed: .onAppear { vm.onAppear() }
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
