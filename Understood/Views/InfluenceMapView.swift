//
//  InfluenceMapView.swift
//  Understood
//
//  Force-directed bubble visualization of extraction categories and concepts
//

import SwiftUI

struct InfluenceMapView: View {
    let nodes: [MapNode]
    var onDrillDown: ((MapNode) -> Void)?

    @State private var selectedNode: MapNode?
    @State private var layoutPositions: [String: CGPoint] = [:]
    @State private var hasLaidOut = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Tap backdrop to dismiss popup
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = nil }

                // Connection lines (concept → parent category)
                ForEach(conceptNodes) { node in
                    if let parentPos = layoutPositions[node.parentId ?? ""],
                       let nodePos = layoutPositions[node.id] {
                        Path { path in
                            path.move(to: parentPos)
                            path.addLine(to: nodePos)
                        }
                        .stroke(node.color.opacity(0.1), lineWidth: 1)
                    }
                }

                // Circles
                ForEach(nodes) { node in
                    if let pos = layoutPositions[node.id] {
                        let r = radius(for: node)
                        let isSelected = selectedNode?.id == node.id

                        circleView(node: node, radius: r, isSelected: isSelected)
                            .position(pos)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedNode = selectedNode?.id == node.id ? nil : node
                                }
                            }
                    }
                }

                // Selection popup
                if let node = selectedNode, let pos = layoutPositions[node.id] {
                    popupOverlay(node: node, anchor: pos, containerSize: size)
                }
            }
            .onAppear {
                if !hasLaidOut {
                    layoutPositions = packCircles(nodes: nodes, in: size)
                    hasLaidOut = true
                }
            }
            .onChange(of: nodes.count) {
                layoutPositions = packCircles(nodes: nodes, in: size)
                hasLaidOut = true
            }
        }
    }

    // MARK: - Circle View

    private func circleView(node: MapNode, radius: CGFloat, isSelected: Bool) -> some View {
        let opacity = 0.3 + node.confidence * 0.7
        let labelSize = node.type == .category
            ? max(9, min(13, radius * 0.24))
            : max(8, min(10, radius * 0.38))
        let numSize = node.type == .category
            ? max(14, min(28, radius * 0.5))
            : max(10, min(18, radius * 0.45))
        let maxChars = Int(radius * 0.28)
        let label = truncate(node.label.uppercased(), max: max(3, maxChars))

        return ZStack {
            // Circle fill
            Circle()
                .fill(node.color.opacity(opacity))
                .frame(width: radius * 2, height: radius * 2)

            // Selection ring
            if isSelected {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: radius * 2, height: radius * 2)
            }

            // Label (above center)
            if radius >= 20 {
                Text(label)
                    .font(.custom("Inter-Bold", size: labelSize))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .offset(y: -(radius * 0.15))
                    .allowsHitTesting(false)
            }

            // Faint occurrence number (below label)
            if radius >= 20 {
                Text("\(node.occurrences)")
                    .font(.custom("Inter-Bold", size: numSize))
                    .foregroundStyle(.white.opacity(0.25))
                    .offset(y: radius * 0.22)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Popup Overlay

    private func popupOverlay(node: MapNode, anchor: CGPoint, containerSize: CGSize) -> some View {
        let popupWidth: CGFloat = 220
        let popupHeight: CGFloat = 130
        let r = radius(for: node)

        let nearRight = anchor.x + r + popupWidth + 16 > containerSize.width
        let nearBottom = anchor.y + popupHeight > containerSize.height - 20

        let x = nearRight
            ? max(12, anchor.x - r - popupWidth - 8)
            : anchor.x + r + 8
        let y = nearBottom
            ? max(12, anchor.y - popupHeight)
            : anchor.y - 16

        return VStack(alignment: .leading, spacing: 6) {
            Text(node.label.uppercased())
                .font(.custom("Inter-Bold", size: 12))
                .tracking(0.8)
                .foregroundStyle(node.color)

            HStack(spacing: 14) {
                statColumn(value: "\(node.occurrences)", label: "OCCURRENCES")
                statColumn(value: "\(Int(node.confidence * 100))%", label: "CONFIDENCE")
                statColumn(value: "\(Int(node.importance * 100))", label: "SCORE")
            }

            Button {
                selectedNode = nil
                onDrillDown?(node)
            } label: {
                Text("VIEW EXTRACTIONS →")
                    .font(.custom("Inter-SemiBold", size: 10))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(node.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(12)
        .frame(width: popupWidth)
        .background(Color.black.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .position(x: x + popupWidth / 2, y: y + popupHeight / 2)
        .transition(.opacity)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.custom("Inter-Bold", size: 18))
                .foregroundStyle(.white)
            Text(label)
                .font(.custom("Inter-SemiBold", size: 7))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Helpers

    private var conceptNodes: [MapNode] {
        nodes.filter { $0.type == .concept && $0.parentId != nil }
    }

    private func radius(for node: MapNode) -> CGFloat {
        let curved = pow(node.importance, 2)
        if node.type == .category {
            return 28 + curved * (95 - 28)
        }
        return 18 + curved * (44 - 18)
    }

    private func truncate(_ text: String, max: Int) -> String {
        if text.count <= max { return text }
        return String(text.prefix(max - 1)) + "…"
    }

    // MARK: - Circle Packing Layout

    private func packCircles(nodes: [MapNode], in size: CGSize) -> [String: CGPoint] {
        guard !nodes.isEmpty else { return [:] }

        struct PlacedCircle {
            let id: String
            var center: CGPoint
            let radius: CGFloat
        }

        let sorted = nodes.sorted { radius(for: $0) > radius(for: $1) }
        var placed: [PlacedCircle] = []
        let cx = size.width / 2
        let cy = size.height / 2
        let padding: CGFloat = 6

        for node in sorted {
            let r = radius(for: node)

            if placed.isEmpty {
                placed.append(PlacedCircle(id: node.id, center: CGPoint(x: cx, y: cy), radius: r))
                continue
            }

            var bestPoint = CGPoint(x: cx, y: cy)
            var bestDist = CGFloat.infinity

            // Spiral outward from center looking for a valid spot
            let angleStep: CGFloat = 0.3
            let radiusStep: CGFloat = 2.0
            var spiralAngle: CGFloat = 0
            var spiralRadius: CGFloat = 0

            while spiralRadius < max(size.width, size.height) {
                let testX = cx + cos(spiralAngle) * spiralRadius
                let testY = cy + sin(spiralAngle) * spiralRadius

                let candidate = CGPoint(x: testX, y: testY)

                // Check bounds
                let inBounds = testX - r - 8 >= 0
                    && testX + r + 8 <= size.width
                    && testY - r - 8 >= 0
                    && testY + r + 8 <= size.height

                if inBounds {
                    let overlaps = placed.contains { p in
                        let dx = p.center.x - testX
                        let dy = p.center.y - testY
                        let dist = sqrt(dx * dx + dy * dy)
                        return dist < p.radius + r + padding
                    }

                    if !overlaps {
                        let distFromCenter = sqrt(pow(testX - cx, 2) + pow(testY - cy, 2))
                        if distFromCenter < bestDist {
                            bestPoint = candidate
                            bestDist = distFromCenter
                            break
                        }
                    }
                }

                spiralAngle += angleStep
                spiralRadius += radiusStep * (angleStep / (2 * .pi))
            }

            placed.append(PlacedCircle(id: node.id, center: bestPoint, radius: r))
        }

        var result: [String: CGPoint] = [:]
        for p in placed {
            result[p.id] = p.center
        }
        return result
    }
}
