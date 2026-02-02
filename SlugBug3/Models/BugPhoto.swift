//
//  BugPhoto.swift
//  SlugBug
//
//  Created by Kevin Leckenby, Leckenby & Associates LLC
//  Enhanced with assistance from ChatGPT (OpenAI)
//
//  Purpose:
//  Defines models for Buggy photo data used in UI and persistent storage.
//
//  Notes:
//  - BugPhoto is the UI-facing model (contains UIImage).
//  - BugPhotoRecord is a disk-safe Codable representation.
//

import UIKit

/// UI model used by the views
struct BugPhoto: Identifiable, Hashable {
    let id: String              // UUID string
    let image: UIImage
    let createdAt: Date
    var note: String?
    var scoreId: String?        // which Buggy score this verifies
    var uploaded: Bool          // "Uploaded to competition?" flag
}

/// Persistent metadata (no UIImage here)
struct BugPhotoRecord: Codable {
    let id: String
    let filename: String
    let createdAt: Date
    var note: String?
    var scoreId: String?
    var uploaded: Bool
}
