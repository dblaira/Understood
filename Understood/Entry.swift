//
//  Entry.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import Foundation

/// Matches the Entry type from the web app
struct Entry: Codable, Identifiable, Hashable {
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
    var createdAt: String
    var updatedAt: String?
    var metadata: EntryMetadata?
    
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
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
