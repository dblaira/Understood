//
//  MapNode.swift
//  Understood
//
//  Data model for Influence Map visualization nodes
//

import SwiftUI

struct MapNode: Identifiable {
    let id: String
    let label: String
    let category: String
    let type: NodeType
    let parentId: String?
    let importance: Double
    let confidence: Double
    let occurrences: Int
    let color: Color
    let nodeLevel: NodeLevel?

    enum NodeType {
        case category
        case concept
    }

    enum NodeLevel {
        case parent
        case child
    }
}
