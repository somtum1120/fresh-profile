import Foundation

enum SessionColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case sky
    case mint
    case violet
    case rose
    case orange
    case slate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sky: "Sky"
        case .mint: "Mint"
        case .violet: "Violet"
        case .rose: "Rose"
        case .orange: "Orange"
        case .slate: "Slate"
        }
    }

    var hex: String {
        switch self {
        case .sky: "#38A7F0"
        case .mint: "#32C795"
        case .violet: "#8B6DE9"
        case .rose: "#E66B91"
        case .orange: "#E9903D"
        case .slate: "#65758B"
        }
    }

    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .sky: (0.22, 0.65, 0.94)
        case .mint: (0.20, 0.78, 0.58)
        case .violet: (0.55, 0.43, 0.91)
        case .rose: (0.90, 0.42, 0.57)
        case .orange: (0.91, 0.56, 0.24)
        case .slate: (0.40, 0.46, 0.55)
        }
    }
}

struct SessionMetadata: Codable, Equatable, Sendable {
    let name: String
    let color: SessionColor
    let createdAt: Date
}

enum SessionName {
    static let maximumLength = 40

    static func normalized(_ value: String, fallbackNumber: Int) -> String {
        let collapsed = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let limited = String(collapsed.prefix(maximumLength))
        return limited.isEmpty ? "Private \(fallbackNumber)" : limited
    }
}

enum SessionLandingPage {
    static func write(
        metadata: SessionMetadata,
        to profileURL: URL
    ) throws -> URL {
        let pageURL = profileURL.appendingPathComponent(
            "FreshProfile Start.html",
            isDirectory: false
        )
        try Data(html(metadata: metadata).utf8).write(
            to: pageURL,
            options: .atomic
        )
        return pageURL
    }

    static func html(metadata: SessionMetadata) -> String {
        let name = escapeHTML(metadata.name)
        let color = metadata.color.hex

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(name) — FreshProfile</title>
          <style>
            :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
            body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: color-mix(in srgb, \(color) 16%, Canvas); color: CanvasText; }
            main { width: min(560px, calc(100% - 48px)); text-align: center; }
            .dot { width: 72px; height: 72px; margin: 0 auto 24px; border-radius: 50%; background: \(color); box-shadow: 0 12px 38px color-mix(in srgb, \(color) 45%, transparent); }
            h1 { margin: 0; font-size: clamp(34px, 7vw, 54px); letter-spacing: -0.04em; }
            p { margin: 14px auto 0; max-width: 460px; font-size: 17px; line-height: 1.55; opacity: .68; }
            .label { display: inline-block; margin-top: 28px; padding: 8px 13px; border: 1px solid color-mix(in srgb, \(color) 48%, transparent); border-radius: 999px; color: \(color); font-weight: 650; }
          </style>
        </head>
        <body>
          <main>
            <div class="dot" aria-hidden="true"></div>
            <h1>\(name)</h1>
            <p>This window has its own disposable browser profile. Its cookies and site data are separate from your other FreshProfile windows.</p>
            <div class="label">Private window · \(metadata.color.displayName)</div>
          </main>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
