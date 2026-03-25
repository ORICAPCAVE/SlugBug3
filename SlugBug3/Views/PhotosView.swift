//
// // PhotosView.swift
// SlugBug
//
// Created by Kevin Leckenby, Leckenby & Associates LLC
// Enhanced with assistance from ChatGPT (OpenAI)
//
// Purpose:
// Provides the user interface for capturing, viewing, sharing, uploading,
// and deleting Buggy photos. Displays a scrollable photo library, supports
// fullscreen detail viewing, sharing, and Firebase upload status.
//
// Recent Updates (2026-01):
// - Removed split (left/right) layout in favor of a unified stacked design.
// - Implemented fully responsive layout for iPhone and iPad in both
//   portrait and landscape orientations.
// - Added device-specific and orientation-aware spacing controls to ensure
//   the capture button and library are always reachable.
// - Refined capture guide box sizing (smaller on iPhone, larger on iPad).
// - Restored and centralized sheet presentations for camera capture,
//   photo library selection, sharing, and detail views.
// - Ensured compatibility with iOS 16+ (PhotosPicker onChange fix).
// - Improved Preview reliability by aligning navigation behavior with
//   real-device presentation.
//
// Notes:
// - Photo capture is integrated via a system camera picker.
// - Photo library access uses PhotosPicker (iOS 16+).
// - Photos are stored locally and optionally uploaded to Firebase Storage.
// - Each image can be linked to a Buggy score for verification.
// - Photos can be shared, viewed fullscreen, or permanently deleted
//   from both device storage and cloud storage.

import UIKit
import SwiftUI
import Combine
import PhotosUI

