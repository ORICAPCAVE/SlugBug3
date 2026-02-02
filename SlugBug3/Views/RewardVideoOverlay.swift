//
//  RewardVideoOverlay.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 11/20/25.
//
import SwiftUI
import AVKit
import AVFAudio

struct RewardVideoOverlay: View {
    var onDone: () -> Void        // called when video finishes
    var onFinished: () -> Void    // called when user closes

    @State private var endObserver: NSObjectProtocol?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 12) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(width: 500, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 12)
                } else {
                    VStack(spacing: 8) {
                        Text("SlugBug Reward").font(.title2.weight(.semibold))
                        Text("Video not found in app bundle.")
                            .font(.footnote).opacity(0.8)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                HStack(spacing: 12) {
                    Button {
                        player?.seek(to: .zero)
                        player?.play()
                    } label: {
                        Label("Replay", systemImage: "gobackward")
                    }
                    .buttonStyle(.borderedProminent)

                    Button { stopAndFinish() } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
        }
        .onAppear {
            // (Optional) ensure playback session so you hear the reward
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)

            setupPlayer()
            startHaptic()
        }
        .onDisappear {
            cleanupObserver()
            player?.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { stopAndFinish() }) {
                Label("Done", systemImage: "xmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 24).padding(.trailing, 20)
            .accessibilityLabel("Close reward")
        }
        .contentShape(Rectangle())
        .onTapGesture { stopAndFinish() }
    }

    private func setupPlayer() {
        // Debug: confirm the file is present
        if let path = Bundle.main.path(forResource: "slugbug12", ofType: "mp4") {
            print("Reward: found video at \(path)")
        } else {
            print("Reward: VIDEO NOT FOUND in bundle")
        }

        guard let url = Bundle.main.url(forResource: "slugbug12", withExtension: "mp4") else {
            return
        }

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p

        // Remove any previous observer
        cleanupObserver()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            onDone()           // only when video actually ends
        }

        p.seek(to: .zero)
        p.play()
    }

    private func stopAndFinish() {
        player?.pause()
        cleanupObserver()
        onFinished()
    }

    private func cleanupObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func startHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
}
