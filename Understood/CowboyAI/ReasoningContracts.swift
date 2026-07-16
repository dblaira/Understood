import Foundation

struct CowboyAttachmentReference: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let mediaType: String?
    let localURL: String?
    let sourceReference: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case mediaType = "media_type"
        case localURL = "local_url"
        case sourceReference = "source_reference"
    }
}

struct ReasoningRequest: Codable {
    let requestID: String
    let conversationID: String
    let rawWords: String
    let attachments: [CowboyAttachmentReference]
    let sourceReferences: [String]
    let currentAppSurface: String
    let connectivityState: String
    let requestedOperation: String

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case conversationID = "conversation_id"
        case rawWords = "raw_words"
        case attachments
        case sourceReferences = "source_references"
        case currentAppSurface = "current_app_surface"
        case connectivityState = "connectivity_state"
        case requestedOperation = "requested_operation"
    }
}

struct CowboyAuthorityReference: Codable, Identifiable, Hashable {
    let beliefID: String
    let antecedent: String
    let consequent: String
    let confidence: Double
    let provenance: JSONValue?

    var id: String { beliefID }

    enum CodingKeys: String, CodingKey {
        case beliefID = "belief_id"
        case antecedent, consequent, confidence, provenance
    }
}

struct CowboyEvidenceReference: Codable, Identifiable, Hashable {
    let evidenceID: String
    let label: String
    let source: String?
    let beliefID: String?

    var id: String { evidenceID }

    enum CodingKeys: String, CodingKey {
        case evidenceID = "evidence_id"
        case label, source
        case beliefID = "belief_id"
    }
}

struct CowboyCandidateRelationship: Codable, Identifiable, Hashable {
    let candidateID: String
    let statement: String
    let relationship: String?
    let evidenceIDs: [String]
    let status: String

    var id: String { candidateID }

    enum CodingKeys: String, CodingKey {
        case candidateID = "candidate_id"
        case statement, relationship, status
        case evidenceIDs = "evidence_ids"
    }
}

struct CowboyRouteStep: Codable, Identifiable, Hashable {
    let worker: String
    let role: String
    let model: String?
    let status: String

    var id: String { "\(worker)|\(role)|\(model ?? "")" }
}

struct ReasoningEnvelope: Codable, Hashable {
    let requestID: String
    let conversationID: String
    let finalAnswer: String
    let acceptedAuthorityUsed: [CowboyAuthorityReference]
    let supportingEvidenceUsed: [CowboyEvidenceReference]
    let candidateRelationshipsGenerated: [CowboyCandidateRelationship]
    let route: String
    let routeTrace: [CowboyRouteStep]
    let graphRevision: String
    let adapterVersion: String
    let pendingOfflineSync: Bool
    let rawWordsSHA256: String
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case conversationID = "conversation_id"
        case finalAnswer = "final_answer"
        case acceptedAuthorityUsed = "accepted_authority_used"
        case supportingEvidenceUsed = "supporting_evidence_used"
        case candidateRelationshipsGenerated = "candidate_relationships_generated"
        case route
        case routeTrace = "route_trace"
        case graphRevision = "graph_revision"
        case adapterVersion = "adapter_version"
        case pendingOfflineSync = "pending_offline_sync"
        case rawWordsSHA256 = "raw_words_sha256"
        case completedAt = "completed_at"
    }
}

struct CowboyHealthEnvelope: Codable {
    let status: String
    let mode: String
    let model: String
    let adapterVersion: String
    let graphRevision: String
    let acceptedAxiomCount: Int
    let pendingOfflineSync: Int
    let pairingRequired: Bool

    enum CodingKeys: String, CodingKey {
        case status, mode, model
        case adapterVersion = "adapter_version"
        case graphRevision = "graph_revision"
        case acceptedAxiomCount = "accepted_axiom_count"
        case pendingOfflineSync = "pending_offline_sync"
        case pairingRequired = "pairing_required"
    }
}

struct CowboyPairResponse: Codable {
    let deviceID: String
    let deviceToken: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceToken = "device_token"
    }
}

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
