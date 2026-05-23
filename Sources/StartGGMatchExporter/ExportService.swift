import Foundation

struct ExportOptions: Sendable {
    var setPageSize: Int = 50
    var entrantPageSize: Int = 100
    var standingPageSize: Int = 100
    var minimumRequestIntervalSeconds: TimeInterval = 0.8
    var concurrentPageRequests: Int = 1
    var retryPolicy: StartGGRetryPolicy = .defaultPolicy

    static func defaults(for mode: StartGGAPIMode) -> ExportOptions {
        ExportConfiguration.defaultConfiguration.options(for: mode)
    }
}

struct ExportProgress: Sendable, Equatable {
    var stage: String
    var detail: String
    var current: Int
    var total: Int?
}

actor RequestThrottler {
    private var nextRequestAt: Date?
    private let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    func waitIfNeeded() async throws {
        let now = Date()
        guard let nextRequestAt else {
            self.nextRequestAt = now.addingTimeInterval(minimumInterval)
            return
        }

        if now < nextRequestAt {
            let delay = UInt64(nextRequestAt.timeIntervalSince(now) * 1_000_000_000)
            try await Task.sleep(nanoseconds: delay)
        }
        self.nextRequestAt = Date().addingTimeInterval(minimumInterval)
    }
}

final class ExportService: @unchecked Sendable {
    typealias ProgressHandler = @Sendable (ExportProgress) async -> Void
    typealias PartialDocumentHandler = @Sendable (ExportDocument) async -> Void

    private let optionOverride: ExportOptions?
    private let progress: ProgressHandler
    private let partialDocumentHandler: PartialDocumentHandler

    init(
        options: ExportOptions? = nil,
        progress: @escaping ProgressHandler = { _ in },
        partialDocumentHandler: @escaping PartialDocumentHandler = { _ in }
    ) {
        optionOverride = options
        self.progress = progress
        self.partialDocumentHandler = partialDocumentHandler
    }

    func export(from inputURL: String, token: String) async throws -> ExportDocument {
        return try await export(from: inputURL, token: token, cachedDocument: nil)
    }

    func export(from inputURL: String, token: String, cachedDocument: ExportDocument?) async throws -> ExportDocument {
        let eventSlug = try StartGGURLParser.eventSlug(from: inputURL)
        let mode = StartGGAPIMode.resolved(for: token)
        let options = optionOverride ?? ExportOptions.defaults(for: mode)
        let client = StartGGClient(token: token, mode: mode, retryPolicy: options.retryPolicy)
        let throttler = RequestThrottler(minimumInterval: options.minimumRequestIntervalSeconds)
        let usableCache = cachedDocument?.source.eventSlug == eventSlug && cachedDocument?.source.apiMode == mode.rawValue ? cachedDocument : nil

        await progress(ExportProgress(stage: "event", detail: "Loading event summary with \(mode.title)", current: 0, total: nil))
        let eventData: EventSummaryData = try await Self.send(
            client: client,
            throttler: throttler,
            operationName: "EventSummary",
            query: StartGGQueries.eventSummary(for: mode),
            variables: ["slug": .string(eventSlug)]
        )

        guard let event = eventData.event else {
            throw StartGGClientError.missingData
        }

        let fetchedEntrants: [Entrant]
        if let cachedEntrants = usableCache?.entrants, !cachedEntrants.isEmpty {
            fetchedEntrants = cachedEntrants
            await progress(ExportProgress(stage: "entrants", detail: "Using cached entrants", current: 1, total: 1))
        } else {
            fetchedEntrants = try await fetchEntrants(eventId: event.id, client: client, throttler: throttler, options: options)
        }

        let fetchedStandings: [Standing]
        if let cachedStandings = usableCache?.standings, !cachedStandings.isEmpty {
            fetchedStandings = cachedStandings
            await progress(ExportProgress(stage: "standings", detail: "Using cached standings", current: 1, total: 1))
        } else {
            fetchedStandings = try await fetchStandings(eventId: event.id, client: client, throttler: throttler, options: options)
        }

        var phaseExports: [PhaseExport] = []
        await partialDocumentHandler(
            makeDocument(
                inputURL: inputURL,
                eventSlug: eventSlug,
                client: client,
                mode: mode,
                event: event,
                entrants: fetchedEntrants,
                standings: fetchedStandings,
                phases: phaseExports
            )
        )

        for (index, phase) in event.phases.enumerated() {
            try Task.checkCancellation()
            if let cachedPhase = usableCache?.phases.first(where: { $0.id == phase.id }), shouldReuse(cachedPhase: cachedPhase) {
                await progress(
                    ExportProgress(
                        stage: "sets",
                        detail: "Using cached completed \(phase.name ?? phase.id.value)",
                        current: index + 1,
                        total: event.phases.count
                    )
                )
                phaseExports.append(makePhaseExport(phase: phase, sets: cachedPhase.sets.map(SetNode.init)))
            } else {
                let sets = try await fetchSets(phase: phase, client: client, throttler: throttler, options: options, phaseIndex: index, phaseTotal: event.phases.count)
                phaseExports.append(makePhaseExport(phase: phase, sets: sets))
            }

            let partialDocument = makeDocument(
                inputURL: inputURL,
                eventSlug: eventSlug,
                client: client,
                mode: mode,
                event: event,
                entrants: fetchedEntrants,
                standings: fetchedStandings,
                phases: phaseExports
            )
            await partialDocumentHandler(partialDocument)
        }

        return makeDocument(
            inputURL: inputURL,
            eventSlug: eventSlug,
            client: client,
            mode: mode,
            event: event,
            entrants: fetchedEntrants,
            standings: fetchedStandings,
            phases: phaseExports
        )
    }

