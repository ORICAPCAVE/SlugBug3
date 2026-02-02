//
//  Score.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 10/9/25.
//
import FirebaseDatabase

struct Score: Identifiable, Equatable, Hashable {
    let id: String
    let dateLabel: String
    let ts: Int64
    let note: String?
    let score: Int?
    let type: String?

    init(id: String, dict: [String: Any]) {
        let tsNum   = (dict["ts"] as? NSNumber)?.int64Value
        let whenIso = dict["whenIso"] as? String
        let dateStr = dict["date"] as? String
        self.note   = dict["note"] as? String
        self.score  = (dict["score"] as? NSNumber)?.intValue
        self.type   = dict["type"] as? String

        self.ts = Self.normalizeTs(tsNum: tsNum, whenIso: whenIso, dateStr: dateStr)
        self.dateLabel = Self.makeDateLabel(ts: self.ts, dateStr: dateStr)

        self.id = id
    }

    // MARK: - Private helpers (scoped to the model)

    private static func normalizeTs(tsNum: Int64?, whenIso: String?, dateStr: String?) -> Int64 {
        if var t = tsNum {
            if t < 1_000_000_000_000 { t *= 1000 } // seconds → ms
            return t
        }
        if let iso = whenIso, let t = parseISO(iso) { return t }
        if let d = dateStr, let t = parseShortDate(d) { return t }
        return Int64(Date().timeIntervalSince1970 * 1000) // fallback: now
    }

    private static func makeDateLabel(ts: Int64, dateStr: String?) -> String {
        if let d = dateStr, !d.isEmpty { return d }
        let d = Date(timeIntervalSince1970: TimeInterval(ts)/1000)
        return Self.shortFmt.string(from: d)
    }

    private static func parseISO(_ s: String) -> Int64? {
        if let d = Self.isoFmtFS.date(from: s) ?? Self.isoFmt.date(from: s) {
            return Int64(d.timeIntervalSince1970 * 1000)
        }
        return nil
    }

    private static func parseShortDate(_ s: String) -> Int64? {
        Self.shortFmt.date(from: s).map { Int64($0.timeIntervalSince1970 * 1000) }
    }

    // MARK: - Cached formatters
    private static let shortFmt: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFmtFS: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
#if DEBUG
extension Score {
    static var previewSamples: [Score] {
        [
            Score(id: "-P1", dict: ["date": "2026-01-12", "ts": 1768195200000, "score": 8, "type": "SlugBug"]),
            Score(id: "-P2", dict: ["date": "2026-01-11", "ts": 1768108800000, "score": 6]),
            Score(id: "-P3", dict: ["date": "2025-09-03", "ts": 1756929064133]),
            Score(id: "-P4", dict: ["date": "2025-08-04"]), // no ts → model will derive
        ]
    }
}
#endif

