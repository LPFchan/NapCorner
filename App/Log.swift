import Foundation

/// Tiny synchronous file logger at ~/Library/Logs/NapCorner.log. A menu bar
/// app launched from Finder has no useful stdout, so diagnostics go to a file.
enum Log {
    private static let url = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/NapCorner.log")
    private static let handle: FileHandle? = {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return try? FileHandle(forWritingTo: url)
    }()

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func write(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8), let handle else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.synchronize()
    }
}
