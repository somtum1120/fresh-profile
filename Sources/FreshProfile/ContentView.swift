import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                launchPanel
                    .frame(width: 270)
                    .padding(24)

                Divider()

                sessionsPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            }

            if model.leftoverCount > 0 {
                Divider()
                .padding(.horizontal, 24)
                leftoverNotice
                    .padding(16)
                    .padding(.horizontal, 8)
            }

            Divider()
            privacyFooter
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
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
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("FreshProfile")
                    .font(.title.bold())
                Text("Named, color-coded private Chrome windows.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !model.sessions.isEmpty {
                Text("\(model.sessions.count) active")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("New private window", systemImage: "plus.square.on.square")
                .font(.headline)

            if model.browsers.isEmpty {
                missingBrowser
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Research", text: $model.draftSessionName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            model.openIsolatedWindow()
                        }
                    Text("Leave blank for an automatic name.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Color")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    colorPicker
                }

                Picker("Browser", selection: $model.selectedBrowserID) {
                    ForEach(model.browsers) { browser in
                        Text(browser.name).tag(Optional(browser.id))
                    }
                }
                .pickerStyle(.menu)

                Button {
                    model.openIsolatedWindow()
                } label: {
                    Label("Open private window", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(model.selectedColor.swiftUIColor)
            }

            Spacer(minLength: 0)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(SessionColor.allCases) { color in
                Button {
                    model.selectedColor = color
                } label: {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if model.selectedColor == color {
                                Circle()
                                    .stroke(.primary, lineWidth: 2)
                                    .padding(-4)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.displayName)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(
                    model.selectedColor == color ? .isSelected : []
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    private var missingBrowser: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Google Chrome not found")
                .font(.headline)
            Text("Install Chrome in Applications, then refresh.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Refresh") {
                model.refresh()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var sessionsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Private windows", systemImage: "square.stack.3d.up")
                    .font(.headline)
                Spacer()
                sessionActions
            }

            if model.sessions.isEmpty {
                emptySessions
            } else {
                List(selection: $model.selectedSessionID) {
                    ForEach(model.sessions) { session in
                        SessionRow(
                            session: session,
                            isClosing: model.closingSessionIDs.contains(
                                session.id
                            )
                        )
                        .tag(session.id)
                        .onTapGesture {
                            model.selectedSessionID = session.id
                            model.showSession(id: session.id)
                        }
                        .contextMenu {
                            Button("Show Window") {
                                model.showSession(id: session.id)
                            }
                            Divider()
                            Button("Close Window", role: .destructive) {
                                model.closeSession(id: session.id)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Click a window to bring it to the front.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var sessionActions: some View {
        HStack(spacing: 8) {
            Button {
                model.showSelectedSession()
            } label: {
                Label("Show", systemImage: "macwindow")
            }
            .disabled(model.selectedSession == nil)

            Button(role: .destructive) {
                model.closeSelectedSession()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .disabled(
                model.selectedSession == nil
                    || model.selectedSessionID.map {
                        model.closingSessionIDs.contains($0)
                    } == true
            )
        }
        .controlSize(.small)
    }

    private var emptySessions: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No private windows are open")
                .font(.title3.weight(.semibold))
            Text("Give one a name and color, then open it.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var leftoverNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(
                "\(model.leftoverCount) interrupted "
                    + (model.leftoverCount == 1 ? "session has" : "sessions have")
                    + " removable data."
            )
            .font(.callout)

            Spacer()

            Button("Remove data") {
                model.removeLeftovers()
            }
        }
    }

    private var privacyFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
            Text(
                "Every window has separate disposable site data. "
                    + "FreshProfile does not make browsing anonymous."
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

private struct SessionRow: View {
    let session: SessionSummary
    let isClosing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(session.color.swiftUIColor)
                .frame(width: 14, height: 14)
                .shadow(
                    color: session.color.swiftUIColor.opacity(0.35),
                    radius: 4
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(session.browserName)
                    Text("·")
                    Text(session.startedAt, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isClosing {
                ProgressView()
                    .controlSize(.small)
                    .help("Closing")
            } else {
                Text(session.color.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(session.color.swiftUIColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        session.color.swiftUIColor.opacity(0.12),
                        in: Capsule()
                    )
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(session.name), \(session.color.displayName), \(session.browserName)"
        )
    }
}

private extension SessionColor {
    var swiftUIColor: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
