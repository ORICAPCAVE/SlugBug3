
//  SlugBug3
//
//
// -----------------------------------------------------------------------------
// MainMenuView
//
// Updated: January 22, 2026
//
// This view was refined with assistance from ChatGPT to resolve complex
// SwiftUI NavigationStack and hit-testing issues on iPad and iPhone.
//
// Key improvements included:
// - Fixing invisible destination views caused by transparent or off-screen layouts.
// - Preventing touch-blocking by disabling hit-testing on full-screen background layers.
// - Stabilizing navigation by ensuring shared ViewModels are reused across destinations.
// - Adding navigation titles and visual cues to confirm successful navigation.
// - Improving layout robustness across device sizes and orientations.
//
// These changes restored reliable menu navigation and prevented intermittent
// freezes and unresponsive UI states.
// -----------------------------------------------------------------------------





import SwiftUI
import Combine
import FirebaseAuth

struct MainMenuView: View {
    @EnvironmentObject var session: SessionVM
    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.horizontalSizeClass) private var hSize
    
    @StateObject private var vm = MainMenuVM()
    @StateObject private var playBugVM = PlayBugVM()
    @StateObject private var photosVM = PhotosVM()

    @State private var confirmLogout = false
    @State private var groupsX: CGFloat = 0

    
    var body: some View {
        NavigationStack(path: $vm.path) {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { print("✅ ZStack tap received") }
                Color.black.ignoresSafeArea()
                GeometryReader { geo in
                    let size = geo.size
    
                    let isPad = UIDevice.current.userInterfaceIdiom == .pad
                    let isLandscape = size.width > size.height

                    let contentMaxWidth: CGFloat =
                        isPad
                        ? (isLandscape ? 700 : 640)
                        : (isLandscape ? 520 : 360)
                    
                    let menuColumns: [GridItem] = {
                        if isPad {
                            return [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ]
                        }

                        return [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ]
                    }()

                    let isPadPortrait = isPad && !isLandscape
                    let isCompactLandscape = (size.width > size.height) && (hSize == .compact)
                    let isIPhonePortrait  = !isPad && !isLandscape
                    let isIPhoneLandscape = !isPad && isLandscape
                    let isIPadLandscape = isPad && (size.width > size.height)
                    let isIPadPortrait  = isPad && (size.width < size.height)

                    let topButtonsYOffset: CGFloat = isLandscape ? 0 : 55
                    let topButtonsXOffset: CGFloat = isPad && isLandscape ? 0.03 : 0
                    let middleButtonsXOffset: CGFloat = isPad && isLandscape ? 0.02 : 0
                    let topButtonWidth: CGFloat? = isPad ? 260 : nil
                    let topButtonsSpacing: CGFloat =
                        isPad ? 24 : (isLandscape ? 20 : 12)
                    
                   
                    Image("slugbug1")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(isPad ? 1.0 : 0.94)
                        .frame(
                            width: geo.size.width * 1.15,
                            height: geo.size.height * 1.15,
                            alignment: .center
                        )
                        .offset(
                            x: (!isPad && !isLandscape) ? -geo.size.width * 0.05 : 0,
                            y: (!isPad && !isLandscape) ? -geo.size.height * 0.03 : 0
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10)
                        {
                            HStack(spacing: topButtonsSpacing) {
                                Button("Slug Bugs") { vm.tapScore() }
                                    .buttonStyle(.borderedProminent)
                                    .frame(maxWidth: .infinity)
                                    .frame(width: topButtonWidth)
                                
                                Button {
                                    print("✅ Logout button tapped")
                                    confirmLogout = true
                                } label: {
                                    Text("Log Out")
                                        .font(.headline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog("Sign out?", isPresented: $confirmLogout) {
                                    Button("Log out", role: .destructive) {
                                        print("✅ Confirmed logout")
                                        session.signOut(resetLanding: true)
                                    }
                                    Button("Cancel", role: .cancel) {}
                                }
                            }
                            
                            .frame(maxWidth: contentMaxWidth)
                            .frame(maxWidth: .infinity, alignment: isLandscape ? .center : .leading)
                            .padding(.top, isLandscape ? 20 : 65)
                            .padding(.horizontal, 15)
                            .offset(x: topButtonsXOffset, y: topButtonsYOffset)

                            if isPadPortrait {
                                Spacer().frame(height: 80)
                            }

                            Spacer().frame(height: (size.width > size.height) ? 18 : 34)

                            if isIPhonePortrait {
                                Spacer().frame(height: 20)
                            }
                            
                            LazyVGrid(columns: menuColumns, spacing: 16) {
                                menuButton("Friends")  { vm.tapFriends() }
                                menuButton("Pictures") { vm.tapPictures() }
                            }
                            
                            
                            Spacer().frame(
                                height: isIPhonePortrait ? 28 : (isLandscape ? 18 : 34)
                            )
                            
                            
                            LazyVGrid(columns: menuColumns, spacing: 16) {
                                menuButton("Rules")  { vm.tapRules() }
                                menuButton("Tribute") { vm.tapTribute() }
                            }
                            
                        }
                        .frame(maxWidth: contentMaxWidth)
                        .frame(maxWidth: .infinity, alignment: isLandscape ? .center : .leading)
                        .padding(.top, isLandscape ? 20 : 65)
                        .padding(.horizontal, 16)
                        .offset(x: middleButtonsXOffset, y: topButtonsYOffset)

                        if isPadPortrait {
                            Spacer().frame(height: 80)
                        }

                        Spacer(
                            minLength: isIPhonePortrait
                            ? 20
                            : isIPhoneLandscape
                            ? 20
                            : 120
                        )

                        if isIPhonePortrait {
                            Spacer().frame(height: 30)
                        }
                        
                        
                        menuButton("Let’s Go") { vm.tapLetsGo() }
                        
                        menuButton("About") { vm.tapAbout() }
                            .buttonStyle(.borderedProminent)

                        Spacer(minLength: 24)
                    }
                    
                    .safeAreaInset(edge: .top){
                        Color.clear.frame(height: 1)
                    }
                    
                    
                    .frame(minHeight: geo.size.height)
                }
                
                
            }
            .navigationDestination(for: MainMenuVM.Route.self) { route in
                switch route {
                case .rules:    RulesView()
                case .tribute:  TributeView()
                case .friends:  FriendsView(vm: FriendsVM())
                case .pictures: PhotosView(vm: photosVM)
                case .score:    ScoreView(onHome: { vm.goHome() })
                case .play:     PlayBugView(vm: playBugVM)
                case .login:    LoginView()
                case .about:    AboutView()
                }
                
            }
            .confirmationDialog("Sign out?", isPresented: $confirmLogout) {
                Button("Log out", role: .destructive) { session.signOut(resetLanding: true) }
                Button("Cancel", role: .cancel) {}
            }
            .task(id: session.user?.uid) {
                vm.bind(session)
            }
            
        
            
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
           
            
        }
    }
    
    
    // MARK: - Helpers
    
    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 56)
    }
    
   

    
    private func isLandscape(_ size: CGSize) -> Bool {
        size.width > size.height
    }
    
    private struct ButtonAnchorKey: PreferenceKey {
        static var defaultValue: [String: Anchor<CGRect>] = [:]
        static func reduce(value: inout [String : Anchor<CGRect>],
                           nextValue: () -> [String : Anchor<CGRect>]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }
}
