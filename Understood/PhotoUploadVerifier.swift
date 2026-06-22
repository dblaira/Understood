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
        let signedInByVerifier = !supabase.isAuthenticated
        var createdEntryId: String?

        do {
            if signedInByVerifier {
                try await supabase.signIn(email: testEmail, password: testPassword)
            }

            guard let userId = supabase.currentSession?.user.id.uuidString else {
                throw NSError(domain: "PhotoUploadVerifier", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing session"])
            }

            // Simulate an older text-only entry, then add a photo like EntryEditorView.saveEntry.
            let entry = try await supabase.createEntry(
                content: "Simulator photo upload verification",
                category: "Insight"
            )
            createdEntryId = entry.id
            try await supabase.updateEntry(id: entry.id, fields: [
                "headline": "photo upload test"
            ])
            log("created existing-style entry id=\(entry.id)")

            let image = verificationImage()

            let url = try await supabase.uploadEntryImage(
                image: image,
                userId: userId,
                entryId: entry.id,
                index: 0
            )
            log("uploaded url=\(url)")

            let uploaded = [EntryImage(url: url, isPoster: true, order: 0)]
            try await supabase.updateEntryImages(entryId: entry.id, images: uploaded)

            let refetched = try await supabase.fetchEntry(id: entry.id)
            log("refetch hasImages=\(refetched.hasImages) poster=\(refetched.posterImageUrl ?? "nil")")

            let feedEntries = try await supabase.fetchEntries(limit: 50)
            let inFeed = feedEntries.first(where: { $0.id == entry.id })
            log("feedHasImages=\(inFeed?.hasImages ?? false) feedPoster=\(inFeed?.posterImageUrl ?? "nil")")

            let (data, response) = try await URLSession.shared.data(from: URL(string: url)!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let decoded = UIImage(data: data), decoded.size.width > 1 else {
                throw NSError(domain: "PhotoUploadVerifier", code: 500, userInfo: [NSLocalizedDescriptionKey: "Poster URL not loadable"])
            }

            guard refetched.hasImages, inFeed?.hasImages == true else {
                throw NSError(domain: "PhotoUploadVerifier", code: 500, userInfo: [NSLocalizedDescriptionKey: "Entry missing displayable images after save"])
            }

            let marker = FileManager.default.temporaryDirectory.appendingPathComponent("photo_upload_verified.txt")
            try "OK\n\(url)\nentryId=\(entry.id)".write(to: marker, atomically: true, encoding: .utf8)
            log("PHOTO_UPLOAD_VERIFIED_OK entryId=\(entry.id)")
            await cleanup(supabase: supabase, entryId: createdEntryId, shouldSignOut: signedInByVerifier)
        } catch {
            let marker = FileManager.default.temporaryDirectory.appendingPathComponent("photo_upload_verified.txt")
            try? "FAIL\n\(error.localizedDescription)".write(to: marker, atomically: true, encoding: .utf8)
            log("PHOTO_UPLOAD_VERIFIED_FAIL error=\(error.localizedDescription)")
            await cleanup(supabase: supabase, entryId: createdEntryId, shouldSignOut: signedInByVerifier)
        }
    }

    private static func log(_ message: String) {
        print(message)
        fputs("\(message)\n", stderr)
    }

    private static func cleanup(supabase: SupabaseService, entryId: String?, shouldSignOut: Bool) async {
        if let entryId {
            try? await supabase.deleteEntry(id: entryId)
        }
        if shouldSignOut {
            try? await supabase.signOut()
        }
    }

    private static func verificationImage() -> UIImage {
        let size = CGSize(width: 240, height: 160)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            UIColor.systemYellow.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))

            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: size.width / 2, y: size.height / 2, width: size.width / 2, height: size.height / 2))

            let text = "OK"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 56),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }
}
#endif
