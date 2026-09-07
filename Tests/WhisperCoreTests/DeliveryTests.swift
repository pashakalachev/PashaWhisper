import XCTest
@testable import PashaWhisper

final class DeliveryTests: XCTestCase {
    func testEmptyResultNeverWritesOrPastes() {
        let error = VerifiedPaste.perform(text: " ", write: { XCTFail("Empty result wrote clipboard"); return 1 },
            unchanged: { _ in true }, destinationMatches: { true }, paste: { XCTFail("Empty result pasted") })
        XCTAssertNotNil(error)
    }
    func testFailedWriteAndClipboardRaceNeverPaste() {
        for revision: Int? in [nil, 3] {
            let error = VerifiedPaste.perform(text: "New transcript", write: { revision }, unchanged: { _ in false },
                destinationMatches: { true }, paste: { XCTFail("Stale clipboard pasted") })
            XCTAssertNotNil(error)
        }
    }
    func testDestinationChangeAfterWriteNeverPastes() {
        var checks = 0
        let error = VerifiedPaste.perform(text: "New transcript", write: { 3 }, unchanged: { _ in true },
            destinationMatches: { checks += 1; return checks == 1 }, paste: { XCTFail("Wrong destination pasted") })
        XCTAssertNotNil(error)
    }
    func testLateClipboardChangeNeverPastes() {
        var checks = 0
        let error = VerifiedPaste.perform(text: "New transcript", write: { 3 }, unchanged: { _ in checks += 1; return checks == 1 },
            destinationMatches: { true }, paste: { XCTFail("Late clipboard change pasted") })
        XCTAssertNotNil(error)
    }
    func testVerifiedTranscriptPastesExactlyOnce() {
        var writes = 0, pastes = 0
        let error = VerifiedPaste.perform(text: "New transcript", write: { writes += 1; return 3 }, unchanged: { $0 == 3 },
            destinationMatches: { true }, paste: { pastes += 1 })
        XCTAssertNil(error); XCTAssertEqual(writes, 1); XCTAssertEqual(pastes, 1)
    }
}
