// //
//  FriendsView.swift
//  SlugBug
//
//  Created with assistance from ChatGPT on 2025-12-09.
//  Handles display, editing, and selection of the user's friends list.
//
//
//
//  Created by Kevin Leckenby on 9/22/25.
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
                let isLandscape = geo.size.width > geo.size.height
                
                ZStack(alignment: .top) {
                    if isLandscape {
                        landscapeBody(geo)
                    } else {
                        portraitBody(geo)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("w \(Int(geo.size.width)) h \(Int(geo.size.height))")
                        Text("safeTop \(Int(geo.safeAreaInsets.top)) safeBot \(Int(geo.safeAreaInsets.bottom))")
                        Text(isLandscape ? "LANDSCAPE ✅" : "PORTRAIT ✅")
                    }
                    .font(.caption.weight(.bold))
                    .padding(8)
                    .background(.black.opacity(0.75))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
                }
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
        ScrollView {
            friendsContent
                .padding(.vertical, 16)
            
            // Optional: helps bring last row above keyboard/home indicator
            Color.clear.frame(height: 120)
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 44)   // ✅ THIS is the “make top visible” knob
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(.horizontal, 16)
    }
    
    
    
    @ViewBuilder
    private func portraitBody(_ geo: GeometryProxy) -> some View {
        let navBarH: CGFloat = 44
        let topPad = geo.safeAreaInsets.top + navBarH + 12
        
        ScrollView {
            friendsContent
                .padding(.vertical, 16)
            
            // ✅ extra space so you can scroll further down
            Color.clear.frame(height: 120)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 24)   // keeps last content off home indicator
        }
        
        .padding(.horizontal, 16)
        
        .padding(.top, topPad)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        
        // 2) Persist deletion (Firebase)
        do {
            try await vm.deleteFriend(id: id)
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