    func encode(_ document: ExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    private func makeDocument(
        inputURL: String,
        eventSlug: String,
        client: StartGGClient,
        mode: StartGGAPIMode,
        event: EventSummary,
        entrants: [Entrant],
        standings: [Standing],
        phases: [PhaseExport]
    ) -> ExportDocument {
        let allSets = phases.flatMap(\.sets)

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: ISO8601DateFormatter().string(from: Date()),
            source: ExportSource(
                inputURL: inputURL,
                eventSlug: eventSlug,
                apiEndpoint: client.endpoint.absoluteString,
                apiMode: mode.rawValue
            ),
            summary: ExportSummary(
                phaseCount: event.phases.count,
                entrantCount: entrants.count,
                standingCount: standings.count,
                setCount: allSets.count,
                completedSetCount: allSets.filter { $0.state == 3 }.count,
                pendingSetCount: allSets.filter { $0.state == 1 }.count,
                startedSetCount: allSets.filter { $0.state == 2 || $0.state == 6 }.count
            ),
            event: event,
            entrants: entrants,
            standings: standings,
            phases: phases
        )
    }

    private static func send<T: Decodable>(
        client: StartGGClient,
        throttler: RequestThrottler,
        operationName: String,
        query: String,
        variables: [String: GraphQLValue]
    ) async throws -> T {
        try await throttler.waitIfNeeded()
        return try await client.send(operationName: operationName, query: query, variables: variables)
    }

    private func fetchEntrants(
        eventId: FlexibleID,
        client: StartGGClient,
        throttler: RequestThrottler,
        options: ExportOptions
    ) async throws -> [Entrant] {
        var entrants: [Entrant] = []
        var page = 1
        var totalPages = 1

        repeat {
            try Task.checkCancellation()
            await progress(ExportProgress(stage: "entrants", detail: "Loading entrants page \(page)", current: page, total: totalPages))
            let data: EventEntrantsData = try await Self.send(
                client: client,
                throttler: throttler,
                operationName: "EventEntrants",
                query: StartGGQueries.eventEntrants,
                variables: [
                    "eventId": .string(eventId.value),
                    "page": .int(page),
                    "perPage": .int(options.entrantPageSize)
                ]
            )
            guard let connection = data.event?.entrants else {
                throw StartGGClientError.missingData
            }
            totalPages = connection.pageInfo.resolvedTotalPages(defaultPerPage: options.entrantPageSize)
            entrants.append(contentsOf: connection.nodes)
            if page == 1, options.concurrentPageRequests > 1, totalPages > 1 {
                let remaining = try await fetchEntrantPages(
                    pages: Array(2...totalPages),
                    eventId: eventId,
                    client: client,
                    throttler: throttler,
                    options: options
                )
                entrants.append(contentsOf: remaining)
                break
            } else {
                page += 1
            }
        } while page <= totalPages

        return entrants
    }

