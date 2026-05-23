import Testing
@testable import StartGGMatchExporter

@Suite("Export configuration")
struct ExportConfigurationTests {
    @Test("Default config contains user-facing notes")
    func defaultConfigContainsNotes() {
        let config = ExportConfiguration.defaultConfiguration

        #expect(!config._notes.isEmpty)
        #expect(!config.officialAPI._notes.isEmpty)
        #expect(!config.publicAPI._notes.isEmpty)
        #expect(config._notes.contains { $0.contains("Fetch Data") })
        #expect(config.officialAPI._notes.contains { $0.contains("API Token") })
    }

    @Test("Default official configuration stays below the documented average rate")
    func defaultOfficialConfigurationStaysBelowRateLimit() {
        let options = ExportConfiguration.defaultConfiguration.options(for: .authenticatedFast)

        #expect(options.minimumRequestIntervalSeconds >= 0.8)
        #expect(options.concurrentPageRequests == 1)
        #expect(options.setPageSize <= 10)
        #expect(options.standingPageSize <= 10)
    }

    @Test("Config clamps unsafe values")
    func configClampsUnsafeValues() {
        let apiConfig = ExportAPIConfiguration(
            _notes: [],
            setPageSize: 1_000,
            entrantPageSize: 1_000,
            standingPageSize: 1_000,
            minimumRequestIntervalSeconds: 0,
            concurrentRequests: 99,
            maxRetries: 99,
            rateLimitInitialPauseSeconds: 1,
            rateLimitPauseIncrementSeconds: 1,
            rateLimitMaxPauseSeconds: 1_000,
            serverErrorInitialPauseSeconds: 0,
            serverErrorMaxPauseSeconds: 1_000
        )

        let options = apiConfig.options()

        #expect(options.setPageSize == 100)
        #expect(options.entrantPageSize == 200)
        #expect(options.standingPageSize == 200)
        #expect(options.minimumRequestIntervalSeconds == 0.2)
        #expect(options.concurrentPageRequests == 4)
        #expect(options.retryPolicy.maxRetries == 20)
    }

    @Test("Refreshing notes preserves numeric tuning")
    func refreshingNotesPreservesNumericTuning() {
        var config = ExportConfiguration.defaultConfiguration
        config._notes = ["old"]
        config.officialAPI._notes = ["old official"]
        config.publicAPI._notes = ["old public"]
        config.officialAPI.minimumRequestIntervalSeconds = 0.9
        config.officialAPI.concurrentRequests = 2
        config.publicAPI.setPageSize = 25

        let refreshed = config.refreshingNotes()

        #expect(refreshed._notes == ExportConfiguration.defaultConfiguration._notes)
        #expect(refreshed.officialAPI._notes == ExportConfiguration.defaultConfiguration.officialAPI._notes)
        #expect(refreshed.publicAPI._notes == ExportConfiguration.defaultConfiguration.publicAPI._notes)
        #expect(refreshed.officialAPI.minimumRequestIntervalSeconds == 0.9)
        #expect(refreshed.officialAPI.concurrentRequests == 2)
        #expect(refreshed.publicAPI.setPageSize == 25)
    }
}
