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

struct FriendsView: View {
    @ObservedObject var vm: FriendsVM
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Delete confirmation state
    @State private var pendingDeleteID: String?
    @State private var pendingDeleteName: String?
    @State private var isShowingDeleteAlert = false
    
    var body: some View {
        
        ZStack {
            // Background
            Image("slugbug1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            GeometryReader { geo in
                let deviceLandscape =
                    (UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first(where: { $0.activationState == .foregroundActive })?
                        .interfaceOrientation.isLandscape) ?? false

                let isNarrowWindow = geo.size.width < 700

                ZStack(alignment: .top) {
                    if deviceLandscape && !isNarrowWindow {
                        landscapeBody(geo)
                    } else {
                        portraitBody(geo)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            }
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
                friendRow(index: index)
            }
            
            Button {
                vm.addFriendRow()
            } label: {
                Label("Add Friend", systemImage: "plus.circle")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
    @ViewBuilder
    func landscapeBody(_ geo: GeometryProxy) -> some View {

        let drop = geo.size.height * 0.30   // 👈 20% vertical drop

        return ZStack(alignment: .top) {

            ScrollView {
                friendsContent
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, drop)   // 👈 THIS moves the ScrollView down
            .frame(maxWidth: .infinity)
        }
    }
        
    
    
    @ViewBuilder
    func portraitBody(_ geo: GeometryProxy) -> some View {

        let drop = geo.size.height * 0.10   // 👈 10% drop

        return ZStack(alignment: .top) {

            ScrollView {
                friendsContent
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, drop)   // 👈 moves it down
        }
    }
    private func onBack() {
        dismiss()
    }
    private func friendRow(index: Int) -> some View {
        let friend = $vm.items[index]
        
        return HStack {
            VStack(alignment: .leading) {
                TextField("Name", text: friend.name)
                    .textInputAutocapitalization(.words)
                
                TextField("Phone", text: friend.phone)
                    .keyboardType(.phonePad)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            Button("Save") {
                Task { await vm.save(friend.wrappedValue) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button {
                friend.invited.wrappedValue.toggle()
                Task { await vm.save(friend.wrappedValue) }
            } label: {
                Image(systemName: friend.invited.wrappedValue ? "checkmark.circle.fill" : "circle")
            }
            .padding(.horizontal, 4)
            .disabled(!vm.canInvite)
            
            Button(role: .destructive) {
                let item = vm.items[index]
                pendingDeleteID = item.id
                pendingDeleteName = item.name.isEmpty ? "this friend" : item.name
                isShowingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
            
        }
        .padding()
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

#Preview("Friends - iPad Landscape") {
    NavigationStack {
        FriendsView(vm: .preview)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
    }
    .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    .previewInterfaceOrientation(.landscapeLeft)
}




