//
//  PhotoDetailView.swift
//  SlugBug
//
//  Created by Kevin Leckenby, Leckenby & Associates LLC
//  Enhanced with assistance from ChatGPT (OpenAI)
//
//  Purpose:
//  Displays a Buggy photo in full screen.
//  Shows capture date, linked Buggy score ID, and upload status for verification.
//
//  Notes:
//  - Used when tapping any photo in the Buggy library.
//  - Designed to support competitive verification use.
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
