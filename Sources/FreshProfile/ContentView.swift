import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if model.browsers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "safari")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary)
                    Text("Google Chrome not found")
                        .font(.title3.bold())
                    Text("Install Google Chrome in Applications, then refresh.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)

                Button("Refresh") {
                    model.refresh()
                }
            } else {
                browserPicker

                Button {
                    model.openIsolatedWindow()
                } label: {
                    Label("Open isolated window", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                activeSessions
            }

            if model.leftoverCount > 0 {
                leftoverNotice
            }

            Spacer(minLength: 0)

            Text(
                "Each window uses a disposable browser profile. "
                + "This does not make browsing anonymous."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 430)
        .alert(
            "FreshProfile",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("FreshProfile")
                .font(.largeTitle.bold())
            Text("Open a clean, isolated Chrome window.")
                .foregroundStyle(.secondary)
        }
    }

    private var browserPicker: some View {
        Picker("Browser", selection: $model.selectedBrowserID) {
            ForEach(model.browsers) { browser in
                Text(browser.name).tag(Optional(browser.id))
            }
        }
        .pickerStyle(.menu)
    }

    private var activeSessions: some View {
        GroupBox("Active windows") {
            if model.sessions.isEmpty {
                Text("No isolated windows are open.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.sessions) { session in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.browserName)
                                Text(session.startedAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Close") {
                                model.closeSession(id: session.id)
                            }
                        }
                        .padding(.vertical, 8)

                        if session.id != model.sessions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var leftoverNotice: some View {
        GroupBox {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)

                Text(
                    "\(model.leftoverCount) leftover "
                    + (model.leftoverCount == 1 ? "profile" : "profiles")
                    + " from an interrupted session."
                )

                Spacer()

                Button("Remove") {
                    model.removeLeftovers()
                }
            }
        }
    }
}
