import Foundation
import XCTest
@testable import FreshProfile

final class BrowserLocatorTests: XCTestCase {
    func testMissingUserBrowserIsNotReturned() {
        let impossibleHome = URL(
            fileURLWithPath: "/freshprofile-tests-does-not-exist"
        )
        let locator = BrowserLocator(homeDirectory: impossibleHome)

        // The system-wide candidate may exist on a developer Mac, so verify only
        // that the fake per-user candidate is not returned.
        XCTAssertFalse(
            locator.installedBrowsers().contains {
                $0.executableURL.path.hasPrefix(impossibleHome.path)
            }
        )
    }
}
