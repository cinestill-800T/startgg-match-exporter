# StartGG Match Exporter

[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![start.gg API](https://img.shields.io/badge/start.gg-GraphQL%20API-ff6694.svg)](https://developer.start.gg/docs/intro/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

StartGG Match Exporter is a small macOS SwiftUI app that exports a start.gg event into JSON for downstream analysis.

It does not infer player nationality, predict matches, or call any AI service. It focuses on collecting comprehensive structured data:

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

Create a token in start.gg Developer Settings and paste it into the app to enable Fast Mode. The token is stored in the macOS Keychain.

## Usage

1. Open `release/StartGGMatchExporter.app`.
2. Paste a start.gg event URL, for example `https://www.start.gg/tournament/.../event/street-fighter-6`.
3. Paste your start.gg API token for Fast Mode, or leave it blank for Public Safe Mode.
4. Click `Fetch Data`.
5. Click `Save JSON`.

The exporter accepts normal event URLs and bracket URLs. It normalizes them to a start.gg event slug internally.

## Connection Modes

The app chooses the mode automatically:

- `Fast Mode`: enabled when an API token is present. Uses the official API, larger pages, parallel page reads, request throttling, and retry handling.
- `Public Safe Mode`: enabled when the token field is blank. Uses public web data with conservative pacing. This is convenient for quick checks, but the official API is preferred for sustained exports.

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

start.gg documents an average rate limit of 80 requests per 60 seconds and a 1000 object maximum per request. The app throttles requests and uses conservative page sizes.

## License

MIT
