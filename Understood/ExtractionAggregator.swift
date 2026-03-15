//
//  ExtractionAggregator.swift
//  Understood
//
//  Aggregates raw extractions into MapNode data for the Influence Map.
//  Port of web app's aggregate.ts + importance.ts
//

import SwiftUI

enum ExtractionAggregator {

    // MARK: - Category Colors (matches web CATEGORY_COLORS)

    static let categoryColors: [String: Color] = [
        "affect":    Color(hex: 0x8B5CF6),
        "ambition":  Color(hex: 0x3B82F6),
        "belief":    Color(hex: 0x7C3AED),
        "exercise":  Color(hex: 0x10B981),
        "health":    Color(hex: 0xF43F5E),
        "insight":   Color(hex: 0xF59E0B),
        "nutrition": Color(hex: 0x14B8A6),
        "purchase":  Color(hex: 0xEC4899),
        "sleep":     Color(hex: 0x6366F1),
        "social":    Color(hex: 0xF97316),
        "work":      Color(hex: 0x0EA5E9),
    ]

    private static let fallbackColors: [Color] = [
        Color(hex: 0x64748B), Color(hex: 0xA855F7), Color(hex: 0x06B6D4), Color(hex: 0x84CC16),
        Color(hex: 0xE11D48), Color(hex: 0x0D9488), Color(hex: 0xD946EF), Color(hex: 0xEA580C),
    ]

    private static func categoryColor(for category: String) -> Color {
        if let c = categoryColors[category] { return c }
        let hash = abs(category.djb2Hash)
        return fallbackColors[hash % fallbackColors.count]
    }

    // MARK: - Importance Weights

    private static let wOccurrences: Double = 0.3
    private static let wIntensity: Double = 0.3
    private static let wConfidence: Double = 0.2
    private static let wRecency: Double = 0.2

    // MARK: - Public API

    static func aggregate(_ extractions: [Extraction]) -> [MapNode] {
        guard !extractions.isEmpty else { return [] }

        var categoryMap: [String: CategoryAccumulator] = [:]
        var conceptMap: [String: ConceptAccumulator] = [:]

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoFallback = ISO8601DateFormatter()
        isoFallback.formatOptions = [.withInternetDateTime]

        func parseDate(_ s: String) -> Date {
            isoFormatter.date(from: s) ?? isoFallback.date(from: s) ?? Date.distantPast
        }

        for ext in extractions {
            let cat = ext.category
            let entryDate = ext.createdAt

            if categoryMap[cat] == nil {
                categoryMap[cat] = CategoryAccumulator(
                    count: 0,
                    totalConfidence: 0,
                    totalIntensity: 0,
                    intensityCount: 0,
                    mostRecentDate: entryDate
                )
            }
            categoryMap[cat]!.count += 1
            categoryMap[cat]!.totalConfidence += ext.confidence

            let intensity = extractIntensity(ext.data)
            if let intensity {
                categoryMap[cat]!.totalIntensity += intensity
                categoryMap[cat]!.intensityCount += 1
            }

            if parseDate(entryDate) > parseDate(categoryMap[cat]!.mostRecentDate) {
                categoryMap[cat]!.mostRecentDate = entryDate
            }

            for (key, value) in ext.data {
                guard case .string(let s) = value, s.count <= 50 else { continue }
                let conceptId = "\(cat)::\(key)::\(s.lowercased())"

                if conceptMap[conceptId] == nil {
                    conceptMap[conceptId] = ConceptAccumulator(
                        key: key,
                        value: s.lowercased(),
                        category: cat,
                        count: 0,
                        totalConfidence: 0,
                        totalIntensity: 0,
                        intensityCount: 0,
                        mostRecentDate: entryDate
                    )
                }
                conceptMap[conceptId]!.count += 1
                conceptMap[conceptId]!.totalConfidence += ext.confidence

                if let intensity {
                    conceptMap[conceptId]!.totalIntensity += intensity
                    conceptMap[conceptId]!.intensityCount += 1
                }

                if parseDate(entryDate) > parseDate(conceptMap[conceptId]!.mostRecentDate) {
                    conceptMap[conceptId]!.mostRecentDate = entryDate
                }
            }
        }

        let sortedCategories = categoryMap.sorted { $0.key < $1.key }
        let recurringConcepts = conceptMap.filter { $0.value.count >= 2 }.sorted { $0.key < $1.key }

        var rawNodes: [RawNodeData] = []

        for (_, acc) in sortedCategories {
            rawNodes.append(RawNodeData(
                occurrences: acc.count,
                avgIntensity: acc.intensityCount > 0 ? acc.totalIntensity / Double(acc.intensityCount) : 0.5,
                avgConfidence: acc.totalConfidence / Double(acc.count),
                mostRecentDate: acc.mostRecentDate
            ))
        }

        for (_, acc) in recurringConcepts {
            rawNodes.append(RawNodeData(
                occurrences: acc.count,
                avgIntensity: acc.intensityCount > 0 ? acc.totalIntensity / Double(acc.intensityCount) : 0.5,
                avgConfidence: acc.totalConfidence / Double(acc.count),
                mostRecentDate: acc.mostRecentDate
            ))
        }

        let scores = computeImportanceScores(rawNodes, parseDate: parseDate)
        var nodes: [MapNode] = []

        for (i, (cat, acc)) in sortedCategories.enumerated() {
            nodes.append(MapNode(
                id: "cat::\(cat)",
                label: cat,
                category: cat,
                type: .category,
                parentId: nil,
                importance: scores[i],
                confidence: acc.totalConfidence / Double(acc.count),
                occurrences: acc.count,
                color: categoryColor(for: cat)
            ))
        }

        for (i, (_, acc)) in recurringConcepts.enumerated() {
            let scoreIdx = sortedCategories.count + i
            nodes.append(MapNode(
                id: "concept::\(acc.category)::\(acc.key)::\(acc.value)",
                label: acc.value,
                category: acc.category,
                type: .concept,
                parentId: "cat::\(acc.category)",
                importance: scores[scoreIdx],
                confidence: acc.totalConfidence / Double(acc.count),
                occurrences: acc.count,
                color: categoryColor(for: acc.category)
            ))
        }

        return nodes
    }

