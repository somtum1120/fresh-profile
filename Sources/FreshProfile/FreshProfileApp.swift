import Combine
import Sparkle
import SwiftUI

@MainActor
private final class UpdateMenuModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

private struct CheckForUpdatesView: View {
    @ObservedObject private var model: UpdateMenuModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        model = UpdateMenuModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!model.canCheckForUpdates)
    }
}

@main
struct FreshProfileApp: App {
    @StateObject private var model = AppModel()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .defaultSize(width: 780, height: 580)
        .windowResizability(.automatic)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(
                    updater: updaterController.updater
                )
            }

            CommandGroup(replacing: .newItem) {
                Button("New Profile") {
                    model.openIsolatedWindow()
                }
                .keyboardShortcut("n")
                .disabled(model.selectedBrowser == nil)
            }

            CommandMenu("Profile") {
                Button("Open or Show Selected Profile") {
                    model.openOrShowSelectedSession()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.selectedSession == nil)

                Button("Close Selected Window") {
                    model.closeSelectedSession()
                }
                .disabled(model.selectedSession?.isRunning != true)

                Divider()

                Button("Refresh Browsers") {
                    model.refresh()
                }
                .keyboardShortcut("r")
            }
        }
    }
}
