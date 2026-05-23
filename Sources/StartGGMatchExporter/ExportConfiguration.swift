import Foundation

struct ExportConfiguration: Codable, Sendable, Equatable {
    var _notes: [String]
    var officialAPI: ExportAPIConfiguration
    var publicAPI: ExportAPIConfiguration

    static let defaultConfiguration = ExportConfiguration(
        _notes: [
            "StartGG Match Exporter loads this file at the beginning of each fetch.",
            "The defaults are intentionally balanced: faster than the emergency-safe values, but still below start.gg's documented average rate limit.",
            "If HTTP 429 appears, increase minimumRequestIntervalSeconds or lower concurrentRequests, then run Fetch Data with Use local cache enabled.",
            "Use Refresh only when you intentionally want to ignore the cache and rebuild the export from start.gg.",
            "Page sizes affect start.gg's GraphQL object complexity. Raising them can make a request fail even when the request rate is low."
        ],
        officialAPI: ExportAPIConfiguration(
            _notes: [
                "Used when an API token is present.",
                "setPageSize controls set result pages. Keep this small because every set includes nested slots and entrants.",
                "entrantPageSize controls the static entrant list. It is usually safe to raise gradually before changing setPageSize.",
                "standingPageSize controls standings pages. Standings can be broad, so raise with care.",
                "minimumRequestIntervalSeconds is the main speed knob. 1.2 seconds is about 50 requests per minute. 0.8 seconds approaches 75 requests per minute.",
                "concurrentRequests should stay at 1 for the safest behavior. Try 2 only after several successful cached runs.",
                "rateLimit pause values control how long the app waits after HTTP 429 before retrying."
            ],
            setPageSize: 10,
            entrantPageSize: 25,
            standingPageSize: 10,
            minimumRequestIntervalSeconds: 1.2,
            concurrentRequests: 1,
            maxRetries: 8,
            rateLimitInitialPauseSeconds: 45,
            rateLimitPauseIncrementSeconds: 30,
            rateLimitMaxPauseSeconds: 180,
            serverErrorInitialPauseSeconds: 1.5,
            serverErrorMaxPauseSeconds: 30
        ),
        publicAPI: ExportAPIConfiguration(
            _notes: [
                "Used when the token field is blank.",
                "The public endpoint is convenient but less suitable for sustained exports. Prefer an API token for large events.",
                "Keep concurrentRequests at 1 unless you are only testing small events.",
                "If the public endpoint slows down or fails, wait a few minutes or switch to authenticated mode."
            ],
            setPageSize: 50,
            entrantPageSize: 100,
            standingPageSize: 100,
            minimumRequestIntervalSeconds: 0.8,
            concurrentRequests: 1,
            maxRetries: 6,
            rateLimitInitialPauseSeconds: 60,
            rateLimitPauseIncrementSeconds: 45,
            rateLimitMaxPauseSeconds: 240,
            serverErrorInitialPauseSeconds: 2,
            serverErrorMaxPauseSeconds: 45
        )
    )

    func options(for mode: StartGGAPIMode) -> ExportOptions {
        switch mode {
        case .authenticatedFast:
            officialAPI.options()
        case .publicSafe:
            publicAPI.options()
        }
    }
}

struct ExportAPIConfiguration: Codable, Sendable, Equatable {
    var _notes: [String]
    var setPageSize: Int
    var entrantPageSize: Int
    var standingPageSize: Int
    var minimumRequestIntervalSeconds: TimeInterval
    var concurrentRequests: Int
    var maxRetries: Int
    var rateLimitInitialPauseSeconds: TimeInterval
    var rateLimitPauseIncrementSeconds: TimeInterval
    var rateLimitMaxPauseSeconds: TimeInterval
    var serverErrorInitialPauseSeconds: TimeInterval
    var serverErrorMaxPauseSeconds: TimeInterval

    func options() -> ExportOptions {
        ExportOptions(
            setPageSize: clamp(setPageSize, min: 1, max: 100),
            entrantPageSize: clamp(entrantPageSize, min: 1, max: 200),
            standingPageSize: clamp(standingPageSize, min: 1, max: 200),
            minimumRequestIntervalSeconds: max(0.2, min(minimumRequestIntervalSeconds, 30)),
            concurrentPageRequests: clamp(concurrentRequests, min: 1, max: 4),
            retryPolicy: StartGGRetryPolicy(
                maxRetries: maxRetries,
                rateLimitInitialPauseSeconds: rateLimitInitialPauseSeconds,
                rateLimitPauseIncrementSeconds: rateLimitPauseIncrementSeconds,
                rateLimitMaxPauseSeconds: rateLimitMaxPauseSeconds,
                serverErrorInitialPauseSeconds: serverErrorInitialPauseSeconds,
                serverErrorMaxPauseSeconds: serverErrorMaxPauseSeconds
            ).clamped()
        )
    }

    private func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.max(minimum, Swift.min(value, maximum))
    }
}

enum ExportConfigurationStore {
    struct LoadResult: Sendable {
        var configuration: ExportConfiguration
        var url: URL?
        var warning: String?
    }

    private static let folderName = "StartGGMatchExporter"
    private static let filename = "config.json"

    static func loadOrCreate() -> LoadResult {
        guard let url = configURL else {
            return LoadResult(
                configuration: .defaultConfiguration,
                url: nil,
                warning: "Application Support folder is unavailable. Built-in pacing defaults will be used."
            )
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try writeDefault(to: url)
            } catch {
                return LoadResult(
                    configuration: .defaultConfiguration,
                    url: url,
                    warning: "Config file could not be created: \(error.localizedDescription)"
                )
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let configuration = try JSONDecoder().decode(ExportConfiguration.self, from: data)
            return LoadResult(configuration: configuration, url: url, warning: nil)
        } catch {
            return LoadResult(
                configuration: .defaultConfiguration,
                url: url,
                warning: "Config file could not be read. Built-in defaults will be used until the JSON is fixed or deleted. \(error.localizedDescription)"
            )
        }
    }

    static var configURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(filename)
    }

    private static func writeDefault(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(ExportConfiguration.defaultConfiguration)
        try data.write(to: url, options: .atomic)
    }
}
