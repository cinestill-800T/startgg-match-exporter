import Foundation

struct ExportOptions: Sendable {
    var setPageSize: Int = 50
    var entrantPageSize: Int = 100
    var standingPageSize: Int = 100
    var minimumRequestIntervalSeconds: TimeInterval = 0.8
}

struct ExportProgress: Sendable, Equatable {
    var stage: String
    var detail: String
    var current: Int
    var total: Int?
}

final class RequestThrottler {
    private var lastRequestAt: Date?
    private let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    func waitIfNeeded() async {
        guard let lastRequestAt else {
            self.lastRequestAt = Date()
            return
        }

        let elapsed = Date().timeIntervalSince(lastRequestAt)
        if elapsed < minimumInterval {
            let delay = UInt64((minimumInterval - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }
        self.lastRequestAt = Date()
    }
}

final class ExportService {
    typealias ProgressHandler = @Sendable (ExportProgress) async -> Void

    private let options: ExportOptions
    private let progress: ProgressHandler

    init(options: ExportOptions = ExportOptions(), progress: @escaping ProgressHandler = { _ in }) {
        self.options = options
        self.progress = progress
    }

    func export(from inputURL: String, token: String) async throws -> ExportDocument {
        let eventSlug = try StartGGURLParser.eventSlug(from: inputURL)
        let client = StartGGClient(token: token)
        let throttler = RequestThrottler(minimumInterval: options.minimumRequestIntervalSeconds)

        await progress(ExportProgress(stage: "event", detail: "Loading event summary", current: 0, total: nil))
        let eventData: EventSummaryData = try await send(
            client: client,
            throttler: throttler,
            operationName: "EventSummary",
            query: StartGGQueries.eventSummary,
            variables: ["slug": .string(eventSlug)]
        )

        guard let event = eventData.event else {
            throw StartGGClientError.missingData
        }

        let fetchedEntrants = try await fetchEntrants(eventId: event.id, client: client, throttler: throttler)
        let fetchedStandings = try await fetchStandings(eventId: event.id, client: client, throttler: throttler)

        var phaseExports: [PhaseExport] = []
        for (index, phase) in event.phases.enumerated() {
            try Task.checkCancellation()
            let sets = try await fetchSets(phase: phase, client: client, throttler: throttler, phaseIndex: index, phaseTotal: event.phases.count)
            phaseExports.append(makePhaseExport(phase: phase, sets: sets))
        }

        let allSets = phaseExports.flatMap(\.sets)

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: ISO8601DateFormatter().string(from: Date()),
            source: ExportSource(
                inputURL: inputURL,
                eventSlug: eventSlug,
                apiEndpoint: client.endpoint.absoluteString
            ),
            summary: ExportSummary(
                phaseCount: event.phases.count,
                entrantCount: fetchedEntrants.count,
                standingCount: fetchedStandings.count,
                setCount: allSets.count,
                completedSetCount: allSets.filter { $0.state == 3 }.count,
                pendingSetCount: allSets.filter { $0.state == 1 }.count,
                startedSetCount: allSets.filter { $0.state == 2 || $0.state == 6 }.count
            ),
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

    private func send<T: Decodable>(
        client: StartGGClient,
        throttler: RequestThrottler,
        operationName: String,
        query: String,
        variables: [String: GraphQLValue]
    ) async throws -> T {
        await throttler.waitIfNeeded()
        return try await client.send(operationName: operationName, query: query, variables: variables)
    }

    private func fetchEntrants(
        eventId: FlexibleID,
        client: StartGGClient,
        throttler: RequestThrottler
    ) async throws -> [Entrant] {
        var entrants: [Entrant] = []
        var page = 1
        var totalPages = 1

        repeat {
            try Task.checkCancellation()
            await progress(ExportProgress(stage: "entrants", detail: "Loading entrants page \(page)", current: page, total: totalPages))
            let data: EventEntrantsData = try await send(
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
            page += 1
        } while page <= totalPages

        return entrants
    }

    private func fetchStandings(
        eventId: FlexibleID,
        client: StartGGClient,
        throttler: RequestThrottler
    ) async throws -> [Standing] {
        var standings: [Standing] = []
        var page = 1
        var totalPages = 1

        repeat {
            try Task.checkCancellation()
            await progress(ExportProgress(stage: "standings", detail: "Loading standings page \(page)", current: page, total: totalPages))
            let data: EventStandingsData = try await send(
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
            page += 1
        } while page <= totalPages

        return standings
    }

    private func fetchSets(
        phase: PhaseSummary,
        client: StartGGClient,
        throttler: RequestThrottler,
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
                    detail: "Loading \(phaseName) page \(page)",
                    current: phaseIndex + 1,
                    total: phaseTotal
                )
            )
            let data: PhaseSetsData = try await send(
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
            page += 1
        } while page <= totalPages

        return sets
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
}
