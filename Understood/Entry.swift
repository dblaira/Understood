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

    /// Poster image URL (checks images array, then legacy fields)
    var posterImageUrl: String? {
        if let images = images, !images.isEmpty {
            let poster = images.first(where: { $0.isPoster }) ?? images[0]
            return poster.url
        }
        return imageUrl ?? photoUrl
    }

    /// All images (converts legacy single-image to array format)
    var allImages: [EntryImage] {
        if let images = images, !images.isEmpty {
            return images.sorted { $0.order < $1.order }
        }
        if let url = imageUrl ?? photoUrl {
            return [EntryImage(url: url, isPoster: true, order: 0)]
        }
        return []
    }

    /// Whether this entry has any images
    var hasImages: Bool {
        posterImageUrl != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
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
    }
}

struct LocationData: Codable, Hashable {
    var city: String?
    var region: String?
    var country: String?
}
