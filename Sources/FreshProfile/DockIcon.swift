import AppKit
import Darwin
import Foundation

enum SessionDockIcon {
    static let canvasSize = NSSize(width: 512, height: 512)

    static func pngData(
        browserExecutableURL: URL,
        color: SessionColor,
        workspace: NSWorkspace = .shared
    ) -> Data? {
        guard let appURL = applicationBundleURL(for: browserExecutableURL) else {
            return nil
        }

        let browserIcon = workspace.icon(forFile: appURL.path)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }
        context.imageInterpolation = .high
        browserIcon.draw(
            in: NSRect(x: 16, y: 16, width: 480, height: 480),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        context.cgContext.saveGState()
        context.cgContext.setBlendMode(.sourceAtop)
        context.cgContext.setFillColor(
            color.nsColor.withAlphaComponent(0.58).cgColor
        )
        context.cgContext.fill(NSRect(x: 16, y: 16, width: 480, height: 480))
        context.cgContext.restoreGState()

        let badgeRect = NSRect(x: 306, y: 22, width: 184, height: 184)
        NSColor.white.withAlphaComponent(0.96).setFill()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: -10, dy: -10)).fill()
        color.nsColor.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        context.flushGraphics()
        return bitmap.representation(using: .png, properties: [:])
    }

    static func applicationBundleURL(for executableURL: URL) -> URL? {
        let macOSURL = executableURL.deletingLastPathComponent()
        let contentsURL = macOSURL.deletingLastPathComponent()
        let appURL = contentsURL.deletingLastPathComponent()

        guard macOSURL.lastPathComponent == "MacOS",
              contentsURL.lastPathComponent == "Contents",
              appURL.pathExtension == "app" else {
            return nil
        }

        return appURL
    }
}

struct DockTileProtocol {
    static func setIconMessage(pngData: Data) throws -> Data {
        try message(
            id: 1,
            method: "Browser.setDockTile",
            params: ["image": pngData.base64EncodedString()]
        )
    }

    static func getTargetsMessage(id: Int) throws -> Data {
        try message(id: id, method: "Target.getTargets")
    }

    static func createWindowMessage(id: Int) throws -> Data {
        try message(
            id: id,
            method: "Target.createTarget",
            params: [
                "url": "chrome://newtab/",
                "newWindow": true,
                "focus": true
            ]
        )
    }

    static func closeTargetMessage(id: Int, targetID: String) throws -> Data {
        try message(
            id: id,
            method: "Target.closeTarget",
            params: ["targetId": targetID]
        )
    }

    private static func message(
        id: Int,
        method: String,
        params: [String: Any]? = nil
    ) throws -> Data {
        var object: [String: Any] = [
            "id": id,
            "method": method
        ]
        if let params {
            object["params"] = params
        }

        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0)
        return data
    }
}

enum SessionWindowResult: Equatable {
    case existing
    case created
    case unavailable
}

final class DockTileConnection {
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let iconMessage: Data
    private let transactionLock = NSLock()
    private var responseBuffer = Data()
    private var nextMessageID = 2

    init?(browserExecutableURL: URL, color: SessionColor) {
        guard let pngData = SessionDockIcon.pngData(
            browserExecutableURL: browserExecutableURL,
            color: color
        ),
        let message = try? DockTileProtocol.setIconMessage(pngData: pngData) else {
            return nil
        }

        iconMessage = message
    }

    func configure(_ process: Process) {
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
    }

    func apply() {
        try? inputPipe.fileHandleForWriting.write(contentsOf: iconMessage)
    }

    func response(timeout: TimeInterval) -> [String: Any]? {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        return readResponse(id: 1, timeout: timeout)
    }

    func ensureWindow(timeout: TimeInterval = 2) -> SessionWindowResult {
        transactionLock.lock()
        defer { transactionLock.unlock() }

        guard let targets = pageTargets(timeout: timeout) else {
            return .unavailable
        }
        guard targets.isEmpty else {
            return .existing
        }

        let id = takeMessageID()
        guard send(try? DockTileProtocol.createWindowMessage(id: id)),
              let response = readResponse(id: id, timeout: timeout),
              response["error"] == nil,
              let result = response["result"] as? [String: Any],
              result["targetId"] as? String != nil else {
            return .unavailable
        }
        return .created
    }

    func closePageTargetsForTesting(
        timeout: TimeInterval = 2
    ) -> Bool {
        transactionLock.lock()
        defer { transactionLock.unlock() }

        guard let targets = pageTargets(timeout: timeout) else {
            return false
        }

        for targetID in targets {
            let id = takeMessageID()
            guard send(
                try? DockTileProtocol.closeTargetMessage(
                    id: id,
                    targetID: targetID
                )
            ),
            let response = readResponse(id: id, timeout: timeout),
            response["error"] == nil else {
                return false
            }
        }
        return true
    }

    private func pageTargets(timeout: TimeInterval) -> [String]? {
        let id = takeMessageID()
        guard send(try? DockTileProtocol.getTargetsMessage(id: id)),
              let response = readResponse(id: id, timeout: timeout),
              response["error"] == nil,
              let result = response["result"] as? [String: Any],
              let targetInfos = result["targetInfos"] as? [[String: Any]] else {
            return nil
        }

        return targetInfos.compactMap { target in
            guard target["type"] as? String == "page" else {
                return nil
            }
            return target["targetId"] as? String
        }
    }

    private func takeMessageID() -> Int {
        defer { nextMessageID += 1 }
        return nextMessageID
    }

    private func send(_ data: Data?) -> Bool {
        guard let data else { return false }
        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }

    private func readResponse(
        id: Int,
        timeout: TimeInterval
    ) -> [String: Any]? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            while let messageData = nextBufferedMessage() {
                guard let object = try? JSONSerialization.jsonObject(
                    with: messageData
                ) as? [String: Any] else {
                    continue
                }
                if object["id"] as? Int == id {
                    return object
                }
            }

            let remainingMilliseconds = max(
                1,
                Int32(deadline.timeIntervalSinceNow * 1_000)
            )
            guard readMore(timeoutMilliseconds: remainingMilliseconds) else {
                return nil
            }
        }
        return nil
    }

    private func nextBufferedMessage() -> Data? {
        guard let terminator = responseBuffer.firstIndex(of: 0) else {
            return nil
        }
        let message = Data(responseBuffer[..<terminator])
        responseBuffer.removeSubrange(...terminator)
        return message
    }

    private func readMore(timeoutMilliseconds: Int32) -> Bool {
        let fileDescriptor = outputPipe.fileHandleForReading.fileDescriptor
        var descriptor = pollfd(
            fd: fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )
        guard Darwin.poll(&descriptor, 1, timeoutMilliseconds) > 0,
              descriptor.revents & Int16(POLLIN) != 0 else {
            return false
        }

        var bytes = [UInt8](repeating: 0, count: 65_536)
        let byteCount = bytes.withUnsafeMutableBytes { buffer in
            Darwin.read(
                fileDescriptor,
                buffer.baseAddress,
                buffer.count
            )
        }
        guard byteCount > 0 else { return false }
        responseBuffer.append(contentsOf: bytes.prefix(byteCount))
        return true
    }
}

private extension SessionColor {
    var nsColor: NSColor {
        NSColor(
            red: CGFloat(rgb.red),
            green: CGFloat(rgb.green),
            blue: CGFloat(rgb.blue),
            alpha: 1
        )
    }
}
