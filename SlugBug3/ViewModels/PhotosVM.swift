// PhotosVM.swift
// SlugBug
//
// Created by Kevin Leckenby, Leckenby & Associates LLC
// Enhanced with assistance from ChatGPT (OpenAI)
//
// Purpose:
// ViewModel responsible for managing Buggy photo data, including local
// persistence, metadata tracking, and Firebase Storage uploads. Acts as the
// single source of truth for the PhotosView UI.
//
// Responsibilities:
// - Persist captured photos to local storage with JSON-backed metadata.
// - Load and restore photos across app launches.
// - Track upload status and synchronize with Firebase Storage.
// - Support deletion from both local storage and cloud storage.
// - Associate photos with optional Buggy score identifiers.
//
// Recent Updates (2026-01):
// - Aligned public API with PhotosView capture and library pickers
//   (handleCapturedImage(_:)).
// - Improved in-memory and on-disk synchronization logic.
// - Hardened upload and delete flows with clearer error handling.
// - Verified compatibility with SwiftUI sheet-based presentation.
//
// Notes:
// - Images are stored as JPEG files in the app Documents directory.
// - Metadata is persisted in bug_photos.json using ISO-8601 dates.
// - Firebase uploads require an authenticated user session.

//
import Foundation
import UIKit
import FirebaseAuth
import FirebaseStorage
import Combine

final class PhotosVM: ObservableObject {

    @Published var photos: [BugPhoto] = []

    /// Set this from outside when you know which score this photo will verify.
    var currentScoreId: String?

    private let fileManager = FileManager.default
    private let metadataFilename = "bug_photos.json"

    private var docsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var metadataURL: URL {
        docsURL.appendingPathComponent(metadataFilename)
    }

    init() {
        print("✅ PhotosVM init")
            Task { await loadAsync() }    }

    // MARK: - Public API

    func handleCapturedImage(_ image: UIImage) {
        let id = UUID().uuidString
        var photo = BugPhoto(
            id: id,
            image: image,
            createdAt: Date(),
            note: nil,
            scoreId: currentScoreId,
            uploaded: false
        )

        // Save to disk
        saveToDisk(photo: photo)

        // Insert at top (newest first)
        photos.insert(photo, at: 0)
    }

