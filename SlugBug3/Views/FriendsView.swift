//
//  FriendsView.swift
//  SlugBug3
//
//  Created by Leckenby and Associates LLC
//  Enhanced with assistance from ChatGPT (OpenAI)
//
//  Purpose:
//  Displays and manages the user’s list of friends.
//  Supports adding, editing, selecting, and deleting friends.
//
//  Key Enhancements (March 2026):
//  - Stabilized delete flow with immediate UI updates and async Firebase persistence
//  - Improved reliability of friend removal from Realtime Database
//  - Added safer state handling for pending deletions and UI rollback
//
//  Notes:
//  Works with FriendsVM and Firebase Realtime Database under:
//  users/{uid}/friends
//


import SwiftUI
import MessageUI

struct FriendsView: View {
    @ObservedObject var vm: FriendsVM
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Delete confirmation state
    @State private var pendingDeleteID: String?
    @State private var pendingDeleteName: String?
    @State private var isShowingDeleteAlert = false
    // MARK: - Add/Edit Friend state
    @State private var isShowingFriendEditor = false
    @State private var editingFriend: Friend?
    
    var body: some View {
        
        ZStack {
            Color.blue
                   .ignoresSafeArea()
            // Background
//            Image("slugbug1")
//                .resizable()
//                .scaledToFill()
//                .clipped()
//                .ignoresSafeArea()
//                .allowsHitTesting(false)
            
            GeometryReader { geo in
                
                let deviceLandscape =
                    (UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first(where: { $0.activationState == .foregroundActive })?
                        .interfaceOrientation.isLandscape) ?? false

                let isPhone = UIDevice.current.userInterfaceIdiom == .phone

                ZStack(alignment: .top) {
                    Image("slugbug1")
                                       .resizable()
                                       .scaledToFill()
                                       .frame(
                                           width: geo.size.width,
                                           height: geo.size.height
                                       )
                                       .clipped()
                                       .allowsHitTesting(false)

                    if deviceLandscape {
                        landscapeBody(geo)
                    } else {
                        portraitBody(geo)
                    }
                }
                .frame(width: geo.size.width,
                       height: geo.size.height)
                .clipped()
                
            }
        }
        .sheet(isPresented: $isShowingFriendEditor) {
            if let friend = editingFriend {
                FriendEditorView(
                    friend: friend
                ) { savedFriend in
                    Task {
                        await vm.save(savedFriend)
                    }

                    editingFriend = nil
                    isShowingFriendEditor = false
                }
            }
        }
        .sheet(isPresented: $vm.showingInviteComposer) {
            MessageComposerView(
                recipients: [vm.invitePhoneNumber],
                body: vm.inviteMessage
            ) { didSend in
                if didSend, let id = vm.pendingInviteFriendID {
                    Task {
                        await vm.markInvited(friendID: id)
                    }
                }

                vm.pendingInviteFriendID = nil
                vm.invitePhoneNumber = ""
                vm.inviteMessage = ""
            }
        }
        .sheet(isPresented: $vm.showingEmailComposer) {
            MailComposerView(
                recipients: [vm.inviteEmailAddress],
                subject: vm.inviteEmailSubject,
                body: vm.inviteMessage
            ) { didSend in
                if didSend, let id = vm.pendingInviteFriendID {
                    Task {
                        await vm.markInvited(friendID: id)
                    }
                }

                vm.pendingInviteFriendID = nil
                vm.inviteEmailAddress = ""
                vm.inviteEmailSubject = ""
                vm.inviteMessage = ""
            }
        }
        .alert("Invite", isPresented: $vm.showingInviteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.inviteErrorMessage ?? "Unable to send invite.")
        }
        .alert("Delete Friend?", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive) {
                guard let id = pendingDeleteID else { return }
                Task { await deleteFriend(id: id) }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteID = nil
                pendingDeleteName = nil
            }
        } message: {
            Text("Are you sure you want to delete \(pendingDeleteName ?? "this friend")?")
        }
        .confirmationDialog(
            "Text Messaging Unavailable",
            isPresented: $vm.showingInviteChoiceAlert,
            titleVisibility: .visible
        ) {
            Button("Email Invite") {
                guard MailComposerView.canSendMail() else {
                    vm.inviteErrorMessage = "Mail is not configured on this device."
                    vm.showingInviteError = true
                    return
                }

                vm.showingEmailComposer = true
            }

            Button("Cancel", role: .cancel) {
                vm.pendingInviteFriendID = nil
                vm.inviteEmailAddress = ""
                vm.inviteEmailSubject = ""
                vm.inviteMessage = ""
            }
        } message: {
            Text("This iPad cannot send text messages. You can send an email invitation instead.")
        }
 
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.white)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Friends")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        
        
    }
    
    // Shared scroll content
    private var friendsContent: some View {
        VStack(spacing: 8) {
            ForEach(vm.items.indices, id: \.self) { index in

                if UIDevice.current.userInterfaceIdiom == .phone {
                    phoneFriendRow(index: index)
                } else {
                    friendRow(index: index)
                }
            }
            
            Button {
                editingFriend = Friend(
                    id: "",
                    name: "",
                    phone: "",
                    email: "",
                    invited: false
                )
                isShowingFriendEditor = true
            } label: {
                Label("Add Friend", systemImage: "plus.circle")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal,12)
        .frame(maxWidth: .infinity)
    }
    @ViewBuilder
    func landscapeBody(_ geo: GeometryProxy) -> some View {

        ScrollView(.vertical, showsIndicators: true) {

            VStack(spacing: 6) {

                ForEach(vm.items.indices, id: \.self) { index in
                    phoneFriendRow(index: index)
                }

                Button {
                    editingFriend = Friend(
                        id: "",
                        name: "",
                        phone: "",
                        email: "",
                        invited: false
                    )
                    isShowingFriendEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Friend")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .frame(
            width: geo.size.width,
            height: geo.size.height
        )
    }
    
    @ViewBuilder
    func portraitBody(_ geo: GeometryProxy) -> some View {

        ScrollView(.vertical, showsIndicators: true) {

            VStack(spacing: 8) {

                ForEach(vm.items.indices, id: \.self) { index in
                    phoneFriendRow(index: index)
                }

                Button {
                    editingFriend = Friend(
                        id: "",
                        name: "",
                        phone: "",
                        email: "",
                        invited: false
                    )
                    isShowingFriendEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Friend")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
    }
    private func onBack() {
        dismiss()
    }
    private func phoneFriendRow(index: Int) -> some View {
        let friend = vm.items[index]

        return Button {
            editingFriend = friend
            isShowingFriendEditor = true
        } label: {
            HStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.name.isEmpty ? "New Friend" : friend.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !friend.phone.isEmpty {
                        Text(friend.phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    guard !friend.invited else { return }

                    Task {
                        await vm.invite(friend)
                    }
                } label: {
                    Image(
                        systemName: friend.invited
                            ? "checkmark.circle.fill"
                            : "paperplane.circle.fill"
                    )
                    .font(.title3)
                    .foregroundStyle(
                        friend.invited ? .green : .blue
                    )
                }
                .buttonStyle(.plain)
                .disabled(!vm.canInvite || friend.invited)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    private func friendRow(index: Int) -> some View {
        let friend = $vm.items[index]

        return VStack(alignment: .leading, spacing: 8) {

            // Friend information
            TextField("Name", text: friend.name)
                .textInputAutocapitalization(.words)

            TextField("Phone", text: friend.phone)
                .keyboardType(.phonePad)
                .foregroundStyle(.secondary)

            TextField("Email", text: friend.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.secondary)

            // Controls
            HStack {
                Button("Save") {
                    Task {
                        await vm.save(friend.wrappedValue)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button {
                    let current = friend.wrappedValue
                    guard !current.invited else { return }

                    Task {
                        await vm.invite(current)
                    }
                } label: {
                    Image(
                        systemName:
                            friend.invited.wrappedValue
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
                .disabled(
                    !vm.canInvite ||
                    friend.invited.wrappedValue
                )

                Button(role: .destructive) {
                    let item = vm.items[index]

                    pendingDeleteID = item.id
                    pendingDeleteName =
                        item.name.isEmpty
                        ? "this friend"
                        : item.name

                    isShowingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func deleteFriend(id: String) async {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Remove from UI immediately (smooth UX)
        let removed = await MainActor.run { () -> Friend? in
            let item = vm.items.first { $0.id == id }
            withAnimation {
                vm.items.removeAll { $0.id == id }
            }
            pendingDeleteID = nil
            pendingDeleteName = nil
            return item
        }
        guard !trimmedID.isEmpty else { return }
        
        // 2) Persist deletion (Firebase)
        do {
            try await vm.deleteFriend(id: trimmedID)
        } catch {
            // Optional rollback so the friend comes back if delete fails
            if let removed {
                await MainActor.run {
                    withAnimation { vm.items.append(removed) }
                }
            }
            print("Delete failed:", error)
        }
    }
}
private struct FriendEditorView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var friend: Friend

    let onSave: (Friend) -> Void

    init(
        friend: Friend,
        onSave: @escaping (Friend) -> Void
    ) {
        _friend = State(initialValue: friend)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Friend Information") {

                    TextField("Name", text: $friend.name)
                        .textInputAutocapitalization(.words)

                    TextField("Phone Number", text: $friend.phone)
                        .keyboardType(.phonePad)

                    TextField("Email", text: $friend.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(
                friend.id.isEmpty ? "Add Friend" : "Edit Friend"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(friend)
                    }
                    .disabled(
                        friend.name
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
        }
    }
}




