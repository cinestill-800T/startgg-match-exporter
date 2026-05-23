# StartGG Match Exporter

[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![start.gg API](https://img.shields.io/badge/start.gg-GraphQL%20API-ff6694.svg)](https://developer.start.gg/docs/intro/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

StartGG Match Exporter is a small macOS SwiftUI app that exports a start.gg event into JSON for downstream analysis.

It does not infer player nationality, predict matches, or call external services beyond start.gg. It focuses on collecting comprehensive structured data:

- event metadata
- phases and progression metadata
- entrants
- standings
- all currently available sets, including completed and pending sets
- set slots, scores, winner IDs, phase group IDs, and display scores

## Requirements

- macOS 13 or later
- Xcode 26.5 or compatible Swift 6 toolchain
- optional start.gg API token

Create a token in start.gg Developer Settings and paste it into the app to enable authenticated official API access. The token is stored in the macOS Keychain.

## Usage

1. Open `release/StartGGMatchExporter.app`.
2. Paste a start.gg event URL, for example `https://www.start.gg/tournament/.../event/street-fighter-6`.
3. Paste your start.gg API token for authenticated official API access, or leave it blank for Public Safe Mode.
4. Click `Fetch Data`.
5. Click `Save JSON`.

The exporter accepts normal event URLs and bracket URLs. It normalizes them to a start.gg event slug internally.

## Connection Modes

The app chooses the mode automatically:

- `Authenticated Safe Mode`: enabled when an API token is present. Uses the official API, small page sizes, sequential reads, request throttling, and longer retry waits for rate limits.
- `Public Safe Mode`: enabled when the token field is blank. Uses public web data with conservative pacing. This is convenient for quick checks, but the official API is preferred for sustained exports.

## Watchlist Export

After fetching an event, paste player names into the Watchlist field. The app matches those names against entrant names, gamer tags, and common prefix forms, then exports only the related sets.

Watchlist outputs:

- focused JSON for structured processing
- Markdown report for quick reading

Matching is mechanical and transparent. The app does not infer nationality, team affiliation, or tournament outcomes beyond the set data returned by start.gg.

## Local Cache

The app caches exports in Application Support and reuses them for the same event URL and connection mode. Fetching with cache enabled uses the cache as a base, skips phases whose cached sets are all completed, and updates the remaining phases. During long exports, the app also saves partial cache snapshots after each phase. If you cancel an export, the next normal `Fetch Data` run can continue from the finished cached phases.

Use `Refresh` to ignore the cache and fetch fresh data from start.gg.

## Configuration

The first fetch creates a local configuration file:

```text
~/Library/Application Support/StartGGMatchExporter/config.json
```

The `Config` button reveals this file in Finder. It includes explanatory `_notes` fields and can tune:

- set, entrant, and standing page sizes
- minimum request interval
- concurrent page requests
- retry count
- HTTP 429 and 5xx retry waits

For authenticated mode, the default request interval is `1.2` seconds, roughly 50 requests per minute. If exports are stable, you can gradually move toward `0.8`. If HTTP 429 appears, increase the interval or return `concurrentRequests` to `1`.

The generated `_notes` text is written in Japanese. If an older English config file already exists, the app refreshes only the explanatory `_notes` while preserving your numeric tuning values.

The app also remembers the last event URL you entered and restores it on the next launch. Save dialogs default to the macOS Downloads folder.

## JSON Shape

The output root contains:

- `schemaVersion`
- `fetchedAt`
- `source`
- `summary`
- `event`
- `entrants`
- `standings`
- `phases`

Each phase contains its set list and a phase group summary derived from the set data.

## Development

Run tests:

```bash
swift test
```

Build app bundles:

```bash
Scripts/build_app.sh all
```

The script places built artifacts directly under:

- `debug/`
- `release/`

## API Notes

This app uses the official start.gg GraphQL API endpoint:

```text
https://api.start.gg/gql/alpha
```

start.gg documents an average rate limit of 80 requests per 60 seconds and a 1000 object maximum per request. The app throttles requests, uses conservative page sizes, and writes local cache snapshots so repeated tournament updates avoid re-fetching completed phases.

## License

MIT
