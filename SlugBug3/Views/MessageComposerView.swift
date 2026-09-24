//
//  MessageComposerView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 3/28/26.
//

import SwiftUI
import MessageUI

struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onComplete: (Bool) -> Void   // true if sent

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposerView

        init(parent: MessageComposerView) {
            self.parent = parent
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)

            switch result {
            case .sent:
                parent.onComplete(true)
            case .cancelled, .failed:
                parent.onComplete(false)
            @unknown default:
                parent.onComplete(false)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // no-op
    }

    static func canSendText() -> Bool {
        MFMessageComposeViewController.canSendText()
    }
}
