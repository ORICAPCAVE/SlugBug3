import Foundation
import Combine

@MainActor
final class AchievementsVM: ObservableObject {
    @Published var lastTierReported: Int = UserDefaults.standard.integer(forKey: "lastTierReported")

    private let service = AchievementsService()
    private let auth = AuthService()

    static let tiers = [10, 50, 100, 1000]

    func checkAndReport(total: Int, playerName: String) async {
        // Find the highest tier newly reached
        guard let target = Self.tiers.filter({ total >= $0 && $0 > lastTierReported }).max() else { return }

        // Update local state & persist
        lastTierReported = target
        UserDefaults.standard.set(target, forKey: "lastTierReported")

        // Prepare payload
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        let uid = auth.currentUID()

        // Fire-and-forget is OK; we ignore errors for now
        guard let id = uid else {
            // decide how you want to handle “no uid” (silent return, error, or ensure sign-in)
            return
        }
        try? await service.report(uid: id, name: playerName, tier: target, ts: ts)
    }
}
