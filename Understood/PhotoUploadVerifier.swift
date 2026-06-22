//
//  PhotoUploadVerifier.swift
//  Understood
//
//  DEBUG-only automated check for simulator/CI: signs in, uploads a photo, updates entry.
//

#if DEBUG
import UIKit
import Auth

enum PhotoUploadVerifier {
    private static let testEmail = "cursor.photo.test.1782017809@example.com"
    private static let testPassword = "CursorPhotoTest123!"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-VERIFY_PHOTO_UPLOAD")
            || ProcessInfo.processInfo.environment["VERIFY_PHOTO_UPLOAD"] == "1"
    }

    static func runIfNeeded() async {
        guard isEnabled else { return }

        let supabase = SupabaseService.shared
        do {
            if !supabase.isAuthenticated {
                try await supabase.signIn(email: testEmail, password: testPassword)
            }

            let entry = try await supabase.createEntry(
                content: "Simulator photo upload verification",
                category: "Insight"
            )

            let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { ctx in
                UIColor.systemBlue.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
            }

            guard let userId = supabase.currentSession?.user.id.uuidString else {
                throw NSError(domain: "PhotoUploadVerifier", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing session"])
            }

            let url = try await supabase.uploadEntryImage(
                image: image,
                userId: userId,
                entryId: entry.id,
                index: 0
            )

            let entryImage = EntryImage(url: url, isPoster: true, order: 0)
            try await supabase.updateEntryImages(entryId: entry.id, images: [entryImage])
            try await supabase.deleteEntry(id: entry.id)

            let marker = FileManager.default.temporaryDirectory.appendingPathComponent("photo_upload_verified.txt")
            try "OK\n\(url)".write(to: marker, atomically: true, encoding: .utf8)
            print("PHOTO_UPLOAD_VERIFIED_OK url=\(url)")
            fputs("PHOTO_UPLOAD_VERIFIED_OK\n", stderr)
        } catch {
            let marker = FileManager.default.temporaryDirectory.appendingPathComponent("photo_upload_verified.txt")
            try? "FAIL\n\(error.localizedDescription)".write(to: marker, atomically: true, encoding: .utf8)
            print("PHOTO_UPLOAD_VERIFIED_FAIL error=\(error.localizedDescription)")
            fputs("PHOTO_UPLOAD_VERIFIED_FAIL \(error.localizedDescription)\n", stderr)
        }
    }
}
#endif
