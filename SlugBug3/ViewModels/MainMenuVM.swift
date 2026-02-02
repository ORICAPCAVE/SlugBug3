//
/// -----------------------------------------------------------------------------
// MainMenuVM
//
// Updated: January 22, 2026
//
// This view model and navigation logic were refined with assistance from
// ChatGPT to resolve SwiftUI NavigationStack issues involving invisible
// destination views, hit-testing conflicts, and ViewModel lifecycle problems.
//
// Key fixes included:
// - Stabilizing navigation by preventing unintended path resets.
// - Ensuring destination views present with visible, opaque backgrounds.
// - Avoiding recreation of heavy ViewModels during navigation.
// - Improving debugging with onAppear and path change logging.
//
// These changes significantly improved navigation reliability on iPad and iPhone.
// -----------------------------------------------------------------------------

import SwiftUI
import Combine

@MainActor
final class MainMenuVM: ObservableObject {
    enum Route: Hashable { case rules, tribute, friends, pictures, score, play, login, about }
    @Published var path: [Route] = []
    
    @Published var showExitAlert = false

    func bind(_ session: SessionVM) {
        // Optional: clear nav on sign-out so you don't return into a deep stack
        session.$user
            .receive(on: RunLoop.main)
            .sink { [weak self] u in if u == nil { self?.path.removeAll() } }
            .store(in: &cancellables)
    }
    func tapPictures() {
            print("Appending pictures…")
            path.append(.pictures)
            print("Path now:", path)
        }
    func tapRules()    { path.append(.rules) }
    func tapTribute()  { path.append(.tribute) }
    func tapFriends()  { path.append(.friends) }
    //func tapPictures() { path.append(.pictures) }
    func tapScore()    { path.append(.score) }
    func tapLetsGo()   { path.append(.play) }
    func tapExit()     { showExitAlert = true }
    func goHome() {path.removeAll()}
    func tapAbout() { print("Appending about...")
        path.append((.about))}
    private var cancellables = Set<AnyCancellable>()
}
