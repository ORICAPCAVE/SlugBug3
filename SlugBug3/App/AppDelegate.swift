// AppDelegate.swift
//  Slug Bug
//
//  Cre/ated by Kevin Leckenby on
//




import UIKit
import FirebaseCore
import GoogleSignIn



class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()   // ← configure here (once)
      // Configure Google Sign-In with Firebase clientID (from GoogleService-Info.plist)
      if let clientID = FirebaseApp.app()?.options.clientID {
                 GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
             }
    return true
  }
}



