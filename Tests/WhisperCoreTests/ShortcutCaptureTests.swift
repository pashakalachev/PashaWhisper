import XCTest
import AppKit
import Carbon
@testable import PashaWhisper
import WhisperCore

final class ShortcutCaptureTests: XCTestCase {
    @MainActor private func event(_ type: NSEvent.EventType, key: UInt16, flags: NSEvent.ModifierFlags = [], text: String = "") -> NSEvent {
        NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: key)!
    }
    @MainActor func testSpaceEscapeAndShiftOnlyCombinationCapture() {
        let recorder = ShortcutRecorder()
        for (key, label): (UInt16,String) in [(49,"Space"),(53,"Escape")] {
            recorder.reset()
            XCTAssertNil(recorder.observe(event(.keyDown, key: key)))
            let result = recorder.observe(event(.keyUp, key: key))
            XCTAssertEqual(result?.display, label)
            XCTAssertEqual(result?.modifiers, 0)
        }
        recorder.reset()
        _ = recorder.observe(event(.keyDown, key: 0, flags: .shift, text: "A"))
        XCTAssertEqual(recorder.observe(event(.keyUp, key: 0, flags: .shift, text: "A"))?.display, "⇧A")
    }
    @MainActor func testRightOptionAndFnCaptureFromEventState() {
        let recorder = ShortcutRecorder()
        let rightOption = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | UInt(NX_DEVICERALTKEYMASK))
        XCTAssertNil(recorder.observe(event(.flagsChanged, key: 61, flags: rightOption)))
        let option = recorder.observe(event(.flagsChanged, key: 61))
        XCTAssertEqual(option?.display, "Right Option")
        XCTAssertEqual(option?.keys, [61])
        recorder.reset()
        XCTAssertNil(recorder.observe(event(.flagsChanged, key: 63, flags: .function)))
        XCTAssertEqual(recorder.observe(event(.flagsChanged, key: 63))?.display, "Fn / Globe")
    }
    @MainActor func testPhysicalSidesAndImplicitFunctionFlag() {
        let leftOption = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | UInt(NX_DEVICELALTKEYMASK))
        XCTAssertFalse(ShortcutKeys.input(event(.flagsChanged, key: 61, flags: leftOption), held: [58,61])!.down)
        XCTAssertTrue(ShortcutKeys.input(event(.flagsChanged, key: 58, flags: leftOption))!.down)
        XCTAssertEqual(ShortcutKeys.input(event(.keyDown, key: 101, flags: .function))?.modifiers, 0)
        XCTAssertEqual(ShortcutKeys.input(event(.keyDown, key: 101, flags: .function), held: [63])?.modifiers, KeyboardShortcut.fnModifier)
    }
    @MainActor func testPedalF18FunctionFlagIsNotPhysicalFn() {
        for flags: NSEvent.ModifierFlags in [[], .function, [.function, .numericPad]] {
            let recorder = ShortcutRecorder()
            XCTAssertNil(recorder.observe(event(.keyDown, key: 79, flags: flags, text: "\u{F715}")))
            let saved = recorder.observe(event(.keyUp, key: 79, flags: flags, text: "\u{F715}"))
            XCTAssertEqual(saved, .f18Pedal)
            XCTAssertFalse(saved!.needsEventTap)
            var matcher = ShortcutMatcher(shortcut: saved!)
            let down = ShortcutKeys.input(event(.keyDown, key: 79, flags: flags))!
            XCTAssertTrue(matcher.update(key: down.key, down: down.down, modifiers: down.modifiers).trigger)
            let up = ShortcutKeys.input(event(.keyUp, key: 79, flags: flags))!
            XCTAssertFalse(matcher.update(key: up.key, down: up.down, modifiers: up.modifiers).trigger)
            XCTAssertTrue(matcher.update(key: down.key, down: down.down, modifiers: down.modifiers).trigger)
        }
    }
    @MainActor func testRealFnPlusF18RemainsDistinct() {
        let recorder = ShortcutRecorder()
        _ = recorder.observe(event(.flagsChanged, key: 63, flags: .function))
        _ = recorder.observe(event(.keyDown, key: 79, flags: .function))
        XCTAssertNil(recorder.observe(event(.keyUp, key: 79, flags: .function)))
        let saved = recorder.observe(event(.flagsChanged, key: 63))
        XCTAssertEqual(saved?.keyCode, 79)
        XCTAssertEqual(saved?.modifiers, KeyboardShortcut.fnModifier)
        XCTAssertEqual(saved?.display, "Fn+F18")
    }
    @MainActor func testMultipleNormalKeysAreSavedAsAChord() {
        let recorder = ShortcutRecorder()
        _ = recorder.observe(event(.keyDown, key: 0, text: "a"))
        _ = recorder.observe(event(.keyDown, key: 11, text: "b"))
        XCTAssertNil(recorder.observe(event(.keyUp, key: 11, text: "b")))
        let result = recorder.observe(event(.keyUp, key: 0, text: "a"))
        XCTAssertEqual(result?.keys, [0,11])
        XCTAssertEqual(result?.display, "A + B")
        XCTAssertTrue(result?.needsEventTap == true)
    }
}
