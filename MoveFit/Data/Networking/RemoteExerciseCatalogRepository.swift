import Foundation

private struct RemoteExerciseCatalogResponseDTO: Decodable {
    let catalogVersion: String
    let page: Int
    let pageSize: Int
    let hasMore: Bool
    let items: [RemoteExerciseDTO]
}

private struct RemoteExerciseDTO: Decodable {
    let id: String
    let nameZhHans: String
    let originalName: String
    let difficulty: String
    let equipment: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructionsZhHans: [String]
    let safetyNotesZhHans: [String]
    let images: [String]?
}

struct RemoteExerciseCatalogRepository: ExerciseCatalogProviding {
    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func exercises(query: ExerciseCatalogQuery, page: Int, pageSize: Int) async throws -> ExerciseCatalogPage {
        let endpoint = baseURL.appendingPathComponent("v1/exercises")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidRequest
        }
        var queryItems = [
            URLQueryItem(name: "page", value: String(max(0, page))),
            URLQueryItem(name: "page_size", value: String(min(max(1, pageSize), 100)))
        ]
        if !query.text.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query.text)) }
        if let equipment = query.equipment { queryItems.append(URLQueryItem(name: "equipment", value: equipment)) }
        if let muscle = query.muscle { queryItems.append(URLQueryItem(name: "muscle", value: muscle)) }
        if let difficulty = query.difficulty {
            queryItems.append(URLQueryItem(name: "difficulty", value: difficulty.backendValue))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw BackendError.invalidRequest }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw BackendError.networkUnavailable
        }
        guard let httpResponse = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BackendError.server(
                status: httpResponse.statusCode,
                code: nil,
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                retryAfterSeconds: nil
            )
        }
        let dto: RemoteExerciseCatalogResponseDTO
        do {
            dto = try JSONDecoder().decode(RemoteExerciseCatalogResponseDTO.self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
        let mapped = try dto.items.map { item -> Exercise in
            guard let difficulty = TrainingDifficulty(backendValue: item.difficulty) else {
                throw BackendError.invalidResponse
            }
            return Exercise(
                id: item.id,
                name: item.nameZhHans,
                originalName: item.originalName,
                difficulty: difficulty,
                equipment: item.equipment,
                primaryMuscles: item.primaryMuscles,
                secondaryMuscles: item.secondaryMuscles,
                instructions: item.instructionsZhHans,
                safetyNotes: item.safetyNotesZhHans,
                sourceVersion: dto.catalogVersion,
                imageURLs: (item.images ?? []).compactMap(URL.init(string:))
            )
        }
        return ExerciseCatalogPage(
            exercises: mapped,
            sourceVersion: dto.catalogVersion,
            hasMore: dto.hasMore,
            source: .remote
        )
    }
}

struct FallbackExerciseCatalogRepository: ExerciseCatalogProviding {
    private let remote: ExerciseCatalogProviding
    private let fallback: ExerciseCatalogProviding

    init(remote: ExerciseCatalogProviding, fallback: ExerciseCatalogProviding = BundledExerciseCatalog()) {
        self.remote = remote
        self.fallback = fallback
    }

    func exercises(query: ExerciseCatalogQuery, page: Int, pageSize: Int) async throws -> ExerciseCatalogPage {
        do {
            return try await remote.exercises(query: query, page: page, pageSize: pageSize)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let page = try await fallback.exercises(query: query, page: page, pageSize: pageSize)
            return ExerciseCatalogPage(
                exercises: page.exercises,
                sourceVersion: page.sourceVersion,
                hasMore: page.hasMore,
                source: .bundledFallback(message: error.localizedDescription)
            )
        }
    }
}

private extension TrainingDifficulty {
    init?(backendValue: String) {
        switch backendValue {
        case "beginner": self = .beginner
        case "intermediate": self = .intermediate
        case "advanced": self = .advanced
        default: return nil
        }
    }

    var backendValue: String {
        switch self {
        case .beginner: return "beginner"
        case .intermediate: return "intermediate"
        case .advanced: return "advanced"
        }
    }
}
