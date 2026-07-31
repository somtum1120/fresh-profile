import Foundation
import XCTest
@testable import FreshProfile

final class ProfileStoreTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    func testCreatesAndRemovesMarkedProfile() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let profileURL = try store.createProfile(id: UUID())

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: profileURL.appendingPathComponent(".freshprofile").path
            )
        )

        try store.removeProfile(at: profileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profileURL.path))
    }

    func testStoresSessionMetadata() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let metadata = SessionMetadata(
            name: "Research",
            color: .mint,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let profileURL = try store.createProfile(
            id: UUID(),
            metadata: metadata
        )

        XCTAssertEqual(store.metadata(for: profileURL), metadata)
    }

    func testRefusesToRemoveUnmarkedDirectory() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let unmarkedURL = temporaryRoot.appendingPathComponent("not-ours")
        try FileManager.default.createDirectory(
            at: unmarkedURL,
            withIntermediateDirectories: false
        )

        XCTAssertThrowsError(try store.removeProfile(at: unmarkedURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unmarkedURL.path))
    }

    func testListsOnlyMarkedProfiles() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let profileURL = try store.createProfile(id: UUID())
        let unmarkedURL = temporaryRoot.appendingPathComponent("not-ours")
        try FileManager.default.createDirectory(
            at: unmarkedURL,
            withIntermediateDirectories: false
        )

        XCTAssertEqual(try store.leftoverProfiles(), [profileURL])
    }

    func testCurrentProcessProfileIsNotRemovableLeftover() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let profileURL = try store.createProfile(id: UUID())
        try store.recordProcessID(
            ProcessInfo.processInfo.processIdentifier,
            for: profileURL
        )

        XCTAssertTrue(store.isProfileInUse(profileURL))
        XCTAssertEqual(try store.removableLeftoverProfiles(), [])
    }

    func testListsPersistentProfilesSeparatelyFromDisposableLeftovers() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let persistentID = UUID()
        let persistentMetadata = SessionMetadata(
            name: "Saved",
            color: .mint,
            createdAt: Date(timeIntervalSince1970: 1_000),
            isPersistent: true
        )
        let persistentURL = try store.createProfile(
            id: persistentID,
            metadata: persistentMetadata
        )
        let disposableURL = try store.createProfile(
            id: UUID(),
            metadata: SessionMetadata(
                name: "Temporary",
                color: .sky,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
        )

        XCTAssertEqual(
            try store.persistentProfiles(),
            [
                StoredProfile(
                    id: persistentID,
                    profileURL: persistentURL,
                    metadata: persistentMetadata
                )
            ]
        )
        XCTAssertEqual(
            try store.removableLeftoverProfiles(),
            [disposableURL]
        )
    }

    func testClearsRecordedProcessID() throws {
        let store = try ProfileStore(rootURL: temporaryRoot)
        let profileURL = try store.createProfile(id: UUID())
        try store.recordProcessID(
            ProcessInfo.processInfo.processIdentifier,
            for: profileURL
        )

        XCTAssertNotNil(store.processID(for: profileURL))
        try store.clearProcessID(for: profileURL)
        XCTAssertNil(store.processID(for: profileURL))
        XCTAssertFalse(store.isProfileInUse(profileURL))
    }

    func testLegacyMetadataDefaultsToDisposable() throws {
        let json = """
        {
          "name": "Legacy",
          "color": "sky",
          "createdAt": "1970-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(
            SessionMetadata.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(metadata.isPersistent)
    }
}
