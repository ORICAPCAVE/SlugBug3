//
//  ScoresVM.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 10/9/25.
//
import FirebaseAuth
import FirebaseDatabase
import Combine

final class ScoresVM: ObservableObject {
    @Published var items: [Score] = []

    private var ref: DatabaseReference?
    private var handle: DatabaseHandle?

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let base = Database.database().reference()
            .child("users")
            .child(uid)
            .child("SlugBugs")

        ref = base

        handle = base.observe(.value) { [weak self] snap in
            guard let self else { return }

            guard snap.exists() else {
                DispatchQueue.main.async { self.items = [] }
                return
            }

            var tmp: [Score] = []
            for child in snap.children {
                guard
                    let s = child as? DataSnapshot,
                    let dict = s.value as? [String: Any]
                else { continue }

                tmp.append(Score(id: s.key, dict: dict)) // model does parsing
            }

            tmp.sort { $0.ts > $1.ts } // newest first

            DispatchQueue.main.async {
                self.items = tmp
            }
        }
    }

    func stop() {
        if let ref, let h = handle {
            ref.removeObserver(withHandle: h)
        }
        handle = nil
        ref = nil
    }

    func delete(score: Score, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(NSError(
                domain: "Auth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Not signed in"]
            ))
            return
        }

        let userRef  = Database.database().reference().child("users").child(uid)
        let scoreRef = userRef.child("SlugBugs").child(score.id)
        let statsRef = userRef.child("stats").child("slugbugTotal")

        scoreRef.removeValue { err, _ in
            if let err = err { completion(err); return }

            statsRef.runTransactionBlock { current in
                let n = (current.value as? Int) ?? 0
                current.value = max(0, n - 1)
                return .success(withValue: current)
            } andCompletionBlock: { _, _, _ in
                completion(nil)
            }
        }
    }
}

#if DEBUG
extension ScoresVM {
    static var preview: ScoresVM {
        let vm = ScoresVM()
        vm.items = Score.previewSamples   // ✅ uses your real Score model
        return vm
    }
}
#endif
