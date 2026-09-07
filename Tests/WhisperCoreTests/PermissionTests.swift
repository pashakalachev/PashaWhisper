import XCTest
import AVFoundation
@testable import PashaWhisper

final class PermissionTests: XCTestCase {
    func testCheckedAccessibilityAloneDoesNotMeanPasteWorks() {
        XCTAssertFalse(PermissionState(accessibility: true, eventPosting: false, microphone: .authorized).autoPasteReady)
        XCTAssertFalse(PermissionState(accessibility: false, eventPosting: true, microphone: .authorized).autoPasteReady)
    }
    func testSetupRequiresMicrophoneAfterPasteAccess() {
        for microphone: AVAuthorizationStatus in [.notDetermined, .denied, .restricted] {
            let state = PermissionState(accessibility: true, eventPosting: true, microphone: microphone)
            XCTAssertTrue(state.autoPasteReady); XCTAssertFalse(state.ready)
        }
        XCTAssertTrue(PermissionState(accessibility: true, eventPosting: true, microphone: .authorized).ready)
    }
}
