import Foundation

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
            "Fast Mode"
        case .publicSafe:
            "Public Safe Mode"
        }
    }

    var shortDescription: String {
        switch self {
        case .authenticatedFast:
            "Token detected. Uses the official API with larger pages and parallel page reads."
        case .publicSafe:
            "No token. Uses public web data with conservative pacing."
        }
    }

    var helpText: String {
        switch self {
        case .authenticatedFast:
            "Fast Mode uses your start.gg API token, larger page sizes, and a small amount of parallelism while still respecting rate limits."
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
    case missingData

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "A start.gg API token is required."
        case .invalidHTTPStatus(let status, let body):
            return "start.gg returned HTTP \(status): \(body)"
        case .graphQLErrors(let errors):
            return errors.map(\.message).joined(separator: "\n")
        case .missingData:
            return "start.gg returned no data."
        }
    }
}

final class StartGGClient: Sendable {
    let endpoint: URL
    let mode: StartGGAPIMode
    private let token: String
    private let session: URLSession

    init(
        token: String,
        mode: StartGGAPIMode? = nil,
        session: URLSession = .shared
    ) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode ?? StartGGAPIMode.resolved(for: token)
        self.endpoint = self.mode.endpoint
        self.session = session
    }

    func send<T: Decodable>(
        operationName: String,
        query: String,
        variables: [String: GraphQLValue]
    ) async throws -> T {
        if mode == .authenticatedFast, token.isEmpty {
            throw StartGGClientError.missingToken
        }

        let requestBody = try JSONEncoder().encode(
            GraphQLRequestBody(query: query, operationName: operationName, variables: variables)
        )

        var attempt = 0
        var lastError: Error?
        while attempt < 4 {
            do {
                return try await sendOnce(requestBody: requestBody)
            } catch StartGGClientError.invalidHTTPStatus(let status, _) where status == 429 || (500..<600).contains(status) {
                lastError = StartGGClientError.invalidHTTPStatus(status, "Retrying after transient response.")
                let delay = UInt64(pow(2.0, Double(attempt)) * 700_000_000)
                try await Task.sleep(nanoseconds: delay)
                attempt += 1
            } catch {
                throw error
            }
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
        request.setValue("StartGGMatchExporter/1.0", forHTTPHeaderField: "User-Agent")

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
}