    private func fetchStandings(
        eventId: FlexibleID,
        client: StartGGClient,
        throttler: RequestThrottler,
        options: ExportOptions
    ) async throws -> [Standing] {
        var standings: [Standing] = []
        var page = 1
        var totalPages = 1

        repeat {
            try Task.checkCancellation()
            await progress(ExportProgress(stage: "standings", detail: "Loading standings page \(page)", current: page, total: totalPages))
            let data: EventStandingsData = try await Self.send(
                client: client,
                throttler: throttler,
                operationName: "EventStandings",
                query: StartGGQueries.eventStandings,
                variables: [
                    "eventId": .string(eventId.value),
                    "page": .int(page),
                    "perPage": .int(options.standingPageSize)
                ]
            )
            guard let connection = data.event?.standings else {
                throw StartGGClientError.missingData
            }
            totalPages = connection.pageInfo.resolvedTotalPages(defaultPerPage: options.standingPageSize)
            standings.append(contentsOf: connection.nodes)
            if page == 1, options.concurrentPageRequests > 1, totalPages > 1 {
                let remaining = try await fetchStandingPages(
                    pages: Array(2...totalPages),
                    eventId: eventId,
                    client: client,
                    throttler: throttler,
                    options: options
                )
                standings.append(contentsOf: remaining)
                break
            } else {
                page += 1
            }
        } while page <= totalPages

        return standings
    }

    private func fetchSets(
        phase: PhaseSummary,
        client: StartGGClient,
        throttler: RequestThrottler,
        options: ExportOptions,
        phaseIndex: Int,
        phaseTotal: Int
    ) async throws -> [SetNode] {
        var sets: [SetNode] = []
        var page = 1
        var totalPages = 1
        let phaseName = phase.name ?? phase.id.value

        repeat {
            try Task.checkCancellation()
            await progress(
                ExportProgress(
                    stage: "sets",
                    detail: "Loading \(phaseName) page \(page) of \(totalPages)",
                    current: phaseIndex + 1,
                    total: phaseTotal
                )
            )
            let data: PhaseSetsData = try await Self.send(
                client: client,
                throttler: throttler,
                operationName: "PhaseSets",
                query: StartGGQueries.phaseSets,
                variables: [
                    "phaseId": .string(phase.id.value),
                    "page": .int(page),
                    "perPage": .int(options.setPageSize)
                ]
            )
            guard let connection = data.phase?.sets else {
                throw StartGGClientError.missingData
            }
            totalPages = connection.pageInfo.resolvedTotalPages(defaultPerPage: options.setPageSize)
            sets.append(contentsOf: connection.nodes)
            if page == 1, options.concurrentPageRequests > 1, totalPages > 1 {
                let remaining = try await fetchSetPages(
                    pages: Array(2...totalPages),
                    phase: phase,
                    phaseName: phaseName,
                    client: client,
                    throttler: throttler,
                    options: options,
                    phaseIndex: phaseIndex,
                    phaseTotal: phaseTotal,
                    totalPages: totalPages
                )
                sets.append(contentsOf: remaining)
                break
            } else {
                page += 1
            }
        } while page <= totalPages

        return sets
    }

    private func fetchEntrantPages(
        pages: [Int],
        eventId: FlexibleID,
        client: StartGGClient,
        throttler: RequestThrottler,
        options: ExportOptions
    ) async throws -> [Entrant] {
        let progress = self.progress
        let results: [(Int, [Entrant])] = try await fetchConcurrently(pages: pages, options: options) { page in
            await progress(ExportProgress(stage: "entrants", detail: "Loading entrants page \(page)", current: page, total: pages.last))
            let data: EventEntrantsData = try await Self.send(
                client: client,
                throttler: throttler,
                operationName: "EventEntrants",
                query: StartGGQueries.eventEntrants,
                variables: [
                    "eventId": .string(eventId.value),
                    "page": .int(page),
                    "perPage": .int(options.entrantPageSize)
                ]
            )
            guard let connection = data.event?.entrants else {
                throw StartGGClientError.missingData
            }
            return connection.nodes
        }
        return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
    }

