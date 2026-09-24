
//
//  FriendsVM.swift
//  SlugBug3
//
//  Created by Leckenby and Associates LLC
//  Enhanced with assistance from ChatGPT (OpenAI)
//
//  Purpose:
//  ViewModel responsible for managing friend data including:
//  - Loading friends from Firebase Realtime Database
//  - Saving and updating friend records
//  - Deleting friends with async persistence
//
//  Key Enhancements (March 2026):
//  - Fixed delete operation to correctly remove records from Firebase
//  - Improved async handling and error recovery for deletions
//  - Ensured UI consistency with backend state during mutations
//
//  Notes:
//  Data is stored under:
//  users/{uid}/friends
//
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
    @Published var showingInviteComposer = false
    @Published var inviteMessage = ""
    @Published var invitePhoneNumber = ""
    @Published var pendingInviteFriendID: String?
    @Published var inviteErrorMessage: String?
    @Published var showingInviteError = false

    @Published var showingEmailComposer = false
    @Published var inviteEmailAddress = ""
    @Published var inviteEmailSubject = ""
    @Published var showingInviteChoiceAlert = false
    private let service: RealtimeDBService
    private let userId: String
    private let dbRef = Database.database().reference()

    init(
        userId: String? = Auth.auth().currentUser?.uid,
        service: RealtimeDBService = RealtimeDBService()
    ) {
        self.service = service
        self.userId = userId ?? ""

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
        items.append(Friend(id: "", name: "", phone: "", email: "", invited: false))
    }

    func invite(_ friend: Friend) async {
        guard canInvite else { return }
        guard !friend.invited else { return }

        let appleLink = "https://apps.apple.com/us/app/YOUR_REAL_APP_ID"
        let androidLink = "https://play.google.com/store/apps/details?id=YOUR_REAL_ANDROID_BUNDLE_ID"

        let message = """
        Hi \(friend.name),

        Come play Slug Bug with me!

        Download for iPhone/iPad:
        \(appleLink)

        Download for Android:
        \(androidLink)
        """

        if MessageComposerView.canSendText() {
            let trimmedPhone = friend.phone.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedPhone.isEmpty else {
                inviteErrorMessage = "This friend does not have a phone number yet."
                showingInviteError = true
                return
            }

            invitePhoneNumber = trimmedPhone
            inviteMessage = message
            pendingInviteFriendID = friend.id
            showingInviteComposer = true
            return
        }

        // iPad / unsupported SMS fallback
        let trimmedEmail = friend.email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            inviteErrorMessage = "This iPad cannot send text messages, and this friend does not have an email address saved yet."
            showingInviteError = true
            return
        }

        inviteMessage = message
        inviteEmailSubject = "Come play Slug Bug with me"
        inviteEmailAddress = trimmedEmail
        pendingInviteFriendID = friend.id
        showingInviteChoiceAlert = true
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
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { return }
        guard !trimmedID.isEmpty else { return }

        try await service.remove(friendID: trimmedID, for: userId)
        await load()
    }

    func markInvited(friendID: String) async {
        guard !userId.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == friendID }) else { return }

        items[index].invited = true
        await save(items[index])
    }
}

#if DEBUG
extension FriendsVM {
    static var preview: FriendsVM {
        let vm = FriendsVM()

        vm.items = [
            Friend(name: "Alice", phone: "555-1234", invited: false),
            Friend(name: "Bob", phone: "555-5678", invited: true),
            Friend(name: "Charlie", phone: "555-9012", invited: false),
        ]

        return vm
    }
}
#endif
