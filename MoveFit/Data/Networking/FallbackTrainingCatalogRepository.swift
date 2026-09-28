import Foundation

struct FallbackTrainingCatalogRepository: TrainingCatalogProviding {
    private let remote: TrainingCatalogProviding
    private let fallback: TrainingCatalogProviding

    init(remote: TrainingCatalogProviding, fallback: TrainingCatalogProviding = BundledTrainingCatalog()) {
        self.remote = remote
        self.fallback = fallback
    }

    func plans(locale: String) async throws -> TrainingCatalogResult {
        do {
            return try await remote.plans(locale: locale)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            let fallbackResult = try await fallback.plans(locale: locale)
            let reason: TrainingCatalogFailure = (error as? BackendError) == .invalidResponse
                ? .incompatibleResponse : .unavailable
            return TrainingCatalogResult(plans: fallbackResult.plans, source: .bundledFallback(reason: reason))
        }
    }
}
