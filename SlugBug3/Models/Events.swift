//
//  Events.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 10/13/25.
//
// Models/Events.swift
import Foundation

/// A small increment event when someone says "bug" or taps +1.
public struct BugHitEvent: Codable, Sendable {
    public let id: String
    public let ts: Int64
    public let count: Int
}

/// A full SlugBug (8 hits) event.
public struct SlugBugEvent: Codable, Sendable {
    public let id: String
    public let ts: Int64
    public let count: Int // always 8
}

