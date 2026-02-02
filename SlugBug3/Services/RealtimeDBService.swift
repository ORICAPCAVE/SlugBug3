//
//  RealtimeDBService.swift
//  SlugBug
//
//  Created with assistance from ChatGPT on 2025-12-09.
//  Service layer for interacting with Firebase Realtime Database
//  (friends, slug bugs, events, and related user data).
//
//Kevin Leckenby

import FirebaseDatabase

final class RealtimeDBService {
    // Path helpers mirror your Android RTDB structure
    private func userRoot(_ uid: String) -> String { "users/\(uid)" }
    private func friendsPath(_ uid: String) -> String { "\(userRoot(uid))/friends" }
    private func eventsPath(_ uid: String) -> String { "\(userRoot(uid))/events" }
    private func setValueAsync(_ ref: DatabaseReference, _ value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, ref in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
    }
    
    
    // MARK: Friends
    func loadFriends(for uid: String) async throws -> [Friend] {
    #if canImport(FirebaseDatabase)
        let ref = Database.database().reference(withPath: friendsPath(uid))
        let snapshot = try await ref.getData()

        guard let dict = snapshot.value as? [String: Any] else {
            return []   // no friends yet
        }

        // NOTE: we handle BOTH old ("name"/"invited") and new ("friend"/"isSelected") keys
        let friends = dict.compactMap { (key, val) -> Friend? in
            guard let v = val as? [String: Any] else { return nil }

            let name =
                (v["friend"] as? String) ??    // new key (matches Android / RTDB shape)
                (v["name"]   as? String) ?? "" // old key (iOS-only writes)

            let phone = v["phone"] as? String ?? ""

            let invited =
                (v["isSelected"] as? Bool) ??  // new key (DB screenshot)
                (v["invited"]    as? Bool) ??  // old key
                false

            // Prefer explicit key field, otherwise use the RTDB child key
            let id = (v["key"] as? String) ?? key

            return Friend(id: id, name: name, phone: phone, invited: invited)
        }

        return friends
    #else
        return []
    #endif
    }


    
    func save(friend: Friend, for uid: String) async throws {
    #if canImport(FirebaseDatabase)
        let base = Database.database().reference(withPath: friendsPath(uid))

        // Decide whether we're creating or updating
        let ref: DatabaseReference
        if friend.id.isEmpty {
            // NEW friend: use auto ID
            ref = base.childByAutoId()
        } else {
            // EXISTING friend: use its key
            ref = base.child(friend.id)
        }

        // Ensure we have the final ID (either existing or newly generated)
        let id = ref.key ?? friend.id

        // 🔵 Write fields that match your actual DB structure:
        //   friend      = name
        //   isSelected  = invited
        //   key         = id
        var payload: [String: Any] = [
            "friend":     friend.name,
            "phone":      friend.phone,
            "isSelected": friend.invited,
            "key":        id
        ]

        try await ref.setValue(payload)
    #else
        throw ServiceError.notImplemented
    #endif
    }

    func remove(friendID: String, for uid: String) async throws {
#if canImport(FirebaseDatabase)
        let ref = Database.database().reference(withPath: "\(friendsPath(uid))/\(friendID)")
        try await ref.removeValue()
#endif
    }
    
    // MARK: Events
    func pushBugHitEvent(_ event: BugHitEvent, for uid: String) async throws {
           let ref = Database.database().reference()
               .child("users").child(uid)
               .child("BugEvents").child(event.id)

           try await setValueAsync(ref, [
               "ts": event.ts,
               "count": event.count
           ])
       }

       // Full SlugBug (8 hits) — include `date` to satisfy your rules
       func pushSlugBugEvent(_ event: SlugBugEvent, for uid: String) async throws {
           let ref = Database.database().reference()
               .child("users").child(uid)
               .child("SlugBugs").child(event.id)

           let date = Date(timeIntervalSince1970: TimeInterval(event.ts)/1000)
           let df = DateFormatter()
           df.calendar = .init(identifier: .gregorian)
           df.locale   = .init(identifier: "en_US_POSIX")
           df.timeZone = .current
           df.dateFormat = "yyyy-MM-dd"
           let dateStr = df.string(from: date)

           try await setValueAsync(ref, [
               "date":  dateStr,   // <-- required by your rules
               "ts":    event.ts,
               "count": event.count
           ])
       }
       }
       
