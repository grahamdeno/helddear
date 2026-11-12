import MessageUI
import SwiftUI
import UIKit

/// The system message sheet. It reports sent, cancelled or failed; sent means queued for delivery.
struct MessageComposer: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    var image: UIImage?
    var onFinish: (MessageComposeResult) -> Void

    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        if let image, MFMessageComposeViewController.canSendAttachments(),
           let data = image.jpegData(compressionQuality: 0.85) {
            vc.addAttachmentData(data, typeIdentifier: "public.jpeg", filename: "photo.jpg")
        }
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void
        init(onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish(result)
        }
    }
}

/// The standard share sheet, used when Messages isn't available on this phone.
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var onFinish: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in onFinish(completed) }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
