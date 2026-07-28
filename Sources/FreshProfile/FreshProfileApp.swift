import SwiftUI

@main
struct FreshProfileApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .defaultSize(width: 780, height: 580)
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Private Window") {
                    model.openIsolatedWindow()
                }
                .keyboardShortcut("n")
                .disabled(model.selectedBrowser == nil)
            }

            CommandMenu("Session") {
                Button("Show Selected Window") {
                    model.showSelectedSession()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.selectedSession == nil)

                Button("Close Selected Window") {
                    model.closeSelectedSession()
                }
                .disabled(model.selectedSession == nil)

                Divider()

                Button("Refresh Browsers") {
                    model.refresh()
                }
                .keyboardShortcut("r")
            }
        }
    }
}
