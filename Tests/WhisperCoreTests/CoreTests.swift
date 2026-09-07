import XCTest
@testable import WhisperCore

final class CoreTests: XCTestCase {
    func testOnlyWholeAnnotationsAreRemoved() {
        XCTAssertEqual(TranscriptFilter.clean("[music]\nI like music.\n[sighs]", mode: .normal), "I like music.")
        XCTAssertEqual(TranscriptFilter.clean("Use [brackets] in the music section.", mode: .strong), "Use [brackets] in the music section.")
        XCTAssertEqual(TranscriptFilter.clean("[music]", mode: .off), "[music]")
        XCTAssertEqual(TranscriptFilter.clean("\n[BLANK_AUDIO]\n ", mode: .normal), "")
        XCTAssertEqual(TranscriptFilter.clean("Yes, yes, yes.", mode: .strong), "Yes, yes, yes.")
    }
    func testEndpointDoesNotAllowRemotePlaintextOrEmbeddedCredentials() {
        XCTAssertThrowsError(try EndpointPolicy.validate("http://example.com/transcribe"))
        XCTAssertThrowsError(try EndpointPolicy.validate("https://key:secret@example.com/transcribe"))
        XCTAssertThrowsError(try EndpointPolicy.validate("https://example.com/transcribe?key=secret"))
        XCTAssertNoThrow(try EndpointPolicy.validate("http://localhost:8080/v1/audio/transcriptions"))
    }
    func testMultipartPreservesAudioAndUsesProviderLanguageField() {
        let data = Multipart.audio(data: Data([0, 1, 255]), model: "gpt-transcribe", language: "ru", openAI: true, boundary: "test")
        XCTAssertNotNil(data.range(of: Data([0, 1, 255])))
        XCTAssertNotNil(data.range(of: Data("name=\"languages[]\"".utf8)))
        XCTAssertTrue(data.suffix(12) == Data("\r\n--test--\r\n".utf8))
    }
    func testShortcutRoundTripAndValidation() throws {
        let candidate = KeyboardShortcut(keyCode: 2, modifiers: 4096 | 512, keyLabel: "D")
        XCTAssertTrue(candidate.isValid)
        XCTAssertEqual(candidate.display, "⌃⇧D")
        XCTAssertEqual(try JSONDecoder().decode(KeyboardShortcut.self, from: JSONEncoder().encode(candidate)), candidate)
        XCTAssertTrue(KeyboardShortcut(keyCode: 2, modifiers: 512, keyLabel: "D").isValid)
        XCTAssertTrue(KeyboardShortcut(keyCode: 53, modifiers: 2048, keyLabel: "Escape").isValid)
    }
    func testSingleKeysModifiersAndLegacyShortcutDecoding() throws {
        for key: UInt32 in [0, 49, 53, 57, 60, 61, 63, 101, 123] {
            XCTAssertTrue(KeyboardShortcut(keyCode: key, modifiers: 0, keyLabel: "Key").isValid)
        }
        XCTAssertFalse(KeyboardShortcut(keyCode: 128, modifiers: 0, keyLabel: "Invalid").isValid)
        let old = Data(#"{"keyCode":49,"modifiers":2048,"keyLabel":"Space"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardShortcut.self, from: old), .standard)
        let chord = KeyboardShortcut(keyCode: 0, modifiers: 0, keyLabel: "A + B", additionalKeys: [11])
        XCTAssertTrue(chord.needsEventTap)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardShortcut.self, from: JSONEncoder().encode(chord)), chord)
    }
    func testCaptureWaitsForReleaseAndKeepsCompleteChord() {
        var capture = ShortcutGesture()
        XCTAssertNil(capture.update(key: 56, down: true, modifiers: 512))
        XCTAssertNil(capture.update(key: 0, down: true, modifiers: 512))
        XCTAssertNil(capture.update(key: 11, down: true, modifiers: 512))
        XCTAssertNil(capture.update(key: 0, down: false, modifiers: 512))
        XCTAssertNil(capture.update(key: 56, down: false, modifiers: 0))
        let result = capture.update(key: 11, down: false, modifiers: 0)
        XCTAssertEqual(result?.keys, [56, 0, 11])
        XCTAssertEqual(result?.modifiers, 512)
        XCTAssertNil(capture.update(key: 53, down: true, modifiers: 0))
        XCTAssertEqual(capture.update(key: 53, down: false, modifiers: 0)?.keys, [53])
    }
    func testModifierTapDoesNotFireWhenUsedForTypingOrMouse() {
        var matcher = ShortcutMatcher(shortcut: KeyboardShortcut(keyCode: 61, modifiers: 0, keyLabel: "Right Option"))
        XCTAssertFalse(matcher.update(key: 61, down: true, modifiers: 2048).trigger)
        XCTAssertTrue(matcher.update(key: 61, down: false, modifiers: 0).trigger)
        _ = matcher.update(key: 61, down: true, modifiers: 2048)
        _ = matcher.update(key: 0, down: true, modifiers: 2048)
        _ = matcher.update(key: 0, down: false, modifiers: 2048)
        XCTAssertFalse(matcher.update(key: 61, down: false, modifiers: 0).trigger)
        _ = matcher.update(key: 61, down: true, modifiers: 2048)
        matcher.usedWithMouse()
        XCTAssertFalse(matcher.update(key: 61, down: false, modifiers: 0).trigger)
        _ = matcher.update(key: 58, down: true, modifiers: 2048)
        XCTAssertFalse(matcher.update(key: 58, down: false, modifiers: 0).trigger)
    }
    func testModifierChordAndCapsLockPulse() {
        var matcher = ShortcutMatcher(shortcut: KeyboardShortcut(keyCode: 55, modifiers: 0, keyLabel: "Command + Shift", additionalKeys: [56]))
        _ = matcher.update(key: 55, down: true, modifiers: 256)
        _ = matcher.update(key: 56, down: true, modifiers: 768)
        XCTAssertFalse(matcher.update(key: 55, down: false, modifiers: 512).trigger)
        XCTAssertTrue(matcher.update(key: 56, down: false, modifiers: 0).trigger)
        var caps = ShortcutMatcher(shortcut: KeyboardShortcut(keyCode: 57, modifiers: 0, keyLabel: "Caps Lock"))
        for _ in 0..<2 {
            XCTAssertFalse(caps.update(key: 57, down: true, modifiers: 0).trigger)
            XCTAssertTrue(caps.update(key: 57, down: false, modifiers: 0).trigger)
        }
    }
    func testChordMatchesExactlyAndSuppressesRepeatsAndMatchingKeyUp() {
        var matcher = ShortcutMatcher(shortcut: KeyboardShortcut(keyCode: 0, modifiers: 512, keyLabel: "A + B", additionalKeys: [11]))
        XCTAssertFalse(matcher.update(key: 0, down: true, modifiers: 512).trigger)
        let match = matcher.update(key: 11, down: true, modifiers: 512)
        XCTAssertTrue(match.trigger); XCTAssertTrue(match.suppress)
        let repeated = matcher.update(key: 11, down: true, modifiers: 512, repeatKey: true)
        XCTAssertFalse(repeated.trigger); XCTAssertTrue(repeated.suppress)
        XCTAssertTrue(matcher.update(key: 11, down: false, modifiers: 512).suppress)
        XCTAssertFalse(matcher.update(key: 0, down: false, modifiers: 512).suppress)
        _ = matcher.update(key: 0, down: true, modifiers: 0)
        XCTAssertFalse(matcher.update(key: 11, down: true, modifiers: 0).trigger)
    }
    func testOverlayFlipsBelowCursorAtScreenTop() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let point = OverlayPlacement.origin(anchor: CGRect(x: 1400, y: 870, width: 1, height: 20), screen: screen, size: CGSize(width: 292, height: 64))
        XCTAssertEqual(point.x, 1138)
        XCTAssertEqual(point.y, 796)
    }
    func testOverlayWorksOnDisplayLeftOfPrimaryAndClampsBottom() {
        let point = OverlayPlacement.origin(anchor: CGRect(x: -1920, y: -300, width: 1, height: 20), screen: CGRect(x: -1920, y: 0, width: 1920, height: 1080), size: CGSize(width: 292, height: 64))
        XCTAssertEqual(point, CGPoint(x: -1910, y: 10))
    }
}
