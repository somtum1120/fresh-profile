import Foundation

struct Browser: Identifiable, Hashable {
    let id: String
    let name: String
    let executableURL: URL

    static let chromeCandidates: [(name: String, bundlePath: String)] = [
        (
            "Google Chrome",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        ),
        (
            "Google Chrome",
            "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        )
    ]
}

struct BrowserLocator {
    var fileManager: FileManager = .default
    var homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser

    func installedBrowsers() -> [Browser] {
        Browser.chromeCandidates.compactMap { candidate in
            let executableURL: URL

            if candidate.bundlePath.hasPrefix("/") {
                executableURL = URL(fileURLWithPath: candidate.bundlePath)
            } else {
                executableURL = homeDirectory.appendingPathComponent(
                    candidate.bundlePath,
                    isDirectory: false
                )
            }

            guard fileManager.isExecutableFile(atPath: executableURL.path) else {
                return nil
            }

            return Browser(
                id: executableURL.path,
                name: candidate.name,
                executableURL: executableURL
            )
        }
    }
}
