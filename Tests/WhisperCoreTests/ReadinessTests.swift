import XCTest
import Foundation
@testable import PashaWhisper

final class ReadinessTests: XCTestCase {
    @MainActor func testMissingModelStopsBeforeMicrophoneAndExplainsSetup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let previousPath = ProcessInfo.processInfo.environment["PASHAWHISPER_DATA_DIR"]
        let previousModel = UserDefaults.standard.object(forKey: "model")
        let previousProvider = UserDefaults.standard.object(forKey: "provider")
        setenv("PASHAWHISPER_DATA_DIR", root.path, 1)
        defer {
            if let previousPath { setenv("PASHAWHISPER_DATA_DIR", previousPath, 1) } else { unsetenv("PASHAWHISPER_DATA_DIR") }
            if let previousModel { UserDefaults.standard.set(previousModel, forKey: "model") } else { UserDefaults.standard.removeObject(forKey: "model") }
            if let previousProvider { UserDefaults.standard.set(previousProvider, forKey: "provider") } else { UserDefaults.standard.removeObject(forKey: "provider") }
            try? FileManager.default.removeItem(at: root)
        }
        let model = AppModel(permissionReader: { PermissionState(accessibility: true, eventPosting: true, microphone: .authorized) }); model.provider = "Offline"; model.selectedModel = "missing-model"
        var attention = false, microphoneStarted = false
        model.onNeedsAttention = { attention = true }
        model.onRecordingChange = { microphoneStarted = $0 }
        model.toggleRecording()
        for _ in 0..<100 where model.preparing { await Task.yield() }
        XCTAssertFalse(model.preparing); XCTAssertFalse(model.recording); XCTAssertFalse(microphoneStarted)
        XCTAssertTrue(attention); XCTAssertEqual(model.section, "Models")
        XCTAssertEqual(model.overlayTitle, "SETUP NEEDED")
        XCTAssertTrue(model.error?.contains("installed model") == true)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Transient").path).isEmpty)
        var access = PermissionState(accessibility: true, eventPosting: false, microphone: .authorized)
        let setup = AppModel(permissionReader: { access })
        setup.onWillRecord = { XCTFail("Recording began before automatic paste access was ready") }
        setup.toggleRecording()
        XCTAssertFalse(setup.busy); XCTAssertEqual(setup.section, "Setup")
        XCTAssertFalse(setup.autoPasteReady)
        access = PermissionState(accessibility: true, eventPosting: true, microphone: .authorized)
        setup.refreshPermissions()
        XCTAssertTrue(setup.autoPasteReady); XCTAssertTrue(setup.permissions.ready)
    }
}
