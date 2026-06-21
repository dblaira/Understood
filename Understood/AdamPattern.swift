//
//  AdamPattern.swift
//  Understood
//
//  The 8-Step Success Architecture — replaces life-area navigation on iOS.
//

import Foundation

enum AdamPattern {
    static let steps: [String] = [
        "Context",
        "Circle",
        "Close the Gap",
        "Choose Success",
        "Code the Pattern",
        "Create Kill Switch",
        "Clear Sign of Success",
        "Compound",
    ]

    /// Menu / filter options: all + each step (id is lowercased step name)
    static let filterOptions: [(id: String, label: String)] = {
        var options = [(id: "all", label: "All")]
        options.append(contentsOf: steps.map { (id: $0.lowercased(), label: $0) })
        return options
    }()

    static let legacyLifeAreas: Set<String> = [
        "business", "finance", "health", "fitness", "spiritual",
        "fun", "social", "romance", "all",
    ]

    static func matchesFilter(_ filter: String, patternStep: String?) -> Bool {
        guard filter != "all" else { return true }
        guard let patternStep else { return false }
        return patternStep.lowercased() == filter
    }

    static func isValidStep(_ value: String) -> Bool {
        steps.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
    }
}
