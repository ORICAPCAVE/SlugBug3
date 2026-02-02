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
    @State private var pendingDeleteIndex: Int?
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

                VStack(spacing: 0) {
                    if isLandscape {
                        landscapeBody(geo)
                    } else {
                        portraitBody(geo)
                    }
                }
            }

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
    private func landscapeBody(_ geo: GeometryProxy) -> some View {
        let windowW = min(geo.size.width * 0.82, 780)
        let windowH = max(220, geo.size.height * 0.75)

        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                friendsContent
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
        }
        .frame(width: windowW, height: windowH)
        .background(Color.black.opacity(0.25))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.yellow, lineWidth: 3))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func portraitBody(_ geo: GeometryProxy) -> some View {
        let navBarH: CGFloat = 44
        let topPad = geo.safeAreaInsets.top + navBarH + 12

        ScrollView {
            friendsContent
                .padding(.vertical, 16)
        }
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
                pendingDeleteIndex = index
                isShowingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Friends - Landscape") {
    NavigationStack {
        FriendsView(vm: .preview)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
    }
    .previewLayout(.fixed(width: 852, height: 393))
    
}




