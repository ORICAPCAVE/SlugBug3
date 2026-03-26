//
//  PhotosVM.swift
//  SlugBug3
//
//  Created by Leckenby and Associates LLC
//  Enhanced with assistance from ChatGPT (OpenAI)
//
//  Purpose:
//  ViewModel responsible for managing BugPhoto lifecycle including:
//  - Local persistence (disk storage + metadata JSON)
//  - Firebase Cloud Storage uploads (user-scoped photo storage)
//  - Realtime Database metadata tracking (photosMeta)
//  - Upload state tracking (uploaded flag)
//  - Exporting and deletion of photos
//
//  Key Enhancements (March 2026):
//  - Integrated Firebase Storage upload pipeline (users/{uid}/photos/{photoId}.jpg)
//  - Added metadata persistence to Realtime Database (photosMeta node)
//  - Implemented upload success handling with markUploaded()
//  - Ensured delete flow syncs local disk, Firebase Storage, and metadata
//  - Added runtime diagnostics for bucket/path debugging
//  - Fixed structural issue (extra brace) that broke class scope
//  - Cleaned duplicate imports and improved code organization
//
//  Notes:
//  This ViewModel now supports a hybrid storage model:
//  - Local disk for fast access
//  - Firebase Storage for file persistence
//  - Realtime Database for structured metadata and future sync capabilities
//
import Foundation
import UIKit
import FirebaseAuth
import FirebaseStorage
import Combine
import FirebaseDatabase

final class PhotosVM: ObservableObject {
    @Published var exportURL: URL?
    @Published var showExporter = false
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
        Task { await loadAsync() }
    }

    // MARK: - Public API

    func handleCapturedImage(_ image: UIImage) {
        let id = UUID().uuidString
        let photo = BugPhoto(
            id: id,
            image: image,
            createdAt: Date(),
            note: nil,
            scoreId: currentScoreId,
            uploaded: false
        )

        saveToDisk(photo: photo)
        photos.insert(photo, at: 0)
    }

    func uploadToFirebase(photo: BugPhoto) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No logged-in user; cannot upload.")
            return
        }

        guard let jpegData = photo.image.jpegData(compressionQuality: 0.9) else {
            print("⚠️ Could not create JPEG data.")
            return
        }

        let storage = Storage.storage()
        print("✅ bucket:", storage.reference().bucket)

        let ref = storage.reference()
            .child("users")
            .child(uid)
            .child("photos")
            .child("\(photo.id).jpg")

        print("⬆️ Starting upload to:", ref.fullPath)
        print("⬆️ Bytes:", jpegData.count)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(jpegData, metadata: metadata) { [weak self] metadata, error in
            if let error = error as NSError? {
                print("❌ putData failed at path:", ref.fullPath)
                print("❌ code:", error.code)
                print("❌ message:", error.localizedDescription)
                return
            }
            ref.putData(jpegData, metadata: metadata) { [weak self] metadata, error in
                if let error = error as NSError? {
                    print("❌ putData failed at path:", ref.fullPath)
                    print("❌ code:", error.code)
                    print("❌ message:", error.localizedDescription)
                    return
                }

                print("✅ Upload success:", metadata?.path ?? ref.fullPath)
                self?.markUploaded(photoID: photo.id)

                let dbRef = Database.database().reference()
                    .child("users")
                    .child(uid)
                    .child("photosMeta")
                    .child(photo.id)

                dbRef.setValue([
                    "id": photo.id,
                    "storagePath": ref.fullPath,
                    "uploaded": true,
                    "createdAt": ISO8601DateFormatter().string(from: Date())
                ])
            }

            print("✅ Upload success:", metadata?.path ?? ref.fullPath)
            self?.markUploaded(photoID: photo.id)
        }
    }

    // MARK: - Disk persistence

    private func saveToDisk(photo: BugPhoto) {
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

        var records = loadRecords()
        let record = BugPhotoRecord(
            id: photo.id,
            filename: filename,
            createdAt: photo.createdAt,
            note: photo.note,
            scoreId: photo.scoreId,
            uploaded: photo.uploaded
        )

        records.removeAll { $0.id == photo.id }
        records.append(record)
        saveRecords(records)
    }

    // ...rest of your methods stay here, still inside PhotosVM...

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
    func exportPhoto(photo: BugPhoto) {
        guard let data = photo.image.jpegData(compressionQuality: 0.9) else {
            print("⚠️ Could not create JPEG data.")
            return
        }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(photo.id).jpg")
        
        do {
            try data.write(to: url, options: .atomic)
            DispatchQueue.main.async {
                self.exportURL = url
                self.showExporter = true
            }
        } catch {
            print("❌ Could not prepare export file: \(error.localizedDescription)")
        }
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
            print("fullPath:", ref.fullPath)

            ref.delete { error in
                if let error = error as NSError? {
                    let message = error.localizedDescription.lowercased()

                    if message.contains("does not exist") || message.contains("object") {
                        print("ℹ️ File already missing in Firebase for \(photo.id)")
                    } else {
                        print("⚠️ Failed to delete from Storage: \(error.localizedDescription)")
                    }
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

