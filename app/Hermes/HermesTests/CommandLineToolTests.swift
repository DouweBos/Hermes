// CommandLineToolTests.swift
// HermesTests
//
// Installing the hermes link where no administrator is needed.

import XCTest
@testable import Hermes

final class CommandLineToolTests: XCTestCase {
    private func makeTool() -> (CommandLineTool, URL) {
        let source = makeFile(named: "hermes")
        let link = makeStorage().root.appendingPathComponent("bin/hermes")
        return (CommandLineTool(link: link, source: source), source)
    }

    func testInstallAndUninstall() throws {
        let (tool, source) = makeTool()
        XCTAssertFalse(tool.isInstalled)
        tool.install()
        XCTAssertNil(tool.error)
        XCTAssertTrue(tool.isInstalled)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: tool.link.path), source.path)
        tool.uninstall()
        XCTAssertFalse(tool.isInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tool.link.path))
    }

    func testReplacesStaleLink() throws {
        let (tool, _) = makeTool()
        try FileManager.default.createDirectory(at: tool.link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: tool.link.path, withDestinationPath: "/nowhere/hermes")
        tool.refresh()
        XCTAssertFalse(tool.isInstalled)
        tool.install()
        XCTAssertTrue(tool.isInstalled)
    }

    func testLeavesOtherFilesAlone() throws {
        let (tool, _) = makeTool()
        try FileManager.default.createDirectory(at: tool.link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("other".utf8).write(to: tool.link)
        tool.install()
        XCTAssertNotNil(tool.error)
        XCTAssertFalse(tool.isInstalled)
        XCTAssertEqual(try String(contentsOf: tool.link, encoding: .utf8), "other")
    }

    func testQuoting() {
        XCTAssertEqual(CommandLineTool.shellQuoted("/Apps/It's.app"), "'/Apps/It'\\''s.app'")
        XCTAssertEqual(CommandLineTool.appleScriptEscaped("a\"b\\c"), "a\\\"b\\\\c")
    }

    func testPermissionErrors() {
        XCTAssertTrue(CommandLineTool.isPermissionError(CocoaError(.fileWriteNoPermission)))
        XCTAssertTrue(CommandLineTool.isPermissionError(NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))))
        XCTAssertFalse(CommandLineTool.isPermissionError(CocoaError(.fileNoSuchFile)))
    }
}
