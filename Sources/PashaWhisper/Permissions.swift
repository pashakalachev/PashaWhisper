import AppKit
import AVFoundation

struct PermissionState: Equatable {
    let accessibility: Bool
    let eventPosting: Bool
    let microphone: AVAuthorizationStatus
    var autoPasteReady: Bool { accessibility && eventPosting }
    // A newly granted Accessibility permission can leave Core Graphics
    // reporting its previous denial until this process restarts.
    var pasteNeedsRestart: Bool { accessibility && !eventPosting }
    var ready: Bool { autoPasteReady && microphone == .authorized }
    static func current() -> Self {
        Self(accessibility: AXIsProcessTrusted(), eventPosting: CGPreflightPostEventAccess(),
             microphone: AVCaptureDevice.authorizationStatus(for: .audio))
    }
}
