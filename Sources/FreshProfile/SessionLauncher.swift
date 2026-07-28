import Foundation

struct LaunchedSession {
    let id: UUID
    let process: Process
    let profileURL: URL
    let metadata: SessionMetadata
}

struct SessionLauncher {
    let profileStore: ProfileStore

    init(profileStore: ProfileStore? = nil) throws {
        self.profileStore = try profileStore ?? ProfileStore()
    }

    func launch(
        browser: Browser,
        name: String,
        color: SessionColor,
        onTermination: @escaping (UUID) -> Void
    ) throws -> LaunchedSession {
        let id = UUID()
        let metadata = SessionMetadata(
            name: name,
            color: color,
            createdAt: Date()
        )
        let profileURL = try profileStore.createProfile(
            id: id,
            metadata: metadata
        )
        let landingPageURL = try SessionLandingPage.write(
            metadata: metadata,
            to: profileURL
        )
        let process = Process()

        process.executableURL = browser.executableURL
        process.arguments = Self.arguments(
            profileURL: profileURL,
            landingPageURL: landingPageURL
        )

        process.terminationHandler = { _ in
            Self.removeProfileWithRetries(
                profileURL,
                profileStore: profileStore
            )
            onTermination(id)
        }

        do {
            try process.run()
            try profileStore.recordProcessID(
                process.processIdentifier,
                for: profileURL
            )
        } catch {
            if process.isRunning {
                process.terminate()
            }
            try? profileStore.removeProfile(at: profileURL)
            throw error
        }

        return LaunchedSession(
            id: id,
            process: process,
            profileURL: profileURL,
            metadata: metadata
        )
    }

    static func arguments(
        profileURL: URL,
        landingPageURL: URL
    ) -> [String] {
        [
            "--user-data-dir=\(profileURL.path)",
            "--incognito",
            "--new-window",
            "--no-first-run",
            "--no-default-browser-check",
            landingPageURL.absoluteString
        ]
    }

    private static func removeProfileWithRetries(
        _ profileURL: URL,
        profileStore: ProfileStore,
        remainingAttempts: Int = 5
    ) {
        do {
            try profileStore.removeProfile(at: profileURL)
        } catch where remainingAttempts > 1 {
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + 1
            ) {
                removeProfileWithRetries(
                    profileURL,
                    profileStore: profileStore,
                    remainingAttempts: remainingAttempts - 1
                )
            }
        } catch {
            // The next app launch exposes leftovers for explicit user cleanup.
        }
    }
}
