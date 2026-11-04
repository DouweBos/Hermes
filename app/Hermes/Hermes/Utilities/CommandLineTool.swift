// Utilities/CommandLineTool.swift
// Hermes
//
// Links the `hermes` command in the app bundle onto the PATH, asking for an admin password only when needed.

import Foundation
import Observation

@Observable
final class CommandLineTool {
    let link: URL
    let source: URL?
    private(set) var isInstalled = false
    private(set) var error: String?

    init(link: URL = URL(fileURLWithPath: "/usr/local/bin/hermes"),
         source: URL? = Bundle.main.url(forResource: "hermes", withExtension: nil)) {
        self.link = link
        self.source = source
        refresh()
    }

    func refresh() {
        let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        isInstalled = target != nil && target == source?.path
    }

    func install() {
        guard let source else { return fail("The command is missing from the app.") }
        // A link from an earlier copy of Hermes is ours to replace; anything else isn't.
        if !isSymlink(link), FileManager.default.fileExists(atPath: link.path) {
            return fail("Something else is already at \(link.path).")
        }
        run(["mkdir", "-p", link.deletingLastPathComponent().path], ["ln", "-sfn", source.path, link.path]) {
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if isSymlink(link) { try FileManager.default.removeItem(at: link) }
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        }
    }

    func uninstall() {
        guard isInstalled else { return }
        run(["rm", "-f", link.path]) { try FileManager.default.removeItem(at: link) }
    }

    /// Tries directly first; `/usr/local/bin` is often root's, so falls back to the administrator prompt.
    private func run(_ commands: [String]..., directly: () throws -> Void) {
        error = nil
        do {
            try directly()
        } catch where Self.isPermissionError(error) {
            runAsAdministrator(commands)
        } catch {
            fail(error.localizedDescription)
        }
        refresh()
    }

    private func runAsAdministrator(_ commands: [[String]]) {
        let shell = commands.map { $0.map(Self.shellQuoted).joined(separator: " ") }.joined(separator: " && ")
        let script = "do shell script \"\(Self.appleScriptEscaped(shell))\" with administrator privileges"
        var info: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&info)
        // -128: the person cancelled the password prompt.
        if let info, info[NSAppleScript.errorNumber] as? Int != -128 {
            fail(info[NSAppleScript.errorMessage] as? String ?? "Couldn't change \(link.path).")
        }
    }

    private func fail(_ message: String) {
        error = message
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let error = error as NSError
        let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError ?? error
        return (error.domain == NSCocoaErrorDomain && error.code == CocoaError.fileWriteNoPermission.rawValue)
            || (underlying.domain == NSPOSIXErrorDomain && [EACCES, EPERM].contains(Int32(underlying.code)))
    }

    static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptEscaped(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
