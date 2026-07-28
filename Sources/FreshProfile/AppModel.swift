import Combine
import Foundation

struct SessionSummary: Identifiable {
    let id: UUID
    let browserName: String
    let startedAt: Date
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var browsers: [Browser] = []
    @Published var selectedBrowserID: String?
    @Published private(set) var sessions: [SessionSummary] = []
    @Published private(set) var leftoverCount = 0
    @Published var errorMessage: String?

    private var processes: [UUID: Process] = [:]
    private let browserLocator: BrowserLocator
    private let launcher: SessionLauncher

    init(
        browserLocator: BrowserLocator = BrowserLocator(),
        launcher: SessionLauncher? = nil
    ) {
        self.browserLocator = browserLocator

        do {
            self.launcher = try launcher ?? SessionLauncher()
        } catch {
            fatalError("Could not initialize the private profile store: \(error)")
        }

        refresh()
    }

    var selectedBrowser: Browser? {
        browsers.first { $0.id == selectedBrowserID }
    }

    func refresh() {
        browsers = browserLocator.installedBrowsers()

        if selectedBrowser == nil {
            selectedBrowserID = browsers.first?.id
        }

        refreshLeftoverCount()
    }

    func openIsolatedWindow() {
        guard let browser = selectedBrowser else {
            errorMessage = "Google Chrome was not found."
            return
        }

        do {
            let launched = try launcher.launch(browser: browser) {
                [weak self] id in
                DispatchQueue.main.async {
                    self?.sessionDidTerminate(id: id)
                }
            }

            processes[launched.id] = launched.process
            sessions.append(
                SessionSummary(
                    id: launched.id,
                    browserName: browser.name,
                    startedAt: Date()
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeSession(id: UUID) {
        processes[id]?.terminate()
    }

    func removeLeftovers() {
        do {
            for profileURL in try launcher.profileStore
                .removableLeftoverProfiles() {
                try launcher.profileStore.removeProfile(at: profileURL)
            }
            refreshLeftoverCount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sessionDidTerminate(id: UUID) {
        processes[id] = nil
        sessions.removeAll { $0.id == id }
        refreshLeftoverCount()
    }

    private func refreshLeftoverCount() {
        do {
            leftoverCount = try launcher.profileStore
                .removableLeftoverProfiles()
                .count
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