    private func fetchStandingPages(
        pages: [Int],
        eventId: FlexibleID,
        client: StartGGClient,
        throttler: RequestThrottler,
        options: ExportOptions
    ) async throws -> [Standing] {
        let progress = self.progress
        let results: [(Int, [Standing])] = try await fetchConcurrently(pages: pages, options: options) { page in
            await progress(ExportProgress(stage: "standings", detail: "Loading standings page \(page)", current: page, total: pages.last))
            let data: EventStandingsData = try await Self.send(
                client: client,
                throttler: throttler,
                operationName: "EventStandings",
                query: StartGGQueries.eventStandings,
                variables: [
                    "eventId": .string(eventId.value),
                    "page": .int(page),
                    "perPage": .int(options.standingPageSize)
                ]
            )
            guard let connection = data.event?.standings else {
                throw StartGGClientError.missingData
            }
            return connection.nodes
        }
        return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
    }

    private func fetchSetPages(
        pages: [Int],
        phase: PhaseSummary,
        phaseName: String,
        client: StartGGClient,
        throttler: RequestThrottler,
        options: ExportOptions,
        phaseIndex: Int,
        phaseTotal: Int,
        totalPages: Int
    ) async throws -> [SetNode] {
        let progress = self.progress
        let results: [(Int, [SetNode])] = try await fetchConcurrently(pages: pages, options: options) { page in
            await progress(
                ExportProgress(
                    stage: "sets",
                    detail: "Loading \(phaseName) page \(page) of \(totalPages)",
                    current: phaseIndex + 1,
                    total: phaseTotal
                )
            )
            let data: PhaseSetsData = try await Self.send(
                client: client,
                throttler: throttler,
                operationName: "PhaseSets",
                query: StartGGQueries.phaseSets,
                variables: [
                    "phaseId": .string(phase.id.value),
                    "page": .int(page),
                    "perPage": .int(options.setPageSize)
                ]
            )
            guard let connection = data.phase?.sets else {
                throw StartGGClientError.missingData
            }
            return connection.nodes
        }
        return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
    }

    private func fetchConcurrently<Node: Sendable>(
        pages: [Int],
        options: ExportOptions,
        fetchPage: @escaping @Sendable (Int) async throws -> [Node]
    ) async throws -> [(Int, [Node])] {
        guard !pages.isEmpty else {
            return []
        }

        let maxConcurrent = max(1, options.concurrentPageRequests)
        var iterator = pages.makeIterator()
        var results: [(Int, [Node])] = []

        try await withThrowingTaskGroup(of: (Int, [Node]).self) { group in
            var active = 0

            func addNextPage() {
                guard let page = iterator.next() else {
                    return
                }
                active += 1
                group.addTask {
                    let nodes = try await fetchPage(page)
                    return (page, nodes)
                }
            }

            for _ in 0..<min(maxConcurrent, pages.count) {
                addNextPage()
            }

            while let result = try await group.next() {
                active -= 1
                results.append(result)
                if active < maxConcurrent {
                    addNextPage()
                }
            }
        }

        return results
    }

    private func makePhaseExport(phase: PhaseSummary, sets: [SetNode]) -> PhaseExport {
        let exportSets = sets.map(ExportSet.init)
        let groups = Dictionary(grouping: exportSets.compactMap(\.phaseGroup)) { $0.id }
        let groupSummaries = groups.map { id, refs -> PhaseGroupSummary in
            let groupSets = exportSets.filter { $0.phaseGroup?.id == id }
            return PhaseGroupSummary(
                id: id,
                displayIdentifier: refs.first?.displayIdentifier,
                setCount: groupSets.count,
                completedSetCount: groupSets.filter { $0.state == 3 }.count,
                pendingSetCount: groupSets.filter { $0.state == 1 }.count,
                startedSetCount: groupSets.filter { $0.state == 2 || $0.state == 6 }.count
            )
        }
        .sorted { ($0.displayIdentifier ?? $0.id.value) < ($1.displayIdentifier ?? $1.id.value) }

        return PhaseExport(
            id: phase.id,
            name: phase.name,
            state: phase.state,
            groupCount: phase.groupCount,
            bracketType: phase.bracketType,
            numSeeds: phase.numSeeds,
            percentComplete: phase.percentComplete,
            destPhases: phase.destPhases,
            phaseGroups: groupSummaries,
            sets: exportSets
        )
    }

    private func shouldReuse(cachedPhase: PhaseExport) -> Bool {
        !cachedPhase.sets.isEmpty && cachedPhase.sets.allSatisfy { $0.state == 3 }
    }
}