struct PhotosView: View {
    
    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.dismiss) private var dismiss

    private func onBack() {
        dismiss()
    }
    
    @ObservedObject var vm: PhotosVM
    @State private var selectedItem: PhotosPickerItem?
    
    @State private var activeSheet: ActiveSheet?
    
    
    
    @State private var photoToDelete: BugPhoto?
    
    private enum ActiveSheet: Identifiable {
        case camera
        case library
        case share(BugPhoto)
        case detail(BugPhoto)
        
        var id: String {
            switch self {
            case .camera: return "camera"
            case .library: return "library"
            case .share(let p): return "share-\(p.id)"
            case .detail(let p): return "detail-\(p.id)"
            }
        }
    }
    var body: some View {
        ZStack {
            Color.green.opacity(0.2)
                .onAppear { print("✅ PhotosView appeared") }
            Image("slugbug1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // MARK: - Adaptive Layout
            //
            // This view uses GeometryReader to implement a unified stacked layout
            // that adapts across iPhone and iPad devices in both portrait and
            // landscape orientations.
            //
            // Design decisions:
            // - A single vertical ScrollView is used to guarantee reachability
            //   of the capture button and photo library on short landscape screens.
            // - Device- and orientation-aware spacing is applied via computed
            //   top spacers instead of split column layouts.
            // - Capture guide sizing is reduced on iPhone to preserve vertical space,
            //   while remaining larger on iPad for improved visibility.
            // - All sheet presentations are attached at the top-level view to
            //   avoid lifecycle and hit-testing issues inside nested containers.
            
            GeometryReader { geo in
                let isLandscape =
                (UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)?
                    .interfaceOrientation.isLandscape ?? (geo.size.width > geo.size.height)
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                let isNarrowWindow = geo.size.width < 700
                // ✅ Your two knobs (percent of screen height)
                let iPhoneDropPct: CGFloat = 0.20   // 20% down on iPhone
                let iPadDropPct: CGFloat   = 0.20   // 45% down on iPad
                
                let deviceDrop = geo.size.height * (isPad ? iPadDropPct : iPhoneDropPct)
                let outerPad: CGFloat = 12
                
                // Fonts / sizes
                let titleFont: Font = isLandscape ? .title2.bold() : .largeTitle.bold()
                let cameraSize: CGFloat = 80
                let iconSize: CGFloat = isLandscape ? 32 : 48
                
                // Capture box height: responsive, but with sensible caps
                let captureBoxHeight: CGFloat = {
                    let available = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
                    let raw = available - 260  // space needed for title + button + library header, etc.
                    
                    // ✅ iPhone-only smaller caps
                    let capPhonePortrait: CGFloat = 170
                    let capPhoneLandscape: CGFloat = 110
                    
                    // iPad keeps your existing caps
                    let capPadPortrait: CGFloat = 240
                    let capPadLandscape: CGFloat = 150
                    
                    let cap: CGFloat = {
                        if isPad {
                            return isLandscape ? capPadLandscape : capPadPortrait
                        } else {
                            return isLandscape ? capPhoneLandscape : capPhonePortrait
                        }
                    }()
                    
                    // min can also be smaller on iPhone so it can compress more if needed
                    let minH: CGFloat = isPad ? 120 : 90
                    
                    return max(minH, min(cap, raw))
                }()
                
                
                // Global top spacing:
                // - big in iPad landscape
                // - small in iPhone landscape
                // - controllable in portrait
                let extraTop: CGFloat = {
                    if isPad && isLandscape && !isNarrowWindow {
                        return (geo.size.height * 0.62).clamped(to: 380...560)   // fullscreen iPad landscape
                    } else if isPad && isLandscape && isNarrowWindow {
                        return (geo.size.height * 0.18).clamped(to: 90...220)    // split iPad landscape (smaller)
                    } else if isPad {
                        return (geo.size.height * 0.18).clamped(to: 90...220)
                    } else if isLandscape {
                        return (geo.size.height * 0.10).clamped(to: 18...60)
                    } else {
                        return 16
                    }
                }()
                
                // ✅ Portrait-only "move up/down" knob (does NOT affect landscape)
                let portraitLift: CGFloat = 40  // increase to move portrait UP more
                let globalLift = geo.size.height * 0.10   // 🔧 move UP 10%
                let baseTop = (geo.safeAreaInsets.top + outerPad + extraTop + deviceDrop
                               - (isLandscape ? 0 : portraitLift))
                
                let cappedTop = baseTop.clamped(to: isPad ? 0...620 : 0...260)
                
                let topSpacerHeight = max(0, cappedTop - geo.size.height * 0.10) // ✅ always moves
                
                
                // ... now use topSpacerHeight here:
                // Spacer().frame(height: topSpacerHeight)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isLandscape ? 10 : 16) {
                        
                        // ✅ Use the computed top spacer (NOT a hardcoded extraTop here)
                        Spacer().frame(height: topSpacerHeight)
                        
                        Text("Buggy Photos")
                            .font(titleFont)
                            .foregroundColor(.white)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.black.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(style: StrokeStyle(lineWidth: 3, dash: [10]))
                                        .foregroundColor(.yellow)
                                )
                                .frame(height: captureBoxHeight)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: iconSize))
                                    .foregroundColor(.yellow)
                                
                                Text("Center the Volkswagen")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                
                                if !isLandscape {
                                    Text("Tap the button when you see a Bug")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.subheadline)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal, 12)
                        
                        Button {
                            print("CAPTURE TAPPED ✅")
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                activeSheet = .camera
                            } else {
                                activeSheet = .library
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.9))
                                    .frame(width: cameraSize, height: cameraSize)
                                
                                Circle()
                                    .stroke(.black, lineWidth: 2)
                                    .frame(width: cameraSize + 8, height: cameraSize + 8)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Buggy Library")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if vm.photos.isEmpty {
                                Text("No photos yet. Spot a Bug and tap the button!")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.headline)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(vm.photos) { photo in
                                            photoCard(photo)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        
                        // ✅ Bottom padding should ONLY be safe area + outer pad (not extraTop)
                        Spacer().frame(height: geo.safeAreaInsets.bottom + outerPad)
                    }
                    .padding(.horizontal, outerPad)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                
                
            }
            
            
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        .toolbar {
            // ✅ Back button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.white)
                }
            }
            
            // ✅ Center title
            ToolbarItem(placement: .principal) {
                Text("Buggy Photos")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        // Put this RIGHT AFTER the closing brace of your outer ZStack (before the final closing brace of body)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraPicker { image in
                    vm.handleCapturedImage(image)
                    activeSheet = nil
                }
            case .library:
                PhotoLibraryPicker { image in
                    vm.handleCapturedImage(image)
                    activeSheet = nil
                }
            case .share(let photo):
                ShareSheet(items: [photo.image])
            case .detail(let photo):
                BugPhotoDetailView(photo: photo)
            }
        }
        .alert("Delete photo?", isPresented: Binding(
            get: { photoToDelete != nil },
            set: { if !$0 { photoToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let p = photoToDelete { vm.delete(photo: p) }
                photoToDelete = nil
            }
            Button("Cancel", role: .cancel) { photoToDelete = nil }
        } message: {
            Text("This can’t be undone.")
        }
    }
    





    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    struct BugPhotoDetailView: View {
        let photo: BugPhoto
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                .navigationTitle("Bug Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    struct PhotoLibraryPicker: View {
        var onPicked: (UIImage) -> Void

        @Environment(\.dismiss) private var dismiss
        @State private var item: PhotosPickerItem?

        var body: some View {
            VStack(spacing: 16) {
                Text("Pick a photo")
                    .font(.headline)

                PhotosPicker(selection: $item, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .onChange(of: item) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onPicked(image)
                        dismiss()
                    }
                }
            }
        }
    }


    
    
    // MARK: - Photo card
    
    
    @ViewBuilder
    private func photoCard(_ photo: BugPhoto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 100)
                    .clipped()
                    .cornerRadius(12)
                
                if photo.uploaded {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.green)
                        .padding(4)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                        .padding(4)
                }
            }
            
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.6), lineWidth: 1)
            )
            .onTapGesture {
                activeSheet = .detail(photo)
            }
            
            Text(photo.createdAt, style: .date)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
            
            if let scoreId = photo.scoreId {
                Text("Score: \(scoreId)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HStack(spacing: 6) {
                Button {
                    activeSheet = .share(photo)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button {
                    vm.upload(photo: photo)
                } label: {
                    Label(photo.uploaded ? "Uploaded" : "Upload",
                          systemImage: photo.uploaded ? "checkmark.seal" : "icloud.and.arrow.up")
                    .font(.caption2)
                }
                .buttonStyle(.bordered)
                
                Button(role: .destructive) {
                    photoToDelete = photo
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(8)
        .background(.black.opacity(0.4))
        .cornerRadius(14)
        
    }
    
    
  

}
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#if DEBUG
#Preview("iPhone") {
    NavigationStack {
        PhotosView(vm: PhotosVM.preview)
    }
}

#Preview("iPad") {
    NavigationStack {
        PhotosView(vm: PhotosVM.preview)
    }
}
#endif

// -----------------------------------------------------------------------------
// Credits
// -----------------------------------------------------------------------------
// Portions of the adaptive layout strategy, SwiftUI sheet management,
// PhotosPicker integration, and preview compatibility refinements
// were developed with assistance from ChatGPT (OpenAI) during iterative
// debugging and device testing.
//
// All final design decisions, implementation, and integration
// remain the work of Kevin Leckenby, Leckenby & Associates LLC.
// -----------------------------------------------------------------------------
