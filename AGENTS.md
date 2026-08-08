# Project guidance

## Scope

FreshProfile is a native SwiftUI macOS launcher for disposable, isolated browser
profiles. Keep the app local-first: no analytics, accounts, network services, or
access to the user's regular browser profile.

## Product decisions

- FreshProfile exists because multiple ordinary Chrome Incognito windows share
  browser session storage. It isolates each window by launching Chrome with a
  separate disposable `--user-data-dir`; it is a launcher, not a browser
  extension.
- Keep the primary workflow immediate: give a session a name and color, launch
  it, click an active session to bring its browser window to the front, and
  remove only that disposable profile after its browser process exits.
- The app is an open-source macOS utility distributed from the
  `somtum1120/fresh-profile` GitHub repository under the MIT license. Release
  artifacts must remain polished for nontechnical users: a real app icon,
  Universal Apple Silicon/Intel build, Developer ID signature, Apple
  notarization, and Sparkle updates.
- Release credentials and private keys must never enter Git. Keep recoverable
  backup copies in the user's designated Bitwarden vault, with operational
  copies limited to the macOS Keychain or documented mode-0600 files. Verify
  the backup exists instead of assuming it does.
- Screenshot tooling and the macshot/CleanShot discussion are a separate
  product direction. Do not add those features to FreshProfile.

Important directories:

- `Sources/FreshProfile`: application code
- `Tests/FreshProfileTests`: unit tests
- `Scripts`: local packaging helpers
- `dist`: ignored build output
- `project.yml`: XcodeGen project used for signed distribution builds

## Commands

- Setup: open `Package.swift` in Xcode 15 or newer
- Release tool setup on macOS: `./Scripts/install-rcodesign.sh`
- Run: `swift run`
- Test: `swift test`
- Lint: compiler warnings via `swift build`
- Build: `./Scripts/build-app.sh`
- Signed release: `./Scripts/remote-release.sh`

## Conventions

- Support macOS 13 and newer.
- Keep browser discovery and profile-directory logic testable without launching
  an external process.
- Never inspect, copy, modify, or delete a user's regular browser profile.
- Only delete directories created beneath FreshProfile's own cache root.
- Treat external browser names and trademarks as compatibility descriptions,
  not project branding.
- Preserve unrelated changes and keep machine-local state out of Git.
