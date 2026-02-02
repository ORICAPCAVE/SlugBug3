//
//  PlayBugVM.swift
//  SlugBug
//
//  Created by Kevin Leckenby on November 20, 2025.
//  Concept, logic design, and speech recognition integration collaboratively developed with assistance from ChatGPT (OpenAI).
//  This view model coordinates live speech input, scoring, Firebase event commits,
//  and reward triggers when the player reaches milestone counts.
//tr
import Foundation
import Combine

@MainActor
final class PlayBugVM: ObservableObject {

    @Published var total: Int  { didSet { persist() } }
    @Published var buggyCount: Int { didSet { persist() } }
    @Published var isListening = false
    @Published var transcript = ""
    @Published var shouldShowAward = false
    @Published var showPostAwardToast = false

    private enum K {
        static let total = "slugbug.total"
        static let buggyCount = "slugbug.buggyCount"
    }

    private let auth = AuthService()
    private let db = RealtimeDBService()
    let speech = SpeechService()

    private var cancellables = Set<AnyCancellable>()

    // Legacy word-index tracker (kept for your existing logic)
    private var lastWordIndex = 0
    // NEW: robust whole-word match tracker
    private var lastMatchCount = 0

    // Precompiled whole-word regex: bug | buggy | slug | slugbug
    // \b ensures whole-word; (?:...) is non-capturing
    private let hitRegex = try! NSRegularExpression(pattern: #"\b(?:slugbug|buggy|bug|slug)\b"#, options: [.caseInsensitive])

    init() {
        // Load persisted values (defaults to 0)
        let d = UserDefaults.standard
        self.total = d.integer(forKey: K.total)
        self.buggyCount = d.integer(forKey: K.buggyCount)

        bindSpeech()
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(total, forKey: K.total)
        d.set(buggyCount, forKey: K.buggyCount)
    }

    func toggleListening() { isListening ? stop() : start() }

    func increment(by amount: Int = 1) {
        guard amount > 0 else { return }
        let old = buggyCount
        buggyCount = min(8, buggyCount + amount)
        total += max(0, buggyCount - old)
        if buggyCount >= 8 { commitSlugBug() }
    }

    func reset() {
        buggyCount = 0
        lastWordIndex = currentWordCount(in: transcript)
        lastMatchCount = currentMatchCount(in: transcript)
    }

    func commitSlugBug() {
        // Prevent triggering multiple reward overlays if called repeatedly
        guard !shouldShowAward else { return }

        guard let uid = auth.currentUID(), !uid.isEmpty else {
            print("commitSlugBug: missing uid")
            buggyCount = 0
            lastWordIndex = currentWordCount(in: transcript)
            lastMatchCount = currentMatchCount(in: transcript)
            return
        }

        let event = SlugBugEvent(
            id: UUID().uuidString,
            ts: Int64(Date().timeIntervalSince1970 * 1000),
            count: 8
        )

        Task {
            do {
                try await db.pushSlugBugEvent(event, for: uid)
                print("✅ SlugBug write ok: users/\(uid)/SlugBugs/\(event.id)")
            } catch {
                print("❌ SlugBug write FAILED:", error.localizedDescription)
            }
        }

        shouldShowAward = true  // <- trigger overlay once
        buggyCount = 0
        lastWordIndex = currentWordCount(in: transcript)
        lastMatchCount = currentMatchCount(in: transcript)
    }

    // In PlayBugVM
    func onRewardAppear() {
        speech.endListening()   // pause mic
    }

    func onRewardDismiss() {
        shouldShowAward = false
        do { try speech.beginListening() } catch {
            print("Resume mic failed:", error.localizedDescription)
        }
    }

    // Optional hook if you want to record completion separately
    var onRewardDone: (() -> Void)? = nil


    private func start() {
        do {
            try speech.beginListening()
            isListening = true
        } catch {
            isListening = false
            print("Speech start error:", error.localizedDescription)
        }
    }

    private func stop() {
        speech.endListening()
        isListening = false
    }


    // MARK: - Bindings

    private func bindSpeech() {
        // Reflect service recording state to UI
        speech.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] rec in self?.isListening = rec }
            .store(in: &cancellables)

        // Debounce + delta-count on transcript
        speech.$transcript
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] fullText in
                guard let self else { return }
                self.transcript = fullText
                self.consumeDelta(from: fullText)
            }
            .store(in: &cancellables)
    }

    // MARK: - Counting

    // NEW: robust delta using regex over the full transcript
    private func consumeDelta(from fullText: String) {
        let newCount = currentMatchCount(in: fullText)
        let delta = max(0, newCount - lastMatchCount)
        if delta > 0 {
            increment(by: delta)

            if let uid = auth.currentUID(), !uid.isEmpty {
                let event = BugHitEvent(
                    id: UUID().uuidString,
                    ts: Int64(Date().timeIntervalSince1970 * 1000),
                    count: delta
                )
                Task { try? await db.pushBugHitEvent(event, for: uid) }
            }
        }
        lastMatchCount = newCount

        // Keep legacy tracker in sync for your other logic
        lastWordIndex = currentWordCount(in: fullText)
    }

    private func currentWordCount(in text: String) -> Int {
        text.lowercased().split { !$0.isLetter }.count
    }

    private func currentMatchCount(in text: String) -> Int {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return hitRegex.numberOfMatches(in: text, options: [], range: range)
    }
}
