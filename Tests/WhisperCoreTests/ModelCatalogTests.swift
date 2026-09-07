import XCTest
import WhisperCore
@testable import PashaWhisper

final class ModelCatalogTests: XCTestCase {
    func testEveryNewArtifactIsPinnedAndHasIntegrityMetadata() {
        XCTAssertEqual(LocalModel.catalog.count, 19)
        XCTAssertEqual(Set(LocalModel.catalog.map(\.id)).count, 19)
        XCTAssertEqual(Set(LocalModel.catalog.map(\.filename)).count, 19)
        let models = LocalModel.catalog.filter { $0.engine == .transcribe }
        XCTAssertEqual(models.count, 6)
        for model in models {
            let artifact = model.downloadable!
            XCTAssertEqual(artifact.sha256.count, 64)
            XCTAssertEqual(artifact.revision.count, 40)
            XCTAssertTrue(model.url.path.contains(artifact.revision))
            XCTAssertTrue(model.filename.hasSuffix(".gguf"))
            XCTAssertFalse(model.upstreamID.hasPrefix("openai/"))
            XCTAssertEqual(model.engine.executable, "transcribe-cli")
            XCTAssertGreaterThan(artifact.bytes, 0)
        }
        XCTAssertEqual(LocalModel.catalog[0].id, "tiny.en-q5_1")
        XCTAssertEqual(LocalModel.catalog[0].engine.executable, "whisper-cli")
    }
    func testUnsupportedLanguageAndMissingCohereLanguageAreExplicit() {
        let cohere = LocalModel.catalog.first { $0.family == "cohere" }!
        XCTAssertNotNil(cohere.languageIssue("auto"))
        XCTAssertNotNil(cohere.languageIssue("ru"))
        XCTAssertNil(cohere.languageIssue("fr"))
        let canary = LocalModel.catalog.first { $0.family == "canary" }!
        XCTAssertNotNil(canary.languageIssue("ru"))
        XCTAssertNil(canary.languageIssue("auto"))
        XCTAssertNil(LocalModel.catalog.first { $0.family == "qwen" }!.languageIssue("ru"))
    }
    func testCorruptedNewModelNeverPassesVerification() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("invalid model".utf8).write(to: url)
        XCTAssertThrowsError(try ModelDownload.verify(url, model: LocalModel.catalog.first { $0.engine == .transcribe }!))
    }
}
