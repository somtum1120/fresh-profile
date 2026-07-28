import Foundation
import Darwin

struct ProfileStore {
    let rootURL: URL
    var fileManager: FileManager = .default

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager

        if let rootURL {
            self.rootURL = rootURL
        } else {
            let cacheURL = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootURL = cacheURL
                .appendingPathComponent("app.freshprofile.FreshProfile")
                .appendingPathComponent("Sessions")
        }

        try fileManager.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
    }

    func createProfile(id: UUID) throws -> URL {
        let profileURL = rootURL.appendingPathComponent(
            id.uuidString,
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: profileURL,
            withIntermediateDirectories: false
        )

        let markerURL = profileURL.appendingPathComponent(".freshprofile")
        try Data().write(to: markerURL, options: .atomic)
        return profileURL
    }

    func recordProcessID(_ processID: Int32, for profileURL: URL) throws {
        guard isOwnedProfile(profileURL) else {
            throw ProfileStoreError.unsafeRemovalTarget
        }

        let processURL = profileURL.appendingPathComponent(".process-id")
        try Data(String(processID).utf8).write(to: processURL, options: .atomic)
    }

    func isProfileInUse(_ profileURL: URL) -> Bool {
        guard isOwnedProfile(profileURL) else {
            return false
        }

        let processURL = profileURL.appendingPathComponent(".process-id")
        guard let data = try? Data(contentsOf: processURL),
              let text = String(data: data, encoding: .utf8),
              let processID = Int32(text) else {
            return false
        }

        return kill(processID, 0) == 0 || errno == EPERM
    }

    func removeProfile(at profileURL: URL) throws {
        let canonicalRoot = rootURL.resolvingSymlinksInPath()
        let canonicalProfile = profileURL.resolvingSymlinksInPath()
        let expectedParent = canonicalProfile.deletingLastPathComponent()

        guard expectedParent == canonicalRoot,
              canonicalProfile != canonicalRoot,
              isOwnedProfile(canonicalProfile) else {
            throw ProfileStoreError.unsafeRemovalTarget
        }

        try fileManager.removeItem(at: canonicalProfile)
    }

    func leftoverProfiles() throws -> [URL] {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return []
        }

        return try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .map {
            rootURL.appendingPathComponent(
                $0.lastPathComponent,
                isDirectory: true
            )
        }
        .filter {
            fileManager.fileExists(
                atPath: $0.appendingPathComponent(".freshprofile").path
            )
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func removableLeftoverProfiles() throws -> [URL] {
        try leftoverProfiles().filter { !isProfileInUse($0) }
    }

    private func isOwnedProfile(_ profileURL: URL) -> Bool {
        let canonicalRoot = rootURL.resolvingSymlinksInPath()
        let canonicalProfile = profileURL.resolvingSymlinksInPath()

        return canonicalProfile.deletingLastPathComponent() == canonicalRoot
            && canonicalProfile != canonicalRoot
            && fileManager.fileExists(
                atPath: canonicalProfile
                    .appendingPathComponent(".freshprofile")
                    .path
            )
    }
}

enum ProfileStoreError: LocalizedError {
    case unsafeRemovalTarget

    var errorDescription: String? {
        switch self {
        case .unsafeRemovalTarget:
            return "FreshProfile refused to remove a directory it did not create."
        }
    }
}
