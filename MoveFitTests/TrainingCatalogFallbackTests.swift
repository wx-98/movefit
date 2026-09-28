import XCTest
@testable import MoveFit

final class TrainingCatalogFallbackTests: XCTestCase {
    func testBundledPlansReplaceFailedRemoteCatalog() async throws {
        let repository = FallbackTrainingCatalogRepository(
            remote: TrainingCatalogFake(error: BackendError.networkUnavailable),
            fallback: BundledTrainingCatalog()
        )

        let result = try await repository.plans(locale: "zh-Hans")

        XCTAssertFalse(result.plans.isEmpty)
        XCTAssertEqual(result.source, .bundledFallback(reason: .unavailable))
    }

    func testCancellationDoesNotUseBundledPlans() async throws {
        let repository = FallbackTrainingCatalogRepository(
            remote: TrainingCatalogFake(error: CancellationError()),
            fallback: BundledTrainingCatalog()
        )

        do {
            _ = try await repository.plans(locale: "en")
            XCTFail("取消请求不得进入降级目录")
        } catch is CancellationError {
            // Expected: cancellation must propagate to the caller.
        }
    }
}

private struct TrainingCatalogFake: TrainingCatalogProviding {
    let error: Error

    func plans(locale: String) async throws -> TrainingCatalogResult {
        throw error
    }
}
