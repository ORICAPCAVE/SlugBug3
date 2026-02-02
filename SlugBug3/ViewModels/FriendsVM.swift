
//
//  FriendsVM.swift
//  SlugBug
//
//  Created with assistance from ChatGPT on 2025-12-09.
//  View model for FriendsView: loads, saves, and deletes friends in Firebase Realtime Database.
//
//Kevin Leckenby 
import SwiftUI
import Foundation
import FirebaseAuth
import Combine
import FirebaseDatabase

@MainActor
final class FriendsVM: ObservableObject {
    @Published var items: [Friend] = []
    @Published var canInvite = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service: RealtimeDBService
    private let userId: String
    private let dbRef = Database.database().reference()
    init(
        userId: String? = Auth.auth().currentUser?.uid,
        service: RealtimeDBService = RealtimeDBService()
    ) {
        self.service = service
        self.userId  = userId ?? ""
        
        Task {
            await load()
        }
    }
    
    // MARK: - Load
    
    func load() async {
        guard !userId.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let friends = try await service.loadFriends(for: userId)
            self.items = friends.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Intents
    
    func addFriendRow() {
        items.append(Friend(id: "", name: "", phone: "", invited: false))
    }
    func invite(_ friend: Friend) {
        guard let idx = items.firstIndex(where: { $0.id == friend.id }) else { return }
        items[idx].invited = true
        Task { await save(items[idx]) }
    }
    
    func save(_ friend: Friend) async {
        guard !userId.isEmpty else { return }
        
        do {
            try await service.save(friend: friend, for: userId)
            await load()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func delete(at offsets: IndexSet) async {
        guard !userId.isEmpty else { return }
        
        let toDelete = offsets.map { items[$0] }
        
        do {
            for friend in toDelete {
                if !friend.id.isEmpty {
                    try await service.remove(friendID: friend.id, for: userId)
                }
            }
            await load()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
    }
    func deleteFriend(id: String) async throws {
        let ref = dbRef
            .child("friends")
            .child(id)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.removeValue { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
        
    


#if DEBUG
extension FriendsVM {
    static var preview: FriendsVM {
        let vm = FriendsVM()   // <-- if this doesn't compile, see note below

        vm.items = [
            Friend(name: "Alice", phone: "555-1234", invited: false),
            Friend(name: "Bob", phone: "555-5678", invited: true),
            Friend(name: "Charlie", phone: "555-9012", invited: false),
        ]

        return vm
    }
}
#endif

