import AppKit
import Combine
import Darwin
import Foundation

struct SessionSummary: Identifiable, Equatable {
    let id: UUID
    let browserName: String
    let name: String
    let color: SessionColor
    let createdAt: Date
    let isPersistent: Bool
    var isRunning: Bool
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var browsers: [Browser] = []
    @Published var selectedBrowserID: String?
    @Published private(set) var sessions: [SessionSummary] = []
    @Published var selectedSessionID: UUID?
    @Published var draftSessionName = ""
    @Published var selectedColor: SessionColor = .sky
    @Published var keepProfileAfterClosing = true
    @Published private(set) var closingSessionIDs: Set<UUID> = []
    @Published private(set) var leftoverCount = 0
    @Published var errorMessage: String?

    private var processes: [UUID: Process] = [:]
    private var dockTileConnections: [UUID: DockTileConnection] = [:]
    private var storedProfiles: [UUID: StoredProfile] = [:]
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
            fatalError("Could not initialize the profile store: \(error)")
        }

        refresh()
    }

    var selectedBrowser: Browser? {
        browsers.first { $0.id == selectedBrowserID }
    }

    var selectedSession: SessionSummary? {
        sessions.first { $0.id == selectedSessionID }
    }

    var activeSessionCount: Int {
        sessions.filter(\.isRunning).count
    }

    func refresh() {
        browsers = browserLocator.installedBrowsers()

        if selectedBrowser == nil {
            selectedBrowserID = browsers.first?.id
        }

        reloadPersistentProfiles()
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
                color: selectedColor,
                isPersistent: keepProfileAfterClosing
            ) { [weak self] id in
                DispatchQueue.main.async {
                    self?.sessionDidTerminate(id: id)
                }
            }

            register(launched, browserName: browser.name)
            selectedSessionID = launched.id
            draftSessionName = ""
            nextSessionNumber += 1
            selectNextColor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openOrShowSelectedSession() {
        guard let selectedSessionID else { return }
        openOrShowSession(id: selectedSessionID)
    }

    func openOrShowSession(id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }) else {
            return
        }

        if session.isRunning {
            showSession(id: id)
        } else {
            reopenSession(id: id)
        }
    }

    func showSelectedSession() {
        guard let selectedSessionID else { return }
        showSession(id: selectedSessionID)
    }

    func showSession(id: UUID) {
        guard let processID = runningProcessID(for: id) else {
            markSessionStopped(id: id)
            errorMessage = "That profile window is no longer running."
            return
        }

        if let connection = dockTileConnections[id] {
            _ = connection.ensureWindow()
        }

        guard let application = NSRunningApplication(
            processIdentifier: processID
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
        guard let processID = runningProcessID(for: id) else {
            markSessionStopped(id: id)
            return
        }

        closingSessionIDs.insert(id)
        if let process = processes[id], process.isRunning {
            process.terminate()
        } else {
            kill(processID, SIGTERM)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self,
                  self.closingSessionIDs.contains(id),
                  let processID = self.runningProcessID(for: id) else {
                return
            }
            kill(processID, SIGKILL)
            self.markSessionStopped(id: id)
        }
    }

    func deleteSelectedProfile() {
        guard let selectedSessionID else { return }
        deleteProfile(id: selectedSessionID)
    }

    func deleteProfile(id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }),
              session.isPersistent,
              !session.isRunning,
              let storedProfile = storedProfiles[id] else {
            return
        }

        do {
            try launcher.profileStore.removeProfile(
                at: storedProfile.profileURL
            )
            storedProfiles[id] = nil
            sessions.removeAll { $0.id == id }
            if selectedSessionID == id {
                selectedSessionID = sessions.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
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

    private func reopenSession(id: UUID) {
        guard let browser = selectedBrowser ?? browsers.first else {
            errorMessage = "Google Chrome was not found."
            return
        }
        guard let storedProfile = storedProfiles[id] else {
            errorMessage = "That saved profile could not be found."
            return
        }

        do {
            let launched = try launcher.relaunch(
                browser: browser,
                storedProfile: storedProfile
            ) { [weak self] id in
                DispatchQueue.main.async {
                    self?.sessionDidTerminate(id: id)
                }
            }
            register(launched, browserName: browser.name)
            selectedSessionID = id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register(
        _ launched: LaunchedSession,
        browserName: String
    ) {
        processes[launched.id] = launched.process
        if let connection = launched.dockTileConnection {
            dockTileConnections[launched.id] = connection
        }

        if launched.metadata.isPersistent {
            storedProfiles[launched.id] = StoredProfile(
                id: launched.id,
                profileURL: launched.profileURL,
                metadata: launched.metadata
            )
        }

        let summary = SessionSummary(
            id: launched.id,
            browserName: browserName,
            name: launched.metadata.name,
            color: launched.metadata.color,
            createdAt: launched.metadata.createdAt,
            isPersistent: launched.metadata.isPersistent,
            isRunning: true
        )
        if let index = sessions.firstIndex(where: { $0.id == launched.id }) {
            sessions[index] = summary
        } else {
            sessions.append(summary)
        }
        sessions.sort { $0.createdAt < $1.createdAt }
    }

    private func reloadPersistentProfiles() {
        do {
            let profiles = try launcher.profileStore.persistentProfiles()
            storedProfiles = Dictionary(
                uniqueKeysWithValues: profiles.map { ($0.id, $0) }
            )
            let profileIDs = Set(profiles.map(\.id))
            sessions.removeAll {
                $0.isPersistent
                    && !profileIDs.contains($0.id)
                    && processes[$0.id] == nil
            }

            for profile in profiles {
                let isRunning = launcher.profileStore.isProfileInUse(
                    profile.profileURL
                )
                if !isRunning,
                   launcher.profileStore.processID(for: profile.profileURL) != nil {
                    try? launcher.profileStore.clearProcessID(
                        for: profile.profileURL
                    )
                }

                let summary = SessionSummary(
                    id: profile.id,
                    browserName: browsers.first?.name ?? "Google Chrome",
                    name: profile.metadata.name,
                    color: profile.metadata.color,
                    createdAt: profile.metadata.createdAt,
                    isPersistent: true,
                    isRunning: isRunning
                )
                if let index = sessions.firstIndex(
                    where: { $0.id == profile.id }
                ) {
                    sessions[index] = summary
                } else {
                    sessions.append(summary)
                }
            }

            sessions.sort { $0.createdAt < $1.createdAt }
            nextSessionNumber = max(nextSessionNumber, sessions.count + 1)
            if selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runningProcessID(for id: UUID) -> Int32? {
        if let process = processes[id], process.isRunning {
            return process.processIdentifier
        }
        guard let storedProfile = storedProfiles[id],
              launcher.profileStore.isProfileInUse(
                storedProfile.profileURL
              ) else {
            return nil
        }
        return launcher.profileStore.processID(
            for: storedProfile.profileURL
        )
    }

    private func selectNextColor() {
        let colors = SessionColor.allCases
        nextColorIndex = (nextColorIndex + 1) % colors.count
        selectedColor = colors[nextColorIndex]
    }

    private func sessionDidTerminate(id: UUID) {
        processes[id] = nil
        dockTileConnections[id] = nil
        closingSessionIDs.remove(id)

        if sessions.first(where: { $0.id == id })?.isPersistent == true {
            markSessionStopped(id: id)
        } else {
            sessions.removeAll { $0.id == id }
            if selectedSessionID == id {
                selectedSessionID = sessions.first?.id
            }
        }

        refreshLeftoverCount()
    }

    private func markSessionStopped(id: UUID) {
        processes[id] = nil
        dockTileConnections[id] = nil
        closingSessionIDs.remove(id)
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].isRunning = false
        }
        if let storedProfile = storedProfiles[id] {
            try? launcher.profileStore.clearProcessID(
                for: storedProfile.profileURL
            )
        }
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
