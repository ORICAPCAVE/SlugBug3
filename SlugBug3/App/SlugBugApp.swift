import SwiftUI
import Combine
import FirebaseCore
import GoogleSignIn

import SwiftUI
import GoogleSignIn

@main
struct SlugBugApp: App {
    @StateObject private var session = SessionVM()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Show landing until the user continues. Persist if you want it only once.
    @AppStorage("didDismissLanding") private var didDismissLanding = false

    var body: some Scene {
           WindowGroup {
               RootSwitcherView() // your Landing/Login/MainMenu logic
                   .environmentObject(session)
                   .onOpenURL { url in
                       _ = GIDSignIn.sharedInstance.handle(url)
                   }
           }
       }
   }
