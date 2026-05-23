import Foundation

enum StartGGURLParserError: LocalizedError, Equatable {
    case missingEventSlug

    var errorDescription: String? {
        switch self {
        case .missingEventSlug:
            return "Enter a start.gg event URL such as https://www.start.gg/tournament/name/event/street-fighter-6"
        }
    }
}

struct StartGGURLParser {
    static func eventSlug(from input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("tournament/"), trimmed.contains("/event/") {
            return stripTrailingPath(afterEventSlug: trimmed)
        }

        guard let url = URL(string: trimmed), let host = url.host?.lowercased(), host.contains("start.gg") else {
            throw StartGGURLParserError.missingEventSlug
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard
            let tournamentIndex = components.firstIndex(of: "tournament"),
            tournamentIndex + 3 < components.count,
            components[tournamentIndex + 2] == "event"
        else {
            throw StartGGURLParserError.missingEventSlug
        }

        let tournamentSlug = components[tournamentIndex + 1]
        let eventSlug = components[tournamentIndex + 3]
        return "tournament/\(tournamentSlug)/event/\(eventSlug)"
    }

    private static func stripTrailingPath(afterEventSlug slug: String) -> String {
        let components = slug.split(separator: "/").map(String.init)
        guard
            let tournamentIndex = components.firstIndex(of: "tournament"),
            tournamentIndex + 3 < components.count,
            components[tournamentIndex + 2] == "event"
        else {
            return slug
        }
        return components[tournamentIndex...(tournamentIndex + 3)].joined(separator: "/")
    }
}