    // MARK: - Importance Scoring

    private static func computeImportanceScores(
        _ nodes: [RawNodeData],
        parseDate: (String) -> Date
    ) -> [Double] {
        guard !nodes.isEmpty else { return [] }

        let occValues = nodes.map(\.occurrences)
        let occMin = Double(occValues.min()!)
        let occMax = Double(occValues.max()!)

        let intValues = nodes.map(\.avgIntensity)
        let intMin = intValues.min()!
        let intMax = intValues.max()!

        let timestamps = nodes.map { parseDate($0.mostRecentDate).timeIntervalSince1970 }
        let oldest = timestamps.min()!
        let newest = timestamps.max()!

        return nodes.enumerated().map { i, node in
            let normOcc = normalize(Double(node.occurrences), min: occMin, max: occMax)
            let normInt = normalize(node.avgIntensity, min: intMin, max: intMax)
            let normConf = node.avgConfidence
            let normRecency = normalize(timestamps[i], min: oldest, max: newest)

            return normOcc * wOccurrences
                + normInt * wIntensity
                + normConf * wConfidence
                + normRecency * wRecency
        }
    }

    private static func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max != min else { return 0.5 }
        return Swift.max(0, Swift.min(1, (value - min) / (max - min)))
    }

    // MARK: - Intensity Extraction

    private static func extractIntensity(_ data: [String: ExtractionValue]) -> Double? {
        for key in ["intensity", "level", "severity"] {
            if case .number(let n) = data[key] { return n }
        }
        return nil
    }

    // MARK: - Internal Types

    private struct CategoryAccumulator {
        var count: Int
        var totalConfidence: Double
        var totalIntensity: Double
        var intensityCount: Int
        var mostRecentDate: String
    }

    private struct ConceptAccumulator {
        let key: String
        let value: String
        let category: String
        var count: Int
        var totalConfidence: Double
        var totalIntensity: Double
        var intensityCount: Int
        var mostRecentDate: String
    }

    private struct RawNodeData {
        let occurrences: Int
        let avgIntensity: Double
        let avgConfidence: Double
        let mostRecentDate: String
    }
}

// MARK: - Color hex initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - DJB2 hash for deterministic fallback colors

extension String {
    var djb2Hash: Int {
        var hash = 0
        for char in utf8 {
            hash = ((hash << 5) &- hash) &+ Int(char)
        }
        return hash
    }
}
