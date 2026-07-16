import CryptoKit
import Foundation
import Network
import Auth

@Observable
@MainActor
final class CowboyAIViewModel {
    enum Phase: Equatable {
        case searching
        case unavailable
        case needsPairing
        case ready
        case pairing
        case thinking
        case captureOnly
        case failed(String)
    }

    enum LaborRoute: String, CaseIterable, Identifiable {
        case personal = "reason"
        case deepLocal = "deep_local"
        case claude = "frontier_claude"
        case codex = "frontier_codex"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .personal: "Personal"
            case .deepLocal: "Deeper local"
            case .claude: "Claude"
            case .codex: "Codex"
            }
        }

        var detail: String {
            switch self {
            case .personal: "Qwen3.6-27B · local personal model"
            case .deepLocal: "Qwen3.5-122B · deeper local worker"
            case .claude: "Online frontier worker"
            case .codex: "Online frontier worker"
            }
        }
    }

    var rawWords = ""
    var pairingCode = ""
    var route: LaborRoute = .personal
    var correctionText = ""
    var tailscaleAddress = UserDefaults.standard.string(forKey: "cowboyAITailscaleURL") ?? ""
    private(set) var phase: Phase = .searching
    private(set) var health: CowboyHealthEnvelope?
    private(set) var envelope: ReasoningEnvelope?
    private(set) var hasInternet = true
    private(set) var reviewMessage: String?

    private let client: CowboyGatewayClient
    private let supabase: SupabaseService
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "understood.cowboyai.path")
    private var conversationID = UUID().uuidString

    init(client: CowboyGatewayClient? = nil, supabase: SupabaseService? = nil) {
        self.client = client ?? .shared
        self.supabase = supabase ?? .shared
        let model = self
        pathMonitor.pathUpdateHandler = { path in
            Task { @MainActor in model.hasInternet = path.status == .satisfied }
        }
        pathMonitor.start(queue: pathQueue)
    }

    var modeTitle: String {
        if client.isAvailable {
            if client.isDiscovered {
                return client.paired ? "Cowboy AI on this Mac" : "Mac found — pairing required"
            }
            return client.paired ? "Cowboy AI through Tailscale" : "Mac address saved — pairing required"
        }
        return hasInternet ? "Cloud worker without personal model" : "Capture only"
    }

    var isDiscovered: Bool { client.isDiscovered }
    var isAvailable: Bool { client.isAvailable }
    var isPaired: Bool { client.paired }

    var modeExplanation: String {
        if client.isAvailable && client.paired {
            return "The accepted graph and personal model shape the answer."
        }
        if client.isAvailable {
            return "Enter the one-time code shown by Cowboy AI on the Mac."
        }
        if hasInternet {
            return "The Mac is unavailable. A cloud worker may answer, but Cowboy AI will not be claimed."
        }
        return "Your exact words will be kept locally until Cowboy AI is available."
    }

    func start() async {
        if ProcessInfo.processInfo.arguments.contains("-uitestCowboyResult") {
            seedUITestResult()
            return
        }
        phase = .searching
        client.startDiscovery()
        for _ in 0..<20 {
            if Task.isCancelled { return }
            if client.isDiscovered { break }
            try? await Task.sleep(for: .milliseconds(150))
        }
        guard client.isAvailable else {
            phase = .unavailable
            return
        }
        do {
            health = try await client.health()
            phase = client.paired ? .ready : .needsPairing
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func pair() async {
        let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6 else {
            phase = .failed("Enter the six-digit code shown on the Mac.")
            return
        }
        phase = .pairing
        do {
            try await client.pair(code: code)
            pairingCode = ""
            if let token = supabase.currentSession?.accessToken {
                health = try await client.syncGraph(supabaseToken: token)
            } else {
                health = try await client.health()
            }
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func submit() async {
        let words = rawWords
        guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        envelope = nil
        reviewMessage = nil
        correctionText = ""
        let isLocal = client.isAvailable
        let request = ReasoningRequest(
            requestID: UUID().uuidString,
            conversationID: conversationID,
            rawWords: words,
            attachments: [],
            sourceReferences: [],
            currentAppSurface: "cowboy_ai",
            connectivityState: isLocal ? (hasInternet ? "online" : "local_network") : (hasInternet ? "online" : "offline"),
            requestedOperation: route.rawValue
        )
        guard isLocal || hasInternet else {
            CowboyOfflineQueue.append(request)
            envelope = Self.captureEnvelope(for: request)
            phase = .captureOnly
            return
        }
        if isLocal && !client.paired {
            phase = .needsPairing
            return
        }
        phase = .thinking
        do {
            envelope = try await client.reason(request, supabaseToken: supabase.currentSession?.accessToken)
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func acceptAnswer() async {
        guard let envelope, client.isAvailable, client.paired else { return }
        do {
            try await client.saveTrainingExample(
                rawWords: rawWords,
                envelope: envelope,
                acceptedResponse: envelope.finalAnswer,
                rejectedResponse: nil,
                correction: nil
            )
            reviewMessage = "Accepted as Adam-approved training material."
        } catch {
            reviewMessage = error.localizedDescription
        }
    }

    func saveCorrection() async {
        guard let envelope, client.isAvailable, client.paired else { return }
        let correction = correctionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !correction.isEmpty else {
            reviewMessage = "Write the replacement first."
            return
        }
        do {
            try await client.saveTrainingExample(
                rawWords: rawWords,
                envelope: envelope,
                acceptedResponse: correction,
                rejectedResponse: envelope.finalAnswer,
                correction: correction
            )
            reviewMessage = "Correction saved with the rejected answer and governing graph revision."
        } catch {
            reviewMessage = error.localizedDescription
        }
    }

    func reviewCandidate(_ candidate: CowboyCandidateRelationship, status: String) async {
        guard client.isAvailable, client.paired else { return }
        do {
            try await client.reviewCandidate(id: candidate.candidateID, status: status)
            reviewMessage = status == "rejected"
                ? "Candidate rejected. It did not become authority."
                : "Candidate queued for Supabase belief review. It is still not authority."
        } catch {
            reviewMessage = error.localizedDescription
        }
    }

    func connectThroughTailscale() async {
        do {
            try client.configureRemoteGateway(tailscaleAddress)
            await start()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private static func captureEnvelope(for request: ReasoningRequest) -> ReasoningEnvelope {
        let hash = SHA256.hash(data: Data(request.rawWords.utf8)).map { String(format: "%02x", $0) }.joined()
        return ReasoningEnvelope(
            requestID: request.requestID,
            conversationID: request.conversationID,
            finalAnswer: "Captured. Cowboy AI will reason over this when the personal model is available.",
            acceptedAuthorityUsed: [],
            supportingEvidenceUsed: [],
            candidateRelationshipsGenerated: [],
            route: "capture_only",
            routeTrace: [CowboyRouteStep(worker: "Understood", role: "append-only capture", model: nil, status: "queued")],
            graphRevision: "last-known-on-mac",
            adapterVersion: "not-used",
            pendingOfflineSync: true,
            rawWordsSHA256: hash,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func seedUITestResult() {
        phase = .ready
        rawWords = "What should govern this decision?"
        envelope = ReasoningEnvelope(
            requestID: "ui-test-request",
            conversationID: "ui-test-conversation",
            finalAnswer: "Keep the accepted belief in control. Treat the new relationship as a candidate until Adam reviews it.",
            acceptedAuthorityUsed: [CowboyAuthorityReference(
                beliefID: "belief-accepted-01",
                antecedent: "When a model finds a relationship",
                consequent: "Adam reviews it before it becomes authority",
                confidence: 0.98,
                provenance: .string("Adam's accepted correction")
            )],
            supportingEvidenceUsed: [CowboyEvidenceReference(
                evidenceID: "evidence-01", label: "Adam's accepted correction", source: "Understood", beliefID: "belief-accepted-01"
            )],
            candidateRelationshipsGenerated: [CowboyCandidateRelationship(
                candidateID: "candidate-01", statement: "This decision may connect to the visible-proof pattern.",
                relationship: "may_reinforce", evidenceIDs: ["evidence-01"], status: "candidate"
            )],
            route: "frontier_through_personal",
            routeTrace: [
                CowboyRouteStep(worker: "Claude", role: "frontier labor", model: "Claude", status: "completed"),
                CowboyRouteStep(worker: "Cowboy AI", role: "authority check and final presentation", model: "Qwen3.6-27B", status: "completed"),
            ],
            graphRevision: "graph-8f31d2",
            adapterVersion: "adam-v1",
            pendingOfflineSync: false,
            rawWordsSHA256: "ui-test",
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

private enum CowboyOfflineQueue {
    static func append(_ request: ReasoningRequest) {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("CowboyAI", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appendingPathComponent("offline-captures.jsonl")
            var data = try JSONEncoder().encode(request)
            data.append(0x0A)
            if FileManager.default.fileExists(atPath: target.path),
               let handle = try? FileHandle(forWritingTo: target) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: target, options: .atomic)
            }
        } catch {
            assertionFailure("Could not save Cowboy AI offline capture: \(error)")
        }
    }
}
