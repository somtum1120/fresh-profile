import Foundation
import Darwin

struct StoredProfile: Equatable {
    let id: UUID
    let profileURL: URL
    let metadata: SessionMetadata
}

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
                .appendingPathComponent("app.somtum.FreshProfile")
                .appendingPathComponent("Sessions")
        }

        try fileManager.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
    }

    func createProfile(
        id: UUID,
        metadata: SessionMetadata? = nil
    ) throws -> URL {
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

        if let metadata {
            let metadataURL = profileURL.appendingPathComponent(".session.json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(metadata).write(to: metadataURL, options: .atomic)
        }

        return profileURL
    }

    func metadata(for profileURL: URL) -> SessionMetadata? {
        guard isOwnedProfile(profileURL) else { return nil }
        let metadataURL = profileURL.appendingPathComponent(".session.json")
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionMetadata.self, from: data)
    }

    func recordProcessID(_ processID: Int32, for profileURL: URL) throws {
        guard isOwnedProfile(profileURL) else {
            throw ProfileStoreError.unsafeRemovalTarget
        }

        let processURL = profileURL.appendingPathComponent(".process-id")
        try Data(String(processID).utf8).write(to: processURL, options: .atomic)
    }

    func processID(for profileURL: URL) -> Int32? {
        guard isOwnedProfile(profileURL) else {
            return nil
        }

        let processURL = profileURL.appendingPathComponent(".process-id")
        guard let data = try? Data(contentsOf: processURL),
              let text = String(data: data, encoding: .utf8),
              let processID = Int32(text) else {
            return nil
        }
        return processID
    }

    func clearProcessID(for profileURL: URL) throws {
        guard isOwnedProfile(profileURL) else {
            throw ProfileStoreError.unsafeRemovalTarget
        }

        let processURL = profileURL.appendingPathComponent(".process-id")
        if fileManager.fileExists(atPath: processURL.path) {
            try fileManager.removeItem(at: processURL)
        }
    }

    func isProfileInUse(_ profileURL: URL) -> Bool {
        guard let processID = processID(for: profileURL) else {
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

    func persistentProfiles() throws -> [StoredProfile] {
        try leftoverProfiles()
            .compactMap { profileURL in
                guard let metadata = metadata(for: profileURL),
                      metadata.isPersistent,
                      let id = UUID(uuidString: profileURL.lastPathComponent) else {
                    return nil
                }
                return StoredProfile(id: id, profileURL: profileURL, metadata: metadata)
            }
            .sorted { $0.metadata.createdAt < $1.metadata.createdAt }
    }

    func removableLeftoverProfiles() throws -> [URL] {
        try leftoverProfiles().filter { profileURL in
            guard metadata(for: profileURL)?.isPersistent != true else {
                return false
            }
            return !isProfileInUse(profileURL)
        }
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
