import SwiftUI

@main
struct FreshProfileApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New isolated window") {
                    model.openIsolatedWindow()
                }
                .keyboardShortcut("n")
                .disabled(model.selectedBrowser == nil)
            }
        }
    }
}
