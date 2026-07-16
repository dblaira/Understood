import Foundation
import Network
import UIKit

enum CowboyGatewayError: LocalizedError {
    case notDiscovered
    case invalidResponse
    case http(Int, String)
    case cloudUnavailable

    var errorDescription: String? {
        switch self {
        case .notDiscovered: "Cowboy AI is not available on this network."
        case .invalidResponse: "Cowboy AI returned an unreadable response."
        case .http(let status, let message): "Cowboy AI returned \(status): \(message)"
        case .cloudUnavailable: "The Mac is unavailable and the cloud worker could not be reached."
        }
    }
}

@Observable
@MainActor
final class CowboyGatewayClient {
    static let shared = CowboyGatewayClient()

    private(set) var endpoint: NWEndpoint?
    private(set) var isSearching = false
    private(set) var gatewayName: String?
    private var browser: NWBrowser?
    private let transport = CowboyHTTPTransport()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var paired: Bool { CowboyKeychain.read() != nil }
    var isDiscovered: Bool { endpoint != nil }
    var hasConfiguredRemote: Bool { remoteBaseURL != nil }
    var isAvailable: Bool { isDiscovered || hasConfiguredRemote }
    var deviceID: String { UIDevice.current.identifierForVendor?.uuidString ?? "understood-iphone" }

