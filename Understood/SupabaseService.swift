//
//  SupabaseService.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import Foundation
import Supabase
import UIKit

/// Shared Supabase client for the entire app
/// Handles authentication and database operations
@Observable
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient
    var currentSession: Session?
    var isAuthenticated: Bool {
        currentSession != nil
    }

    /// Base URL for the Vercel API routes
    static let apiBaseURL = "https://understood.app"

    private init() {
        let supabaseURL = URL(string: "https://wqdacfrzurhpsiuvzxwo.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxZGFjZnJ6dXJocHNpdXZ6eHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3MzQyNjcsImV4cCI6MjA3NzMxMDI2N30.IuiHf6TYw2UhB8Rk4FPTdySTg41_ndB0h1vqkJEYqmE"

        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )

        // Check for existing session on init
        Task {
            await checkSession()
        }
    }

    // MARK: - Authentication

    /// Check if there's an active session
    func checkSession() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.currentSession = session
            }
        } catch {
            await MainActor.run {
                self.currentSession = nil
            }
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        await MainActor.run {
            self.currentSession = session
        }
    }

    /// Sign out
    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run {
            self.currentSession = nil
        }
    }

    // MARK: - Data Fetching

    /// Fetch journal entries (stories) for the current user
    func fetchEntries(limit: Int = 20) async throws -> [Entry] {
        let entries: [Entry] = try await client
            .from("entries")
            .select()
            .eq("entry_type", value: "story")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return entries
    }

    /// Fetch a single entry by ID
    func fetchEntry(id: String) async throws -> Entry {
        let entry: Entry = try await client
            .from("entries")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return entry
    }

    /// Fetch beliefs (entries with entry_type = 'connection')
    func fetchBeliefs(limit: Int = 50) async throws -> [Entry] {
        let beliefs: [Entry] = try await client
            .from("entries")
            .select()
            .eq("entry_type", value: "connection")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return beliefs
    }

    /// Fetch entries connected to a specific belief via source_entry_id
    func fetchConnectedEntries(beliefId: String) async throws -> [Entry] {
        let entries: [Entry] = try await client
            .from("entries")
            .select()
            .eq("source_entry_id", value: beliefId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return entries
    }

    /// Fetch all entries regardless of type (used for actions, pinned, etc.)
    func fetchAllEntries(limit: Int = 200) async throws -> [Entry] {
        let entries: [Entry] = try await client
            .from("entries")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return entries
    }

    /// Fetch the user's featured entry (for story hero)
    func fetchFeaturedEntry() async throws -> Entry? {
        let entries: [Entry] = try await client
            .from("entries")
            .select()
            .eq("featured", value: true)
            .limit(1)
            .execute()
            .value
        return entries.first
    }

    /// Fetch all pinned entries (pinned_at is not null)
    func fetchPinnedEntries() async throws -> [Entry] {
        let entries: [Entry] = try await client
            .from("entries")
            .select()
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value
        return entries.filter { $0.isPinned }
            .sorted { ($0.pinnedAt ?? "") > ($1.pinnedAt ?? "") }
    }

    /// Fetch actions (entries with entry_type = 'action')
    func fetchActions(limit: Int = 200) async throws -> [Entry] {
        let entries: [Entry] = try await client
            .from("entries")
            .select()
            .eq("entry_type", value: "action")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return entries
    }

    // MARK: - Entry Actions

    /// Delete an entry by ID
    func deleteEntry(id: String) async throws {
        try await client
            .from("entries")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Toggle pinned state using pinned_at timestamp
    func togglePin(id: String, currentlyPinned: Bool) async throws {
        let payload = PinUpdatePayload(
            pinnedAt: currentlyPinned ? nil : ISO8601DateFormatter().string(from: Date()),
            pinned: !currentlyPinned,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("entries")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    /// Toggle featured state. Only one entry can be featured at a time —
    /// unfeaturing the old one is handled server-side by RLS/trigger, but
    /// we clear all other featured flags client-side as a safety measure.
    func toggleFeatured(entryId: String, currentlyFeatured: Bool) async throws {
        let payload = FeaturedUpdatePayload(
            featured: !currentlyFeatured,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("entries")
            .update(payload)
            .eq("id", value: entryId)
            .execute()
    }

    /// Toggle action completion: sets or clears completed_at
    func toggleActionComplete(id: String, currentlyCompleted: Bool) async throws {
        let payload = CompletionUpdatePayload(
            completedAt: currentlyCompleted ? nil : ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("entries")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Entry Creation

    /// Create a new journal entry
    func createEntry(
        content: String,
        category: String,
        entryType: String = "story",
        sourceEntryId: String? = nil,
        metadata: EntryMetadata? = nil
    ) async throws -> Entry {
        guard let userId = currentSession?.user.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let payload = NewEntryPayload(
            content: content,
            headline: "",
            category: category,
            entryType: entryType,
            userId: userId.uuidString,
            generatingVersions: true,
            sourceEntryId: sourceEntryId,
            metadata: metadata
        )

        let entry: Entry = try await client
            .from("entries")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return entry
    }

    /// Create a linked entry (Water Cycle: story -> action -> note -> story)
    func createLinkedEntry(
        content: String,
        category: String,
        sourceEntryId: String,
        entryType: String
    ) async throws -> Entry {
        return try await createEntry(
            content: content,
            category: category,
            entryType: entryType,
            sourceEntryId: sourceEntryId
        )
    }

    // MARK: - AI Inference (Vercel API Routes)

    /// Call the infer-entry API to get AI-generated headline, category, mood, and entry type
    func inferEntry(content: String) async throws -> InferEntryResponse {
        guard let url = URL(string: "\(Self.apiBaseURL)/api/infer-entry") else {
            throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        if let token = currentSession?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "API", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Inference failed with status \(statusCode)"])
        }

        return try JSONDecoder().decode(InferEntryResponse.self, from: data)
    }

    /// Call the infer-enrichment API for contextual metadata
    func inferEnrichment(content: String, timeOfDay: String?, dayOfWeek: String?) async throws -> InferEnrichmentResponse {
        guard let url = URL(string: "\(Self.apiBaseURL)/api/infer-enrichment") else {
            throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = currentSession?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["content": content]
        if let timeOfDay = timeOfDay { body["timeOfDay"] = timeOfDay }
        if let dayOfWeek = dayOfWeek { body["dayOfWeek"] = dayOfWeek }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "API", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Enrichment failed with status \(statusCode)"])
        }

        return try JSONDecoder().decode(InferEnrichmentResponse.self, from: data)
    }

    /// Update an existing entry with inferred data
    func updateEntry(id: String, fields: [String: String]) async throws {
        try await client
            .from("entries")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    /// Update an existing entry's metadata
    func updateEntryMetadata(id: String, metadata: EntryMetadata) async throws {
        let wrapper = MetadataUpdatePayload(metadata: metadata)
        try await client
            .from("entries")
            .update(wrapper)
            .eq("id", value: id)
            .execute()
    }

    /// Call generate-versions API and save results to the entry
    func generateVersions(entry: Entry) async throws {
        guard let url = URL(string: "\(Self.apiBaseURL)/api/generate-versions") else {
            throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Versions can take a while to generate

        if let token = currentSession?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // The endpoint expects { entry: Entry }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let entryData = try encoder.encode(entry)
        let entryDict = try JSONSerialization.jsonObject(with: entryData)
        let body: [String: Any] = ["entry": entryDict]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "API", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Version generation failed with status \(statusCode)"])
        }

        // Parse versions from response
        struct VersionsResponse: Codable {
            let versions: [Version]
        }
        let versionsResponse = try JSONDecoder().decode(VersionsResponse.self, from: data)

        // Save versions to the entry and mark generating as false
        let updatePayload = VersionsUpdatePayload(
            versions: versionsResponse.versions,
            generatingVersions: false
        )
        try await client
            .from("entries")
            .update(updatePayload)
            .eq("id", value: entry.id)
            .execute()
    }

    // MARK: - Extractions

    /// Fetch all extractions across every batch for map aggregation
    func fetchAllExtractions() async throws -> [Extraction] {
        let extractions: [Extraction] = try await client
            .from("extractions")
            .select()
            .order("created_at", ascending: false)
            .limit(5000)
            .execute()
            .value
        return extractions
    }

    /// Fetch extractions for the current user, optionally filtered by batch ID
    func fetchExtractions(batchId: String? = nil, limit: Int = 200) async throws -> [Extraction] {
        if let batchId = batchId {
            let extractions: [Extraction] = try await client
                .from("extractions")
                .select()
                .eq("batch_id", value: batchId)
                .order("category", ascending: true)
                .limit(limit)
                .execute()
                .value
            return extractions
        } else {
            let extractions: [Extraction] = try await client
                .from("extractions")
                .select()
                .order("category", ascending: true)
                .limit(limit)
                .execute()
                .value
            return extractions
        }
    }

    /// Fetch distinct batch IDs with counts for the batch selector
    func fetchExtractionBatches() async throws -> [(batchId: String, createdAt: String, count: Int)] {
        let all: [Extraction] = try await client
            .from("extractions")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        var batchMap: [String: (createdAt: String, count: Int)] = [:]
        for ext in all {
            if let existing = batchMap[ext.batchId] {
                batchMap[ext.batchId] = (createdAt: existing.createdAt, count: existing.count + 1)
            } else {
                batchMap[ext.batchId] = (createdAt: ext.createdAt, count: 1)
            }
        }

        return batchMap.map { (batchId: $0.key, createdAt: $0.value.createdAt, count: $0.value.count) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Trigger extraction pipeline via the Vercel API route
    func runExtraction() async throws -> ExtractionBatchResponse {
        guard let url = URL(string: "\(Self.apiBaseURL)/api/extract") else {
            throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        if let token = currentSession?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: Any])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "API", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Extraction failed with status \(statusCode)"])
        }

        return try JSONDecoder().decode(ExtractionBatchResponse.self, from: data)
    }

    // MARK: - Image Upload

    /// Resize a UIImage to max width, maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxWidth: CGFloat = 1200) -> UIImage {
        let size = image.size
        guard size.width > maxWidth else { return image }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Upload an image to Supabase Storage entry-photos bucket
    /// Returns the public URL of the uploaded image
    func uploadEntryImage(image: UIImage, userId: String, entryId: String, index: Int) async throws -> String {
        // Resize to max 1200px width
        let resized = resizeImage(image)

        // Convert to JPEG data
        guard let jpegData = resized.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "SupabaseService", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }

        // Build file path: {userId}/{entryId}-{index}-{timestamp}.jpg
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let fileName = "\(entryId)-\(index)-\(timestamp).jpg"
        let filePath = "\(userId)/\(fileName)"

        // Upload using Supabase Storage
        try await client.storage
            .from("entry-photos")
            .upload(filePath, data: jpegData, options: .init(contentType: "image/jpeg", upsert: true))

        // Get public URL
        let publicUrl = try client.storage
            .from("entry-photos")
            .getPublicURL(path: filePath)

        return publicUrl.absoluteString
    }

    /// Update an entry's images array and legacy photo_url field
    func updateEntryImages(entryId: String, images: [EntryImage]) async throws {
        let payload = ImagesUpdatePayload(
            images: images,
            photoUrl: images.first?.url,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("entries")
            .update(payload)
            .eq("id", value: entryId)
            .execute()
    }
}

// MARK: - Insert/Update Payloads

struct NewEntryPayload: Encodable {
    let content: String
    let headline: String
    let category: String
    let entryType: String
    let userId: String
    let generatingVersions: Bool
    let sourceEntryId: String?
    let metadata: EntryMetadata?

    enum CodingKeys: String, CodingKey {
        case content, headline, category, metadata
        case entryType = "entry_type"
        case userId = "user_id"
        case generatingVersions = "generating_versions"
        case sourceEntryId = "source_entry_id"
    }
}

struct PinUpdatePayload: Encodable {
    let pinnedAt: String?
    let pinned: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case pinnedAt = "pinned_at"
        case pinned
        case updatedAt = "updated_at"
    }
}

struct CompletionUpdatePayload: Encodable {
    let completedAt: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }
}

struct FeaturedUpdatePayload: Encodable {
    let featured: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case featured
        case updatedAt = "updated_at"
    }
}

struct MetadataUpdatePayload: Encodable {
    let metadata: EntryMetadata
}

struct ImagesUpdatePayload: Encodable {
    let images: [EntryImage]
    let photoUrl: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case images
        case photoUrl = "photo_url"
        case updatedAt = "updated_at"
    }
}

struct VersionsUpdatePayload: Encodable {
    let versions: [Version]
    let generatingVersions: Bool

    enum CodingKeys: String, CodingKey {
        case versions
        case generatingVersions = "generating_versions"
    }
}

// MARK: - API Response Models

struct InferEntryResponse: Codable {
    let headline: String?
    let subheading: String?
    let category: String?
    let mood: String?
    let entryType: String?
    let connectionType: String?

    enum CodingKeys: String, CodingKey {
        case headline, subheading, category, mood
        case entryType = "entry_type"
        case connectionType = "connection_type"
    }
}

struct InferEnrichmentResponse: Codable {
    let activity: String?
    let energy: String?
    let mood: [String]?
    let environment: String?
    let trigger: String?
}
