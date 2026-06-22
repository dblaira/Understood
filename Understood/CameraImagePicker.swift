//
//  CameraImagePicker.swift
//  Understood
//
//  Native camera bridge for SwiftUI capture and entry editing flows.
//

import AVFoundation
import SwiftUI
import UIKit

enum CameraAccess {
    /// `nil` when access is granted; otherwise a user-facing denial message.
    static func requestIfNeeded() async -> String? {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return nil
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted
                ? nil
                : "Camera access is needed to attach photos. Enable it in Settings → Understood."
        case .denied, .restricted:
            return "Camera access is off. Enable it in Settings → Understood → Camera."
        @unknown default:
            return "Camera is not available right now."
        }
    }

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            parent.dismiss()
            DispatchQueue.main.async {
                self.parent.onComplete(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
            DispatchQueue.main.async {
                self.parent.onComplete(nil)
            }
        }
    }
}

extension UIImage {
    /// Camera photos often arrive rotated; normalize before preview and upload.
    func uprightOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
