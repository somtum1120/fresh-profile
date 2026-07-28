# Project guidance

## Scope

FreshProfile is a native SwiftUI macOS launcher for disposable, isolated browser
profiles. Keep the app local-first: no analytics, accounts, network services, or
access to the user's regular browser profile.

Important directories:

- `Sources/FreshProfile`: application code
- `Tests/FreshProfileTests`: unit tests
- `Scripts`: local packaging helpers
- `dist`: ignored build output

## Commands

- Setup: open `Package.swift` in Xcode 15 or newer
- Run: `swift run`
- Test: `swift test`
- Lint: compiler warnings via `swift build`
- Build: `./Scripts/build-app.sh`

## Conventions

- Support macOS 13 and newer.
- Keep browser discovery and profile-directory logic testable without launching
  an external process.
- Never inspect, copy, modify, or delete a user's regular browser profile.
- Only delete directories created beneath FreshProfile's own cache root.
- Treat external browser names and trademarks as compatibility descriptions,
  not project branding.
- Preserve unrelated changes and keep machine-local state out of Git.