    func upload(photo: BugPhoto) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No logged-in user; cannot upload.")
            return
        }

        guard let jpegData = photo.image.jpegData(compressionQuality: 0.9) else {
            print("⚠️ Could not create JPEG data.")
            return
        }

        let storage = Storage.storage()
        let ref = storage.reference()
            .child("users")
            .child(uid)
            .child("photos")
            .child("\(photo.id).jpg")

        ref.putData(jpegData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                print("❌ Upload failed: \(error)")
                return
            }

            print("✅ Uploaded Bug photo \(photo.id)")

            // Mark uploaded locally
            DispatchQueue.main.async {
                self?.markUploaded(photoID: photo.id)
            }
        }
    }

    // MARK: - Disk persistence

    private func saveToDisk(photo: BugPhoto) {
        // 1. Save image
        let filename = "\(photo.id).jpg"
        let fileURL = docsURL.appendingPathComponent(filename)

        guard let data = photo.image.jpegData(compressionQuality: 0.9) else {
            print("⚠️ Failed to create JPEG for \(photo.id)")
            return
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to write image file: \(error)")
        }

        // 2. Save / update metadata
        var records = loadRecords()
        let record = BugPhotoRecord(
            id: photo.id,
            filename: filename,
            createdAt: photo.createdAt,
            note: photo.note,
            scoreId: photo.scoreId,
            uploaded: photo.uploaded
        )
        // Remove any old record with same id
        records.removeAll { $0.id == photo.id }
        records.append(record)
        saveRecords(records)
    }

    private func loadFromDisk() {
        let records = loadRecords()
        var loaded: [BugPhoto] = []

        for record in records {
            let fileURL = docsURL.appendingPathComponent(record.filename)
            if let image = UIImage(contentsOfFile: fileURL.path) {
                let photo = BugPhoto(
                    id: record.id,
                    image: image,
                    createdAt: record.createdAt,
                    note: record.note,
                    scoreId: record.scoreId,
                    uploaded: record.uploaded
                )
                loaded.append(photo)
            }
        }

        // Newest first
        loaded.sort { $0.createdAt > $1.createdAt }

        DispatchQueue.main.async {
            self.photos = loaded
        }
    }

    private func loadRecords() -> [BugPhotoRecord] {
        guard fileManager.fileExists(atPath: metadataURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([BugPhotoRecord].self, from: data)
        } catch {
            print("❌ Failed to load metadata: \(error)")
            return []
        }
    }

    private func saveRecords(_ records: [BugPhotoRecord]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("❌ Failed to save metadata: \(error)")
        }
    }

    private func markUploaded(photoID: String) {
        // Update in-memory
        if let index = photos.firstIndex(where: { $0.id == photoID }) {
            photos[index].uploaded = true
        }

        // Update metadata on disk
        var records = loadRecords()
        if let rIndex = records.firstIndex(where: { $0.id == photoID }) {
            records[rIndex].uploaded = true
        }
        saveRecords(records)
    }
    func delete(photo: BugPhoto) {
        // 1. Delete image file + metadata
        var records = loadRecords()

        if let record = records.first(where: { $0.id == photo.id }) {
            // Delete image file
            let fileURL = docsURL.appendingPathComponent(record.filename)
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                print("❌ Failed to remove image file: \(error)")
            }
        }

        // Remove record from metadata list and save
        records.removeAll { $0.id == photo.id }
        saveRecords(records)

        // 2. Delete from Firebase Storage if it was uploaded
        if photo.uploaded, let uid = Auth.auth().currentUser?.uid {
            let storage = Storage.storage()
            let ref = storage.reference()
                .child("users")
                .child(uid)
                .child("photos")
                .child("\(photo.id).jpg")

            ref.delete { error in
                if let error = error {
                    print("⚠️ Failed to delete from Storage (may not exist): \(error)")
                } else {
                    print("✅ Deleted Bug photo \(photo.id) from Storage")
                }
            }
        }

        // 3. Remove from in-memory array so UI updates
        DispatchQueue.main.async {
            self.photos.removeAll { $0.id == photo.id }
        }
    }
    @MainActor
    func loadAsync() async {
        let loaded: [BugPhoto] = await Task.detached(priority: .userInitiated) { [docsURL, metadataURL, fileManager] in
            // --- local helpers so we can run off-main safely ---
            func loadRecords() -> [BugPhotoRecord] {
                guard fileManager.fileExists(atPath: metadataURL.path) else { return [] }
                do {
                    let data = try Data(contentsOf: metadataURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode([BugPhotoRecord].self, from: data)
                } catch {
                    print("❌ Failed to load metadata: \(error)")
                    return []
                }
            }

            let records = loadRecords()
            var loaded: [BugPhoto] = []
            loaded.reserveCapacity(records.count)

            for record in records {
                let fileURL = docsURL.appendingPathComponent(record.filename)
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    loaded.append(
                        BugPhoto(
                            id: record.id,
                            image: image,
                            createdAt: record.createdAt,
                            note: record.note,
                            scoreId: record.scoreId,
                            uploaded: record.uploaded
                        )
                    )
                }
            }

            loaded.sort { $0.createdAt > $1.createdAt }
            return loaded
        }.value

        self.photos = loaded
    }


}
#if DEBUG
extension PhotosVM {
    static var preview: PhotosVM {
        // If your PhotosVM requires dependencies, create “fake” ones here.
        // Replace this initializer with whatever PhotosVM actually uses.
        let vm = PhotosVM()

        // If you have an array like `photos` or `items`, seed it:
        // vm.photos = [
        //   BugPhoto(id: "1", localPath: "...", createdAt: Date(), note: "Test")
        // ]

        return vm
    }
}
#endif

