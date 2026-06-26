import Foundation
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
        #expect(config._notes.contains { $0.contains("Fetch") && $0.contains("Refresh") })
        #expect(config.officialAPI._notes.contains { $0.contains("API Token") })
    }

    @Test("Default official configuration stays below the documented average rate")
    func defaultOfficialConfigurationStaysBelowRateLimit() {
        let options = ExportConfiguration.defaultConfiguration.options(for: .authenticatedFast)

        #expect(options.minimumRequestIntervalSeconds >= 0.75)
        #expect(options.minimumRequestIntervalSeconds < 0.8)
        #expect(options.concurrentPageRequests == 2)
        #expect(options.setPageSize == 45)
        #expect(options.entrantPageSize == 150)
        #expect(options.standingPageSize == 45)
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
        config.autoFetchIntervalMinutes = 12
        config.officialAPI.minimumRequestIntervalSeconds = 0.9
        config.officialAPI.concurrentRequests = 2
        config.publicAPI.setPageSize = 25

        let refreshed = config.refreshingNotes()

        #expect(refreshed._notes == ExportConfiguration.defaultConfiguration._notes)
        #expect(refreshed.officialAPI._notes == ExportConfiguration.defaultConfiguration.officialAPI._notes)
        #expect(refreshed.publicAPI._notes == ExportConfiguration.defaultConfiguration.publicAPI._notes)
        #expect(refreshed.autoFetchIntervalMinutes == 12)
        #expect(refreshed.officialAPI.minimumRequestIntervalSeconds == 0.9)
        #expect(refreshed.officialAPI.concurrentRequests == 2)
        #expect(refreshed.publicAPI.setPageSize == 25)
    }

    @Test("Refreshing notes migrates previous default tuning")
    func refreshingNotesMigratesPreviousDefaultTuning() {
        var config = ExportConfiguration.defaultConfiguration
        config.officialAPI.setPageSize = 10
        config.officialAPI.entrantPageSize = 25
        config.officialAPI.standingPageSize = 10
        config.officialAPI.minimumRequestIntervalSeconds = 1.2
        config.officialAPI.concurrentRequests = 1
        config.publicAPI.setPageSize = 50
        config.publicAPI.entrantPageSize = 100
        config.publicAPI.minimumRequestIntervalSeconds = 0.8

        let refreshed = config.refreshingNotes()

        #expect(refreshed.officialAPI.setPageSize == ExportConfiguration.defaultConfiguration.officialAPI.setPageSize)
        #expect(refreshed.officialAPI.entrantPageSize == ExportConfiguration.defaultConfiguration.officialAPI.entrantPageSize)
        #expect(refreshed.officialAPI.minimumRequestIntervalSeconds == ExportConfiguration.defaultConfiguration.officialAPI.minimumRequestIntervalSeconds)
        #expect(refreshed.officialAPI.concurrentRequests == ExportConfiguration.defaultConfiguration.officialAPI.concurrentRequests)
        #expect(refreshed.publicAPI.setPageSize == ExportConfiguration.defaultConfiguration.publicAPI.setPageSize)
        #expect(refreshed.publicAPI.entrantPageSize == ExportConfiguration.defaultConfiguration.publicAPI.entrantPageSize)
        #expect(refreshed.publicAPI.minimumRequestIntervalSeconds == ExportConfiguration.defaultConfiguration.publicAPI.minimumRequestIntervalSeconds)
    }

    @Test("Missing auto-fetch interval decodes to default")
    func missingAutoFetchIntervalDecodesToDefault() throws {
        let json = """
        {
          "_notes": [],
          "officialAPI": {
            "_notes": [],
            "concurrentRequests": 2,
            "entrantPageSize": 150,
            "maxRetries": 8,
            "minimumRequestIntervalSeconds": 0.76,
            "rateLimitInitialPauseSeconds": 45,
            "rateLimitMaxPauseSeconds": 180,
            "rateLimitPauseIncrementSeconds": 30,
            "serverErrorInitialPauseSeconds": 1.5,
            "serverErrorMaxPauseSeconds": 30,
            "setPageSize": 45,
            "standingPageSize": 45
          },
          "publicAPI": {
            "_notes": [],
            "concurrentRequests": 1,
            "entrantPageSize": 200,
            "maxRetries": 6,
            "minimumRequestIntervalSeconds": 0.76,
            "rateLimitInitialPauseSeconds": 60,
            "rateLimitMaxPauseSeconds": 240,
            "rateLimitPauseIncrementSeconds": 45,
            "serverErrorInitialPauseSeconds": 2,
            "serverErrorMaxPauseSeconds": 45,
            "setPageSize": 75,
            "standingPageSize": 100
          }
        }
        """

        let config = try JSONDecoder().decode(ExportConfiguration.self, from: Data(json.utf8))

        #expect(config.autoFetchIntervalMinutes == ExportConfiguration.defaultAutoFetchIntervalMinutes)
    }

    @Test("Auto-fetch interval is clamped for runtime use")
    func autoFetchIntervalIsClampedForRuntimeUse() {
        var config = ExportConfiguration.defaultConfiguration

        config.autoFetchIntervalMinutes = 0
        #expect(config.refreshingNotes().autoFetchIntervalMinutes == 1)

        config.autoFetchIntervalMinutes = 120
        #expect(config.refreshingNotes().autoFetchIntervalMinutes == 60)
    }
}
