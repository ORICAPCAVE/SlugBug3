import SwiftUI

struct RootView: View {
    @StateObject private var friendsVM = FriendsVM()
    @StateObject private var playBugVM = PlayBugVM()
    @StateObject private var achievementsVM = AchievementsVM()
    @StateObject private var photosVM = PhotosVM()

    var body: some View {
        TabView {
            PlayBugView(vm: playBugVM)
                .tabItem { Label("Play", systemImage: "mic.circle") }

            FriendsView(vm: friendsVM)
                .tabItem { Label("Friends", systemImage: "person.2") }

            AchievementsView(vm: achievementsVM)
                .tabItem { Label("Achieve", systemImage: "star.circle") }

            PhotosView(vm: photosVM)
                .tabItem { Label("Photos", systemImage: "photo.on.rectangle") }
        }
    }
}

#Preview {
    RootView()
}
