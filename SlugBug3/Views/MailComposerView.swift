//
//  MailComposerView.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 3/28/26.
//

import SwiftUI
import MessageUI

struct MailComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    let onComplete: (Bool) -> Void   // true if sent

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)

            switch result {
            case .sent:
                parent.onComplete(true)
            case .saved, .cancelled, .failed:
                parent.onComplete(false)
            @unknown default:
                parent.onComplete(false)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }

    static func canSendMail() -> Bool {
        MFMailComposeViewController.canSendMail()
    }
}
