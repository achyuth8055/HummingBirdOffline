//
//  MailComposerView.swift
//  HummingBirdOffline
//
//  SwiftUI wrapper for MFMailComposeViewController

import SwiftUI
import MessageUI

struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    let recipients: [String]
    let subject: String
    let body: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
            
            if let error = error {
                print("Mail composer error: \(error.localizedDescription)")
            }
        }
    }
}
