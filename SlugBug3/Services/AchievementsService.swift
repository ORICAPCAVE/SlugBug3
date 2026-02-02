import Foundation

final class AchievementsService {
// Configure this to your Hostinger endpoint
private let endpoint = URL(string: "https://steamintegrator.net/api/slugbug/achievement")!

struct Payload: Codable { let uid: String; let name: String; let tier: Int; let ts: Int64 }

func report(uid: String, name: String, tier: Int, ts: Int64) async throws {
var req = URLRequest(url: endpoint)
req.httpMethod = "POST"
req.setValue("application/json", forHTTPHeaderField: "Content-Type")
req.httpBody = try JSONEncoder().encode(Payload(uid: uid, name: name, tier: tier, ts: ts))
let (data, resp) = try await URLSession.shared.data(for: req)
guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
throw ServiceError.invalidResponse
}
// Optionally decode a response object here if your API returns one
_ = data
}
}
