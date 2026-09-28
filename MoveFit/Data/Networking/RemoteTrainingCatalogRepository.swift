import Foundation

struct RemoteTrainingCatalogRepository: TrainingCatalogProviding {
    private let client: MoveFitAPIClient
    private let pageLimit = 50
    private let maximumPages = 100

    init(client: MoveFitAPIClient) {
        self.client = client
    }

    func plans(locale: String) async throws -> TrainingCatalogResult {
        guard locale == "en" || locale == "zh-Hans" else { throw BackendError.invalidRequest }
        var plans: [TrainingPlan] = []
        var seenIDs = Set<String>()
        var seenCursors = Set<String>()
        var cursor: String?

        for _ in 0..<maximumPages {
            try Task.checkCancellation()
            var request = BackendRequest(path: "api/v1/training-plans")
            request.queryItems = [
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "limit", value: String(pageLimit))
            ]
            if let cursor { request.queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
            let page = try await client.send(request, as: RemoteTrainingPlanDTO.Page.self)
            guard page.items.count <= pageLimit else { throw BackendError.invalidResponse }
            for item in page.items {
                let plan = try item.domain(expectedLocale: locale)
                guard seenIDs.insert(plan.id).inserted else { throw BackendError.invalidResponse }
                plans.append(plan)
            }
            guard page.hasMore else {
                guard page.nextCursor == nil else { throw BackendError.invalidResponse }
                return TrainingCatalogResult(plans: plans, source: .remote)
            }
            guard let nextCursor = page.nextCursor,
                  !nextCursor.isEmpty,
                  nextCursor.count <= 4_096,
                  seenCursors.insert(nextCursor).inserted else {
                throw BackendError.invalidResponse
            }
            cursor = nextCursor
        }
        throw BackendError.invalidResponse
    }
}
