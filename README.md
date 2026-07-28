# FreshProfile

FreshProfile is a small, open-source macOS app that launches isolated,
disposable browser windows. Every window receives its own user-data directory,
so cookies, local storage, IndexedDB, service workers, and caches are not shared
with other FreshProfile windows or with your regular browser profile.

The initial release supports Google Chrome on macOS.

> [!IMPORTANT]
> FreshProfile is not affiliated with or endorsed by Google. It does not make
> browsing anonymous. Websites, network operators, and signed-in services may
> still identify or observe you.

## How it works

1. FreshProfile creates a unique directory in its macOS cache directory.
2. It launches the browser executable with that directory passed as
   `--user-data-dir`, along with `--incognito`.
3. When that browser process exits, FreshProfile removes the directory.
4. If the app or Mac stops unexpectedly, FreshProfile offers to remove leftover
   directories the next time it opens.

FreshProfile never reads, copies, or modifies your regular Chrome profile.

## Requirements

- macOS 13 Ventura or newer
- Google Chrome installed in `/Applications` or `~/Applications`
- Xcode 15 or newer for development

## Download

Download the signed and Apple-notarized Universal ZIP from the
[latest GitHub Release](https://github.com/somtum1120/fresh-profile/releases/latest).
It supports both Apple Silicon and Intel Macs. Unzip it and move
`FreshProfile.app` to `Applications`.

## Development

Open `Package.swift` in Xcode, or use the command line:

```sh
swift run
swift test
```

Build a local `.app` bundle:

```sh
./Scripts/build-app.sh
open dist/FreshProfile.app
```

Signed and notarized releases are produced on a trusted Mac using the process
documented in [docs/releasing.md](docs/releasing.md).

## Current limitations

- Browser processes can outlive FreshProfile if the launcher is force-quit.
  Leftover data is retained until the user explicitly removes it on next launch.
- The first Chrome window may briefly show browser onboarding UI depending on
  the installed Chrome version and managed-device policies.
- Automatic updates are not yet implemented.

## Security

Please report security issues privately using GitHub's security advisory feature
instead of opening a public issue.

## License

[MIT](LICENSE)
