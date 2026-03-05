/*
 FriendsView.swift
 SlugBug

 Layout improvements for iPad portrait, landscape, and Split View.

 Key behaviors implemented:
 - Detect true device orientation using UIWindowScene.interfaceOrientation.
 - Use GeometryReader to size and position the ScrollView container.
 - Apply percentage-based vertical drops to keep the Friends list visually centered
   on large iPad landscape displays.
 - Separate layout paths for portrait and landscape to keep spacing predictable.
 - Maintain ScrollView usability while adjusting layout offsets.

 Landscape layout adjustments:
 - ScrollView vertically dropped approximately 30% to avoid crowding at top.
 - Layout designed to work correctly in full-screen landscape and Split View.

 Portrait layout adjustments:
 - Smaller vertical drop (~10%) to keep list centered without wasting space.

 Development Notes:
 - Using window size alone (geo.size.width > geo.size.height) was unreliable
   in iPad Split View, so device orientation detection was added.

 Implementation assistance:
 - Layout troubleshooting, orientation detection, and ScrollView positioning
   strategy were developed with assistance from ChatGPT (OpenAI).
 - Final layout tuned and tested by Kevin Leckenby.

 Last refined: 2026
*/




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
 
            .navigationTitle("Friends")                 // ✅ add this
            .navigationBarTitleDisplayMode(.inline)     // ✅ and this
        
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.teal.opacity(0.85), for: .navigationBar)
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




