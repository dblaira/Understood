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
    static func requestIfNeeded() async -> Result<Void, String> {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return .success(())
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted
                ? .success(())
                : .failure("Camera access is needed to attach photos. Enable it in Settings → Understood.")
        case .denied, .restricted:
            return .failure("Camera access is off. Enable it in Settings → Understood → Camera.")
        @unknown default:
            return .failure("Camera is not available right now.")
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
            parent.onComplete(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onComplete(nil)
            parent.dismiss()
        }
    }
}
