# Releasing FreshProfile from the Mac homespace

The personal GitHub repository `somtum1120/fresh-profile` is the integrated
source of truth. Releases are built directly from the trusted Mac homespace
checkout and distributed outside the Mac App Store with Developer ID signing
and Apple notarization. VM101 is not a routine source or release endpoint.

The release process:

1. Generates the Xcode project from `project.yml`.
2. Archives a universal Apple Silicon and Intel application.
3. Signs from a PEM private key with `rcodesign`, a Developer ID certificate,
   Apple secure timestamps, and Hardened Runtime.
4. Submits the app to Apple's notary service using a Team API key.
5. Staples the notarization ticket and validates the app with `spctl`.
6. Creates a ZIP and SHA-256 checksum for GitHub Releases.

## Local configuration

Install the pinned `rcodesign` release on the trusted Mac. The installer
downloads the official Universal archive and verifies its SHA-256 checksum:

```sh
./Scripts/install-rcodesign.sh
```

On the Mac, provide a mode-0600 property list through
`FRESH_PROFILE_ASC_CONFIG`, or use the existing default at:

```text
~/Library/Application Support/PeCaViewer/AppStoreConnect.plist
```

It must contain `keyID`, `issuerID`, `keyPath`, and `teamID`. The referenced
private key must be an App Store Connect Team API key. Never commit either file.

The matching Developer ID Application certificate must be installed in the
Mac user's keychain. Its PEM private key is read from this default path:

```text
~/Library/Application Support/FreshProfile/DeveloperID-FreshProfile.key
```

The certificate, private key, and API key must never be committed.

## Build

```sh
./Scripts/mac-release.sh
```

Run the command from the Mac homespace checkout at a pushed commit SHA. The
signed, notarized ZIP and checksum paths are printed by the script. Publishing
the GitHub Release is a separate explicit step, and the source SHA should be
recorded in the release notes.

## Recovery

Re-clone the pushed GitHub revision into the Mac homespace, restore only the
documented machine-local signing configuration, and run `mac-release.sh` from a
clean `main` whose full HEAD matches live `origin/main`. Do not recreate source
sync, a remote dispatcher, or a LaunchAgent trigger.
