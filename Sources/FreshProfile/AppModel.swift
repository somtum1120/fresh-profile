import AppKit
import Combine
import Darwin
import Foundation

struct SessionSummary: Identifiable, Equatable {
    let id: UUID
    let browserName: String
    let name: String
    let color: SessionColor
    let startedAt: Date
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var browsers: [Browser] = []
    @Published var selectedBrowserID: String?
    @Published private(set) var sessions: [SessionSummary] = []
    @Published var selectedSessionID: UUID?
    @Published var draftSessionName = ""
    @Published var selectedColor: SessionColor = .sky
    @Published private(set) var closingSessionIDs: Set<UUID> = []
    @Published private(set) var leftoverCount = 0
    @Published var errorMessage: String?

    private var processes: [UUID: Process] = [:]
    private var nextSessionNumber = 1
    private var nextColorIndex = 0
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

    var selectedSession: SessionSummary? {
        sessions.first { $0.id == selectedSessionID }
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

        let sessionName = SessionName.normalized(
            draftSessionName,
            fallbackNumber: nextSessionNumber
        )

        do {
            let launched = try launcher.launch(
                browser: browser,
                name: sessionName,
                color: selectedColor
            ) { [weak self] id in
                DispatchQueue.main.async {
                    self?.sessionDidTerminate(id: id)
                }
            }

            processes[launched.id] = launched.process
            sessions.append(
                SessionSummary(
                    id: launched.id,
                    browserName: browser.name,
                    name: launched.metadata.name,
                    color: launched.metadata.color,
                    startedAt: launched.metadata.createdAt
                )
            )
            selectedSessionID = launched.id
            draftSessionName = ""
            nextSessionNumber += 1
            selectNextColor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showSelectedSession() {
        guard let selectedSessionID else { return }
        showSession(id: selectedSessionID)
    }

    func showSession(id: UUID) {
        guard let process = processes[id], process.isRunning else {
            errorMessage = "That private window is no longer running."
            return
        }

        guard let application = NSRunningApplication(
            processIdentifier: process.processIdentifier
        ) else {
            errorMessage = "FreshProfile could not locate that window."
            return
        }

        if !application.activate(options: [.activateAllWindows]) {
            errorMessage = "FreshProfile could not bring that window forward."
        }
    }

    func closeSelectedSession() {
        guard let selectedSessionID else { return }
        closeSession(id: selectedSessionID)
    }

    func closeSession(id: UUID) {
        guard let process = processes[id], process.isRunning else { return }
        closingSessionIDs.insert(id)
        process.terminate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self,
                  self.closingSessionIDs.contains(id),
                  let process = self.processes[id],
                  process.isRunning else {
                return
            }
            kill(process.processIdentifier, SIGKILL)
        }
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

    private func selectNextColor() {
        let colors = SessionColor.allCases
        nextColorIndex = (nextColorIndex + 1) % colors.count
        selectedColor = colors[nextColorIndex]
    }

    private func sessionDidTerminate(id: UUID) {
        processes[id] = nil
        closingSessionIDs.remove(id)
        sessions.removeAll { $0.id == id }

        if selectedSessionID == id {
            selectedSessionID = sessions.first?.id
        }

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
