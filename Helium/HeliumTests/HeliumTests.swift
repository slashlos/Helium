//
//  HeliumTests.swift
//  HeliumTests
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import XCTest
@testable import Helium

class HeliumTests: XCTestCase {

    func testYouTubeShortURLConvertsToWatchURL() {
        let url = URL(string: "https://youtu.be/jNQXAC9IVRw")!
        let converted = UrlHelpers.doMagic(url)!

        XCTAssertEqual(converted.scheme, "https")
        XCTAssertEqual(converted.host, "www.youtube.com")
        XCTAssertEqual(converted.path, "/watch")
        XCTAssertEqual(queryValue("v", in: converted), "jNQXAC9IVRw")
    }

    func testYouTubeShortURLPreservesTimestamp() {
        let url = URL(string: "https://youtu.be/jNQXAC9IVRw?t=10s")!
        let converted = UrlHelpers.doMagic(url)!

        XCTAssertEqual(converted.host, "www.youtube.com")
        XCTAssertEqual(converted.path, "/watch")
        XCTAssertEqual(queryValue("v", in: converted), "jNQXAC9IVRw")
        XCTAssertEqual(queryValue("t", in: converted), "10s")
    }

    func testYouTubeWatchURLIgnoresExtraQueryParameters() {
        let url = URL(string: "https://www.youtube.com/watch?v=jNQXAC9IVRw&feature=share&list=abc")!
        let converted = UrlHelpers.doMagic(url)!

        XCTAssertEqual(converted.host, "www.youtube.com")
        XCTAssertEqual(converted.path, "/watch")
        XCTAssertEqual(queryValue("v", in: converted), "jNQXAC9IVRw")
        XCTAssertNil(queryValue("feature", in: converted))
        XCTAssertNil(queryValue("list", in: converted))
    }

    func testYouTubeWatchURLIsChromelessCandidate() {
        let url = URL(string: "https://www.youtube.com/watch?v=jNQXAC9IVRw")!

        XCTAssertTrue(url.isYouTubeWatchPage)
        XCTAssertTrue(url.isYouTubeChromelessCandidate)
    }

    func testYouTubeSigninPageIsNotChromelessCandidate() {
        let url = URL(string: "https://accounts.google.com/signin/v2/identifier")!

        XCTAssertFalse(url.isYouTubeWatchPage)
        XCTAssertFalse(url.isYouTubeChromelessCandidate)
    }

    func testValidatedPasteboardURLAcceptsHTTPSURL() {
        let url = UrlHelpers.validatedPasteboardURL(from: "https://www.youtube.com/watch?v=jNQXAC9IVRw")

        XCTAssertEqual(url?.host, "www.youtube.com")
        XCTAssertEqual(queryValue("v", in: url!), "jNQXAC9IVRw")
    }

    func testValidatedPasteboardURLAcceptsBareDomain() {
        let url = UrlHelpers.validatedPasteboardURL(from: "youtube.com/watch?v=jNQXAC9IVRw")

        XCTAssertEqual(url?.host, "www.youtube.com")
        XCTAssertEqual(queryValue("v", in: url!), "jNQXAC9IVRw")
    }

    func testValidatedPasteboardURLAcceptsExistingFilePath() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = directory.appendingPathComponent(UUID().uuidString + ".txt")
        try! Data("hi".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let parsed = UrlHelpers.validatedPasteboardURL(from: fileURL.path)

        XCTAssertEqual(parsed?.standardizedFileURL, fileURL.standardizedFileURL)
    }

    func testValidatedPasteboardURLRejectsMultilineProse() {
        XCTAssertNil(UrlHelpers.validatedPasteboardURL(from: "hello\nhttps://example.com"))
    }

    func testValidatedPasteboardURLRejectsJavaScriptScheme() {
        XCTAssertNil(UrlHelpers.validatedPasteboardURL(from: "javascript:alert(1)"))
    }

    func testBundledHomePageResolverMatchesLegacyDefault() {
        XCTAssertTrue(UserSettings.usesBundledHomePage(UserSettings.HomePageURL.default, incognito: false))
        XCTAssertTrue(UserSettings.usesBundledHomePage(UserSettings.HomeStrkURL.default, incognito: true))
    }

    func testBundledHomePageResolverLeavesCustomHomePageAlone() {
        XCTAssertFalse(UserSettings.usesBundledHomePage("https://example.com/start.html", incognito: false))
    }

    private func queryValue(_ name: String, in url: URL) -> String? {
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
