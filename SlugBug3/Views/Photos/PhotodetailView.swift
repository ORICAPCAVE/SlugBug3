//
//  PhotodetailView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 12/10/25.
//
import SwiftUI

struct PhotoDetailView: View {
    let photo: BugPhoto

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer(minLength: 0)

                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding()

                VStack(spacing: 4) {
                    Text(photo.createdAt, style: .date)
                    Text(photo.createdAt, style: .time)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                if let scoreId = photo.scoreId {
                    Text("Linked Buggy score: \(scoreId)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                } else {
                    Text("No specific score linked")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                if photo.uploaded {
                    Label("Uploaded to competition", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .padding(.top, 8)
                } else {
                    Label("Not uploaded yet", systemImage: "icloud.slash")
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .navigationTitle("Buggy Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

