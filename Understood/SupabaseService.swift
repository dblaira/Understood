//
//  SupabaseService.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import Foundation
import Supabase

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

    // MARK: - Entry Actions

    /// Delete an entry by ID
    func deleteEntry(id: String) async throws {
        try await client
            .from("entries")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Toggle pinned state on an entry
    func togglePin(id: String, pinned: Bool) async throws {
        try await client
            .from("entries")
            .update(["pinned": pinned])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Entry Creation

    /// Create a new journal entry
    func createEntry(content: String, category: String, metadata: EntryMetadata?) async throws -> Entry {
        guard let userId = currentSession?.user.id else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let payload = NewEntryPayload(
            content: content,
            headline: "",
            category: category,
            entryType: "story",
            userId: userId.uuidString,
            generatingVersions: true,
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
}

// MARK: - Insert/Update Payloads

struct NewEntryPayload: Encodable {
    let content: String
    let headline: String
    let category: String
    let entryType: String
    let userId: String
    let generatingVersions: Bool
    let metadata: EntryMetadata?

    enum CodingKeys: String, CodingKey {
        case content, headline, category, metadata
        case entryType = "entry_type"
        case userId = "user_id"
        case generatingVersions = "generating_versions"
    }
}

struct MetadataUpdatePayload: Encodable {
    let metadata: EntryMetadata
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
