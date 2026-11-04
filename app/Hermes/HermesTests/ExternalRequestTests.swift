// ExternalRequestTests.swift
// HermesTests
//
// Parsing files opened with Hermes and hermes:// URLs.

import XCTest
@testable import Hermes

final class ExternalRequestTests: XCTestCase {
    func testAddKeepsOrderAndKinds() throws {
        let url = try XCTUnwrap(URL(string: "hermes://add?path=/tmp/a%20b.txt&text=hello%20there&url=https://example.com/x"))
        XCTAssertEqual(ExternalRequest(url: url), .add([
            .file(URL(fileURLWithPath: "/tmp/a b.txt")),
            .text("hello there"),
            .link(URL(string: "https://example.com/x")!)
        ]))
    }

    func testLoneAddressAsTextBecomesLink() throws {
        let url = try XCTUnwrap(URL(string: "hermes://add?text=%20https://example.com%0A"))
        XCTAssertEqual(ExternalRequest(url: url), .add([.link(URL(string: "https://example.com")!)]))
    }

    func testSkipsEmptyAndUnknownValues() throws {
        XCTAssertNil(ExternalRequest(url: try XCTUnwrap(URL(string: "hermes://add?text=%20%0A&url=ftp://x&foo=bar"))))
        XCTAssertNil(ExternalRequest(url: try XCTUnwrap(URL(string: "hermes://delete?path=/tmp"))))
        XCTAssertNil(ExternalRequest(url: try XCTUnwrap(URL(string: "https://add?path=/tmp"))))
    }

    func testShowPicksTab() throws {
        XCTAssertEqual(ExternalRequest(url: try XCTUnwrap(URL(string: "hermes://show?tab=clipboard"))), .show(.clipboard))
        XCTAssertEqual(ExternalRequest(url: try XCTUnwrap(URL(string: "hermes://show"))), .show(.shelf))
    }

    func testOpenedFilesBecomeOneAdd() throws {
        let files = [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")]
        let show = try XCTUnwrap(URL(string: "hermes://show"))
        XCTAssertEqual(ExternalRequest.requests(for: files + [show]),
                       [.add(files.map(ExternalRequest.Content.file)), .show(.shelf)])
    }
}
