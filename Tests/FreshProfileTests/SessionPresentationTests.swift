import Foundation
import XCTest
@testable import FreshProfile

final class SessionPresentationTests: XCTestCase {
    func testNormalizesSessionName() {
        XCTAssertEqual(
            SessionName.normalized("  Client   research  ", fallbackNumber: 1),
            "Client research"
        )
        XCTAssertEqual(
            SessionName.normalized("   ", fallbackNumber: 7),
            "Private 7"
        )
        XCTAssertEqual(
            SessionName.normalized(
                String(repeating: "a", count: 80),
                fallbackNumber: 1
            ).count,
            SessionName.maximumLength
        )
    }

    func testLandingPageEscapesNameAndUsesColor() {
        let metadata = SessionMetadata(
            name: "<Work & \"Mail\">",
            color: .rose,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let html = SessionLandingPage.html(metadata: metadata)

        XCTAssertTrue(html.contains("&lt;Work &amp; &quot;Mail&quot;&gt;"))
        XCTAssertFalse(html.contains("<Work &"))
        XCTAssertTrue(html.contains(SessionColor.rose.hex))
    }

    func testChromeArgumentsUseIsolatedIncognitoProfileAndLandingPage() {
        let profileURL = URL(fileURLWithPath: "/tmp/Fresh Profile")
        let landingURL = profileURL.appendingPathComponent("Start.html")
        let arguments = SessionLauncher.arguments(
            profileURL: profileURL,
            landingPageURL: landingURL
        )

        XCTAssertTrue(
            arguments.contains("--user-data-dir=\(profileURL.path)")
        )
        XCTAssertTrue(arguments.contains("--incognito"))
        XCTAssertTrue(arguments.contains("--new-window"))
        XCTAssertEqual(arguments.last, landingURL.absoluteString)
    }
}