    private var remoteBaseURL: URL? {
        guard let value = UserDefaults.standard.string(forKey: "cowboyAITailscaleURL") else { return nil }
        return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func configureRemoteGateway(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || URL(string: trimmed)?.scheme == "https" else {
            throw CowboyGatewayError.http(400, "Use the secure HTTPS address from Tailscale.")
        }
        UserDefaults.standard.set(trimmed.isEmpty ? nil : trimmed, forKey: "cowboyAITailscaleURL")
    }

    func startDiscovery() {
        guard browser == nil else { return }
        isSearching = true
        let browser = NWBrowser(for: .bonjour(type: "_cowboyai._tcp", domain: nil), using: .tcp)
        let client = self
        browser.browseResultsChangedHandler = { results, _ in
            let first = results.first
            Task { @MainActor in
                client.endpoint = first?.endpoint
                client.gatewayName = first.map { result in
                    if case .service(let name, _, _, _) = result.endpoint { return name }
                    return "Cowboy AI"
                }
                client.isSearching = false
            }
        }
        browser.stateUpdateHandler = { state in
            if case .failed = state {
                Task { @MainActor in client.isSearching = false }
            }
        }
        self.browser = browser
        browser.start(queue: DispatchQueue(label: "understood.cowboyai.bonjour"))
    }

    func health() async throws -> CowboyHealthEnvelope {
        try await request(path: "/v1/health", method: "GET", body: nil, requiresPairing: false)
    }

    func pair(code: String) async throws {
        struct PairRequest: Encodable {
            let deviceID: String
            let deviceName: String
            let oneTimeCode: String
            enum CodingKeys: String, CodingKey {
                case deviceID = "device_id"
                case deviceName = "device_name"
                case oneTimeCode = "one_time_code"
            }
        }
        let body = try encoder.encode(PairRequest(
            deviceID: deviceID,
            deviceName: UIDevice.current.name,
            oneTimeCode: code
        ))
        let response: CowboyPairResponse = try await request(
            path: "/v1/pair", method: "POST", body: body, requiresPairing: false
        )
        try CowboyKeychain.save(response.deviceToken)
    }

    func syncGraph(supabaseToken: String) async throws -> CowboyHealthEnvelope {
        struct SyncResponse: Decodable {
            let graphRevision: String
            let acceptedAxiomCount: Int
            enum CodingKeys: String, CodingKey {
                case graphRevision = "graph_revision"
                case acceptedAxiomCount = "accepted_axiom_count"
            }
        }
        let _: SyncResponse = try await request(
            path: "/v1/graph/sync",
            method: "POST",
            body: Data("{}".utf8),
            extraHeaders: ["X-Supabase-Access-Token": supabaseToken]
        )
        return try await health()
    }

    func reason(_ request: ReasoningRequest, supabaseToken: String?) async throws -> ReasoningEnvelope {
        if isAvailable {
            do {
                return try await self.request(
                    path: "/v1/reason",
                    method: "POST",
                    body: try encoder.encode(request),
                    extraHeaders: supabaseToken.map { ["X-Supabase-Access-Token": $0] } ?? [:]
                )
            } catch where request.connectivityState != "online" {
                throw error
            } catch {
                // The Mac path is unavailable. The fallback below remains visibly labeled.
            }
        }
        guard request.connectivityState == "online", let supabaseToken else {
            throw CowboyGatewayError.notDiscovered
        }
        return try await cloudReason(request, token: supabaseToken)
    }

    func saveTrainingExample(
        rawWords: String,
        envelope: ReasoningEnvelope,
        acceptedResponse: String,
        rejectedResponse: String?,
        correction: String?
    ) async throws {
        struct TrainingRequest: Encodable {
            let source: String
            let rawWords: String
            let acceptedResponse: String
            let rejectedResponse: String?
            let acceptedBeliefIDs: [String]
            let graphRevision: String
            let correction: String?
            let approvalStatus: String
            enum CodingKeys: String, CodingKey {
                case source
                case rawWords = "raw_words"
                case acceptedResponse = "accepted_response"
                case rejectedResponse = "rejected_response"
                case acceptedBeliefIDs = "accepted_belief_ids"
                case graphRevision = "graph_revision"
                case correction
                case approvalStatus = "approval_status"
            }
        }
        struct Acknowledgement: Decodable { let id: String }
        let body = try encoder.encode(TrainingRequest(
            source: "Adam review in Understood",
            rawWords: rawWords,
            acceptedResponse: acceptedResponse,
            rejectedResponse: rejectedResponse,
            acceptedBeliefIDs: envelope.acceptedAuthorityUsed.map(\.beliefID),
            graphRevision: envelope.graphRevision,
            correction: correction,
            approvalStatus: "accepted"
        ))
        let _: Acknowledgement = try await request(
            path: "/v1/training/examples", method: "POST", body: body
        )
    }

    func reviewCandidate(id: String, status: String) async throws {
        struct Review: Encodable { let status: String }
        struct Acknowledgement: Decodable {
            let candidateID: String
            enum CodingKeys: String, CodingKey { case candidateID = "candidate_id" }
        }
        let _: Acknowledgement = try await request(
            path: "/v1/candidates/\(id)/review",
            method: "POST",
            body: try encoder.encode(Review(status: status))
        )
    }

    private func cloudReason(_ request: ReasoningRequest, token: String) async throws -> ReasoningEnvelope {
        guard let url = URL(string: "\(SupabaseService.apiBaseURL)/api/reason") else {
            throw CowboyGatewayError.cloudUnavailable
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try encoder.encode(request)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CowboyGatewayError.cloudUnavailable
        }
        return try decoder.decode(ReasoningEnvelope.self, from: data)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: Data?,
        requiresPairing: Bool = true,
        extraHeaders: [String: String] = [:]
    ) async throws -> Response {
        var headers = extraHeaders
        if requiresPairing {
            guard let token = CowboyKeychain.read() else { throw CowboyGatewayError.http(401, "Pair this iPhone first") }
            headers["Authorization"] = "Bearer \(token)"
            headers["X-Cowboy-Device-ID"] = deviceID
        }
        let data: Data
        if let endpoint {
            data = try await transport.send(
                endpoint: endpoint, method: method, path: path, headers: headers, body: body
            )
        } else if let remoteBaseURL {
            var urlRequest = URLRequest(url: remoteBaseURL.appending(path: path))
            urlRequest.httpMethod = method
            headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
            if body != nil { urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            urlRequest.httpBody = body
            let (remoteData, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw CowboyGatewayError.http(
                    (response as? HTTPURLResponse)?.statusCode ?? 0,
                    "Mac gateway unavailable"
                )
            }
            data = remoteData
        } else {
            throw CowboyGatewayError.notDiscovered
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private final class CowboyHTTPTransport: @unchecked Sendable {
    func send(
        endpoint: NWEndpoint,
        method: String,
        path: String,
        headers: [String: String],
        body: Data?
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(to: endpoint, using: .tcp)
            let state = CowboyHTTPExchangeState()

            func finish(_ result: Result<Data, Error>) {
                guard state.markFinished() else { return }
                connection.cancel()
                continuation.resume(with: result)
            }

            var requestHeaders = headers
            requestHeaders["Host"] = "cowboyai.local"
            requestHeaders["Accept"] = "application/json"
            requestHeaders["Connection"] = "close"
            if body != nil { requestHeaders["Content-Type"] = "application/json" }
            requestHeaders["Content-Length"] = String(body?.count ?? 0)
            let headerLines = requestHeaders.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n")
            var requestData = Data("\(method) \(path) HTTP/1.1\r\n\(headerLines)\r\n\r\n".utf8)
            if let body { requestData.append(body) }
            let outboundData = requestData

            var receiveNext: (() -> Void)!
            receiveNext = {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { data, _, complete, error in
                    if let data { state.append(data) }
                    if let error { finish(.failure(error)); return }
                    if complete {
                        do { finish(.success(try Self.parseHTTPResponse(state.data))) }
                        catch { finish(.failure(error)) }
                    } else {
                        receiveNext()
                    }
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: outboundData, completion: .contentProcessed { error in
                        if let error { finish(.failure(error)) }
                        else { receiveNext() }
                    })
                case .failed(let error): finish(.failure(error))
                case .cancelled:
                    finish(.failure(CowboyGatewayError.invalidResponse))
                default: break
                }
            }
            connection.start(queue: DispatchQueue(label: "understood.cowboyai.http"))
        }
    }

    private static func parseHTTPResponse(_ data: Data) throws -> Data {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator),
              let header = String(data: data[..<range.lowerBound], encoding: .utf8),
              let statusText = header.components(separatedBy: "\r\n").first,
              let status = Int(statusText.split(separator: " ").dropFirst().first ?? "") else {
            throw CowboyGatewayError.invalidResponse
        }
        let body = Data(data[range.upperBound...])
        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["detail"] as? String
                ?? String(data: body, encoding: .utf8)
                ?? "Unknown error"
            throw CowboyGatewayError.http(status, message)
        }
        return body
    }
}

private nonisolated final class CowboyHTTPExchangeState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var received = Data()

    var data: Data {
        lock.withLock { received }
    }

    func append(_ data: Data) {
        lock.withLock { received.append(data) }
    }

    func markFinished() -> Bool {
        lock.withLock {
            guard !finished else { return false }
            finished = true
            return true
        }
    }
}
