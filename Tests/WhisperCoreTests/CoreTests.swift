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
        XCTAssertFalse(KeyboardShortcut(keyCode: 2, modifiers: 512, keyLabel: "D").isValid)
        XCTAssertFalse(KeyboardShortcut(keyCode: 53, modifiers: 2048, keyLabel: "Escape").isValid)
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
