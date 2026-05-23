import Foundation

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

final class StartGGClient {
    let endpoint: URL
    private let token: String
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        endpoint: URL = URL(string: "https://api.start.gg/gql/alpha")!,
        token: String,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    func send<T: Decodable>(
        operationName: String,
        query: String,
        variables: [String: GraphQLValue]
    ) async throws -> T {
        guard !token.isEmpty else {
            throw StartGGClientError.missingToken
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("StartGGMatchExporter/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try encoder.encode(
            GraphQLRequestBody(query: query, operationName: operationName, variables: variables)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StartGGClientError.missingData
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StartGGClientError.invalidHTTPStatus(httpResponse.statusCode, body)
        }

        let decoded = try decoder.decode(GraphQLResponse<T>.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw StartGGClientError.graphQLErrors(errors)
        }
        guard let responseData = decoded.data else {
            throw StartGGClientError.missingData
        }
        return responseData
    }
}
