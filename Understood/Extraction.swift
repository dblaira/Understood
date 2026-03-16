//
//  Extraction.swift
//  Understood
//
//  Structured data extracted from journal entries by Claude
//

import Foundation

struct Extraction: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let entryId: String?
    let category: String
    let data: [String: ExtractionValue]
    let confidence: Double
    let sourceText: String?
    let batchId: String
    let createdAt: String
    let parentCategory: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case entryId = "entry_id"
        case category
        case data
        case confidence
        case sourceText = "source_text"
        case batchId = "batch_id"
        case createdAt = "created_at"
        case parentCategory = "parent_category"
    }
}

/// Handles mixed JSON value types in extraction data
enum ExtractionValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)

    var displayString: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            if n == n.rounded() {
                return String(Int(n))
            }
            return String(format: "%.1f", n)
        case .bool(let b): return b ? "yes" : "no"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else {
            self = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        }
    }
}

/// Response from the /api/extract endpoint
struct ExtractionBatchResponse: Codable {
    let batchId: String?
    let totalEntriesProcessed: Int
    let totalExtractionsFound: Int
    let categoriesFound: [String]
    let extractionIds: [String]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case totalEntriesProcessed = "total_entries_processed"
        case totalExtractionsFound = "total_extractions_found"
        case categoriesFound = "categories_found"
        case extractionIds = "extraction_ids"
        case message
    }
}
