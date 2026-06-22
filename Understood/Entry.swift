//
//  Entry.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import Foundation

// MARK: - Entry Image

/// Image attached to an entry (matches web app's EntryImage type)
struct EntryImage: Codable, Hashable {
    let url: String
    var isPoster: Bool
    var order: Int
    var focalX: Double?
    var focalY: Double?

    enum CodingKeys: String, CodingKey {
        case url
        case isPoster = "is_poster"
        case order
        case focalX = "focal_x"
        case focalY = "focal_y"
    }
}

// MARK: - Entry

/// Matches the Entry type from the web app
struct Entry: Codable, Identifiable, Hashable {
    static let maxImagesPerEntry = 6

    let id: String
    let userId: String
    var headline: String
    var category: String
    var subheading: String?
    var content: String
    var mood: String?
    var versions: [Version]?
    var generatingVersions: Bool?
    var entryType: String?
    var connectionType: String?
    var sourceEntryId: String?
    var pinned: Bool?
    var pinnedAt: String?
    var featured: Bool?
    var dueDate: String?
    var recurrenceRule: String?
    var completedAt: String?
    var createdAt: String
    var updatedAt: String?
    var metadata: EntryMetadata?

    // Image fields
    var images: [EntryImage]?
    var photoUrl: String?
    var imageUrl: String?

    /// Display text: headline if present, otherwise first line of content
    var displayHeadline: String {
        if !headline.isEmpty { return headline }
        let stripped = content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = stripped.components(separatedBy: .newlines).first ?? stripped
        if firstLine.count > 80 {
            return String(firstLine.prefix(80)) + "..."
        }
        return firstLine.isEmpty ? "Untitled entry" : firstLine
    }

    /// Whether a string is a loadable remote image URL.
    static func isValidImageURL(_ urlString: String?) -> Bool {
        guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    /// Trimmed HTTPS URL for display, if valid.
    static func validImageURLString(_ urlString: String?) -> String? {
        guard isValidImageURL(urlString) else { return nil }
        return urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// All images (converts legacy single-image to array format)
    var allImages: [EntryImage] {
        if let images = images, !images.isEmpty {
            return images.sorted { $0.order < $1.order }
        }
        if let url = Self.validImageURLString(imageUrl ?? photoUrl) {
            return [EntryImage(url: url, isPoster: true, order: 0)]
        }
        return []
    }

    /// Images with valid URLs — used for feed and carousel display.
    var displayableImages: [EntryImage] {
        allImages.filter { Self.isValidImageURL($0.url) }
    }

    /// Poster image URL (checks images array, then legacy fields)
    var posterImageUrl: String? {
        let candidates = displayableImages
        guard !candidates.isEmpty else { return nil }
        if let poster = candidates.first(where: { $0.isPoster }),
           let url = Self.validImageURLString(poster.url) {
            return url
        }
        return Self.validImageURLString(candidates[0].url)
    }

    /// Whether this entry has any displayable images
    var hasImages: Bool {
        posterImageUrl != nil
    }

    /// Adam Pattern step stored in entry metadata (iOS primary classifier)
    var patternStep: String? {
        metadata?.patternStep
    }

    /// Label for cards and hero — pattern step only; life areas are sunset on iOS
    var patternDisplayLabel: String? {
        guard let step = patternStep?.trimmingCharacters(in: .whitespacesAndNewlines),
              !step.isEmpty else { return nil }
        return step.uppercased()
    }

    /// Hero title with collapsed whitespace — avoids stretched multi-line layout.
    var heroHeadline: String {
        displayHeadline
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Entry Type Helpers

    var isPinned: Bool { pinnedAt != nil }
    var isCompleted: Bool { completedAt != nil }
    var isAction: Bool { entryType == "action" }
    var isStory: Bool { entryType == nil || entryType == "story" }
    var isNote: Bool { entryType == "note" }

    var parsedDueDate: Date? {
        guard let dueDate else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: dueDate) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: dueDate)
    }

    var parsedCompletedAt: Date? {
        guard let completedAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: completedAt) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: completedAt)
    }

    var isOverdue: Bool {
        guard !isCompleted, let due = parsedDueDate else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let due = parsedDueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    /// Plain-text preview of content, HTML stripped, max 80 chars
    var contentPreview: String {
        let stripped = content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.count > 80 {
            return String(stripped.prefix(80)) + "..."
        }
        return stripped
    }

    /// Poster image with focal point data
    var posterWithFocalPoint: (url: String, focalX: Double, focalY: Double)? {
        let candidates = displayableImages
        guard !candidates.isEmpty else { return nil }
        let poster = candidates.first(where: { $0.isPoster }) ?? candidates[0]
        guard let url = Self.validImageURLString(poster.url) else { return nil }
        return (url, poster.focalX ?? 50, poster.focalY ?? 50)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case headline
        case category
        case subheading
        case content
        case mood
        case versions
        case generatingVersions = "generating_versions"
        case entryType = "entry_type"
        case connectionType = "connection_type"
        case sourceEntryId = "source_entry_id"
        case pinned
        case pinnedAt = "pinned_at"
        case featured
        case dueDate = "due_date"
        case recurrenceRule = "recurrence_rule"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
        case images
        case photoUrl = "photo_url"
        case imageUrl = "image_url"
    }
}

/// AI-generated alternative versions of an entry
struct Version: Codable, Hashable {
    let name: String
    let title: String
    let content: String
    var headline: String?
    var body: String?
}

/// Auto-captured context for an entry
struct EntryMetadata: Codable, Hashable {
    var activity: String?
    var energy: String?
    var environment: String?
    var trigger: String?
    var timestamp: String?
    var dayOfWeek: String?
    var timeOfDay: String?
    var device: String?
    var location: LocationData?
    var patternStep: String?

    enum CodingKeys: String, CodingKey {
        case activity
        case energy
        case environment
        case trigger
        case timestamp
        case dayOfWeek = "day_of_week"
        case timeOfDay = "time_of_day"
        case device
        case location
        case patternStep = "pattern_step"
    }
}

struct LocationData: Codable, Hashable {
    var city: String?
    var region: String?
    var country: String?
}
