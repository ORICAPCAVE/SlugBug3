import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("SlugBug iOS")
            Button("Run Firebase Smoke Test") { smokeTest() }
        }
        .padding()
    }
}

func smokeTest() {
    print("Firebase apps:", FirebaseApp.allApps ?? [:])

    Auth.auth().signInAnonymously { result, error in
        if let error = error { print("Auth error:", error); return }
        let uid = result?.user.uid ?? "?"
        print("Signed in as:", uid)

        // If you use a custom DB instance, swap in your URL below:
        // let db = Database.database(url: "https://<your-db>.firebasedatabase.app")
        let db = Database.database()
        let ref = db.reference().child("debug").child(uid)

        ref.setValue(["ts": ServerValue.timestamp(), "hello": "world"]) { err, _ in
            if let err = err { print("DB write error:", err); return }
            ref.observeSingleEvent(of: .value) { snap in
                print("DB read value:", snap.value ?? "nil")
            }
        }
    }
}

//  ContentView.swift
//  Slug Bug
//
//  Created by Kevin Leckenby on 9/23/25.
//

