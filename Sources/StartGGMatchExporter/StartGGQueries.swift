import Foundation

enum StartGGQueries {
    static func eventSummary(for mode: StartGGAPIMode) -> String {
        switch mode {
        case .authenticatedFast:
            authenticatedEventSummary
        case .publicSafe:
            publicEventSummary
        }
    }

    static let authenticatedEventSummary = """
    query EventSummary($slug: String!) {
      event(slug: $slug) {
        id
        name
        slug
        numEntrants
        type
        videogame {
          id
          name
        }
        tournament {
          id
          name
          slug
          timezone
        }
        phases {
          id
          name
          state
          groupCount
          bracketType
          numSeeds
        }
      }
    }
    """

    static let publicEventSummary = """
    query EventSummary($slug: String!) {
      event(slug: $slug) {
        id
        name
        slug
        numEntrants
        type
        videogame {
          id
          name
        }
        tournament {
          id
          name
          slug
          timezone
        }
        phases {
          id
          name
          state
          groupCount
          bracketType
          numSeeds
          percentComplete
          destPhases {
            id
            name
            progressionData {
              origin
              numProgressing
            }
          }
        }
      }
    }
    """

    static let eventEntrants = """
    query EventEntrants($eventId: ID!, $page: Int!, $perPage: Int!) {
      event(id: $eventId) {
        id
        entrants(query: { page: $page, perPage: $perPage }) {
          pageInfo {
            total
            totalPages
            page
            perPage
          }
          nodes {
            id
            name
            initialSeedNum
            participants {
              id
              gamerTag
              prefix
              player {
                id
                gamerTag
                prefix
              }
            }
          }
        }
      }
    }
    """

    static let eventStandings = """
    query EventStandings($eventId: ID!, $page: Int!, $perPage: Int!) {
      event(id: $eventId) {
        id
        standings(query: { page: $page, perPage: $perPage }) {
          pageInfo {
            total
            totalPages
            page
            perPage
          }
          nodes {
            id
            placement
            entrant {
              id
              name
              initialSeedNum
              participants {
                id
                gamerTag
                prefix
                player {
                  id
                  gamerTag
                  prefix
                }
              }
            }
          }
        }
      }
    }
    """

    static let phaseSets = """
    query PhaseSets($phaseId: ID!, $page: Int!, $perPage: Int!) {
      phase(id: $phaseId) {
        id
        name
        sets(page: $page, perPage: $perPage, sortType: STANDARD) {
          pageInfo {
            total
            totalPages
            page
            perPage
          }
          nodes {
            id
            identifier
            state
            round
            fullRoundText
            displayScore
            winnerId
            completedAt
            startedAt
            updatedAt
            phaseGroup {
              id
              displayIdentifier
            }
            slots {
              id
              entrant {
                id
                name
                initialSeedNum
                participants {
                  id
                  gamerTag
                  prefix
                  player {
                    id
                    gamerTag
                    prefix
                  }
                }
              }
              standing {
                placement
                stats {
                  score {
                    value
                  }
                }
              }
            }
          }
        }
      }
    }
    """
}
