import Foundation

struct StartGGRetryPolicy: Sendable, Equatable {
    var maxRetries: Int
    var rateLimitInitialPauseSeconds: TimeInterval
    var rateLimitPauseIncrementSeconds: TimeInterval
    var rateLimitMaxPauseSeconds: TimeInterval
    var serverErrorInitialPauseSeconds: TimeInterval
    var serverErrorMaxPauseSeconds: TimeInterval

    static let defaultPolicy = StartGGRetryPolicy(
        maxRetries: 8,
        rateLimitInitialPauseSeconds: 45,
        rateLimitPauseIncrementSeconds: 30,
        rateLimitMaxPauseSeconds: 180,
        serverErrorInitialPauseSeconds: 1.5,
        serverErrorMaxPauseSeconds: 30
    )

    func clamped() -> StartGGRetryPolicy {
        StartGGRetryPolicy(
            maxRetries: max(1, min(maxRetries, 20)),
            rateLimitInitialPauseSeconds: max(10, min(rateLimitInitialPauseSeconds, 600)),
            rateLimitPauseIncrementSeconds: max(5, min(rateLimitPauseIncrementSeconds, 300)),
            rateLimitMaxPauseSeconds: max(10, min(rateLimitMaxPauseSeconds, 900)),
            serverErrorInitialPauseSeconds: max(0.5, min(serverErrorInitialPauseSeconds, 120)),
            serverErrorMaxPauseSeconds: max(1, min(serverErrorMaxPauseSeconds, 300))
        )
    }

    func delaySeconds(for status: Int, attempt: Int) -> Double {
        let policy = clamped()
        if status == 429 {
            let delay = policy.rateLimitInitialPauseSeconds + Double(attempt) * policy.rateLimitPauseIncrementSeconds
            return min(policy.rateLimitMaxPauseSeconds, delay)
        }
        let delay = pow(2.0, Double(attempt)) * policy.serverErrorInitialPauseSeconds
        return min(policy.serverErrorMaxPauseSeconds, delay)
    }
}

enum StartGGAPIMode: String, Codable, Sendable {
    case authenticatedFast
    case publicSafe

    var endpoint: URL {
        switch self {
        case .authenticatedFast:
            URL(string: "https://api.start.gg/gql/alpha")!
        case .publicSafe:
            URL(string: "https://www.start.gg/api/-/gql")!
        }
    }

    var title: String {
        switch self {
        case .authenticatedFast:
            "Authenticated Safe Mode"
        case .publicSafe:
            "Public Safe Mode"
        }
    }

    var shortDescription: String {
        switch self {
        case .authenticatedFast:
            "Token detected. Uses the official API with conservative pacing."
        case .publicSafe:
            "No token. Uses public web data with conservative pacing."
        }
    }

    var helpText: String {
        switch self {
        case .authenticatedFast:
            "Authenticated Safe Mode uses your start.gg API token and intentionally slow sequential reads to avoid complexity and rate-limit failures."
        case .publicSafe:
            "Public Safe Mode does not require a token. It uses start.gg public web data and runs more slowly because that endpoint is less suitable for sustained export work."
        }
    }

    static func resolved(for token: String) -> StartGGAPIMode {
        token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .publicSafe : .authenticatedFast
    }
}

enum StartGGClientError: LocalizedError {
    case missingToken
    case invalidHTTPStatus(Int, String)
    case graphQLErrors([GraphQLError])
    case rateLimited(String)
    case missingData

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "A start.gg API token is required."
        case .invalidHTTPStatus(let status, let body):
            return "start.gg returned HTTP \(status): \(body)"
        case .graphQLErrors(let errors):
            return errors.map(\.message).joined(separator: "\n")
        case .rateLimited(let message):
            return message
        case .missingData:
            return "start.gg returned no data."
        }
    }
}

final class StartGGClient: Sendable {
    private static let requestEncoder = JSONEncoder()
    private static let requestEncoderLock = NSLock()

    let endpoint: URL
    let mode: StartGGAPIMode
    private let token: String
    private let session: URLSession
    private let retryPolicy: StartGGRetryPolicy

    init(
        token: String,
        mode: StartGGAPIMode? = nil,
        session: URLSession = .shared,
        retryPolicy: StartGGRetryPolicy = .defaultPolicy
    ) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode ?? StartGGAPIMode.resolved(for: token)
        self.endpoint = self.mode.endpoint
        self.session = session
        self.retryPolicy = retryPolicy.clamped()
    }

    func send<T: Decodable>(
        operationName: String,
        query: String,
        variables: [String: GraphQLValue]
    ) async throws -> T {
        if mode == .authenticatedFast, token.isEmpty {
            throw StartGGClientError.missingToken
        }

        let requestBody = try Self.encodeRequestBody(
            GraphQLRequestBody(query: query, operationName: operationName, variables: variables)
        )

        var attempt = 0
        var lastError: Error?
        var lastStatus: Int?
        while attempt < retryPolicy.maxRetries {
            do {
                return try await sendOnce(requestBody: requestBody)
            } catch StartGGClientError.invalidHTTPStatus(let status, let body) where status == 429 || (500..<600).contains(status) {
                lastError = StartGGClientError.invalidHTTPStatus(status, body)
                lastStatus = status
                let seconds = retryPolicy.delaySeconds(for: status, attempt: attempt)
                let delay = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
                attempt += 1
            } catch {
                throw error
            }
        }

        if lastStatus == 429 {
            throw StartGGClientError.rateLimited("start.gg rate limit is still active after waiting and retrying. Use cached data for now, or wait several minutes before refreshing.")
        }
        if let lastError {
            throw lastError
        }
        throw StartGGClientError.missingData
    }

    private func sendOnce<T: Decodable>(requestBody: Data) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("StartGGMatchExporter/2.0", forHTTPHeaderField: "User-Agent")

        switch mode {
        case .authenticatedFast:
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .publicSafe:
            request.setValue("20", forHTTPHeaderField: "client-version")
            request.setValue("gg-web-gql-client, gg-web-rest", forHTTPHeaderField: "x-web-source")
            request.setValue("smashgg-legacy", forHTTPHeaderField: "apollo-client-id")
        }

        request.httpBody = requestBody

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StartGGClientError.missingData
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StartGGClientError.invalidHTTPStatus(httpResponse.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw StartGGClientError.graphQLErrors(errors)
        }
        guard let responseData = decoded.data else {
            throw StartGGClientError.missingData
        }
        return responseData
    }

    private static func encodeRequestBody(_ body: GraphQLRequestBody) throws -> Data {
        requestEncoderLock.lock()
        defer { requestEncoderLock.unlock() }
        return try requestEncoder.encode(body)
    }
}
