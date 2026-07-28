# Releasing FreshProfile

FreshProfile releases are built on a trusted Mac and distributed outside the
Mac App Store with Developer ID signing and Apple notarization.

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

Copy `Scripts/remote-release.env.example` to
`.local/remote-release.env`. This ignored file identifies the trusted Mac,
SSH key, destination directory, and XcodeGen executable.

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
./Scripts/remote-release.sh
```

The signed, notarized ZIP and checksum are copied to the ignored `dist`
directory. Publishing the GitHub Release is a separate explicit step.
