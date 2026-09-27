import Foundation

private struct PasswordLoginRequestDTO: Encodable {
    let identifierKind: String
    let identifier: String
    let password: String
}

private struct RegisterPasswordRequestDTO: Encodable {
    let identifierKind: String
    let identifier: String
    let password: String
    let verificationProof: String
}

private struct RegistrationChallengeRequestDTO: Encodable {
    let identifier: String
    let channel: String
    let deviceID: String
}

private struct RegistrationChallengeResponseDTO: Decodable {
    let challengeID: UUID

    private enum CodingKeys: String, CodingKey {
        case challengeID = "challengeId"
    }
}

private struct RegistrationChallengeConfirmRequestDTO: Encodable {
    let code: String
    let deviceID: String
}

private struct RegistrationChallengeConfirmResponseDTO: Decodable {
    let verificationProof: String
}

private struct RegisteredAccountResponseDTO: Decodable {
    let userID: UUID
    let identifierKind: String

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case identifierKind
    }
}

private struct ProfileResponseDTO: Decodable {
    let nickname: String?
    let currentHeightCentimeters: Double?
    let currentWeightKilograms: Double?
    let currentBodyFatPercentage: Double?
    let version: Int
}

private struct ProfilePatchRequestDTO: Encodable {
    let baseVersion: Int
    let nickname: String
    let currentHeightCentimeters: Double
    let currentWeightKilograms: Double
    let currentBodyFatPercentage: Double
}

private struct WorkoutListResponseDTO: Decodable {
    let items: [WorkoutResponseDTO]
    let nextCursor: String?
    let hasMore: Bool
}

private struct WorkoutResponseDTO: Decodable {
    let id: UUID
    let type: String
    let source: String
    let startedAt: String
    let durationSeconds: Int
    let distanceMeters: Double?
    let energyKilocalories: Double?
    let deletedAt: String?
}

private struct WorkoutCreateRequestDTO: Encodable {
    let workoutID: UUID
    let type: String
    let source: String
    let startedAt: String
    let endedAt: String
    let durationSeconds: Int
    let distanceMeters: Double?
    let energyKilocalories: Double?
    let averageHeartRateBpm: Double?
    let deviceTimezone: String
}

private struct ClientConfigResponseDTO: Decodable {
    struct Config: Decodable {
        let featureEnabled: Bool?
        let syncIntervalSeconds: Int?
    }

    let schemaVersion: String
    let revision: Int
    let config: Config
}

struct BackendRepository: AuthenticationProviding, RegistrationVerificationProviding,
    RemoteProfileProviding, RemoteWorkoutProviding, ClientConfigurationProviding {
    let client: MoveFitAPIClient
    let uuidProvider: UUIDProviding
    private let timeZone: TimeZone

    init(
        client: MoveFitAPIClient,
        uuidProvider: UUIDProviding = SystemUUIDProvider(),
        timeZone: TimeZone = .current
    ) {
        self.client = client
        self.uuidProvider = uuidProvider
        self.timeZone = timeZone
    }

    func restoreSession() async throws -> AccountSession? {
        guard let session = try await client.storedSession() else { return nil }
        guard let method = session.socialProvider?.authenticationMethod
            ?? session.identifierKind?.authenticationMethod else {
            throw BackendError.invalidSession
        }
        return AccountSession(
            id: session.sessionID,
            displayName: session.identifier,
            method: method,
            isLocalSimulation: false
        )
    }

    func signIn(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String
    ) async throws -> AccountSession {
        let cleanedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedIdentifier.isEmpty, !password.isEmpty else { throw BackendError.invalidRequest }
        let body = try await client.encode(
            PasswordLoginRequestDTO(
                identifierKind: kind.rawValue,
                identifier: cleanedIdentifier,
                password: password
            )
        )
        let data = try await client.sendForSession(
            BackendRequest(path: "api/v1/auth/login/password", method: .post, body: body)
        )
        let sessionID = uuidProvider.make()
        try await client.storeSession(
            tokenResponseData: data,
            kind: kind,
            identifier: cleanedIdentifier,
            sessionID: sessionID
        )
        return AccountSession(
            id: sessionID,
            displayName: cleanedIdentifier,
            method: kind.authenticationMethod,
            isLocalSimulation: false
        )
    }

    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async throws {
        let body = try await client.encode(
            RegisterPasswordRequestDTO(
                identifierKind: kind.rawValue,
                identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                verificationProof: verificationProof.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        let request = BackendRequest(path: "api/v1/auth/register", method: .post, body: body)
        do {
            _ = try await client.send(request, as: RegisteredAccountResponseDTO.self)
        } catch {
            throw mapRegistrationError(error)
        }
    }

    func requestRegistrationChallenge(
        identifier: RegistrationIdentifier,
        deviceID: String
    ) async throws -> UUID {
        guard !deviceID.isEmpty, deviceID.count <= 255 else {
            throw BackendError.invalidRequest
        }
        let body = try await client.encode(
            RegistrationChallengeRequestDTO(
                identifier: identifier.value,
                channel: identifier.kind.rawValue,
                deviceID: deviceID
            )
        )
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/auth/verification-challenges",
                    method: .post,
                    body: body
                ),
                as: RegistrationChallengeResponseDTO.self
            )
            return response.challengeID
        } catch {
            throw mapRegistrationError(error)
        }
    }

    func confirmRegistrationChallenge(
        challengeID: UUID,
        code: RegistrationVerificationCode,
        deviceID: String
    ) async throws -> String {
        guard !deviceID.isEmpty, deviceID.count <= 255 else {
            throw BackendError.invalidRequest
        }
        let body = try await client.encode(
            RegistrationChallengeConfirmRequestDTO(
                code: code.value,
                deviceID: deviceID
            )
        )
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/auth/verification-challenges/\(challengeID.uuidString)/verify",
                    method: .post,
                    body: body
                ),
                as: RegistrationChallengeConfirmResponseDTO.self
            )
            guard !response.verificationProof.isEmpty else {
                throw BackendError.invalidResponse
            }
            return response.verificationProof
        } catch {
            throw mapRegistrationError(error)
        }
    }

    func signOut(allSessions: Bool) async {
        let path = allSessions ? "api/v1/auth/logout-all" : "api/v1/auth/logout"
        let request = BackendRequest(path: path, method: .post, requiresAuthentication: true)
        do {
            try await client.sendWithoutResponse(request)
        } catch {
            // 本地凭据必须清除；远程撤销失败会由令牌过期机制最终收敛。
        }
        await client.clearSession()
    }

    func currentProfile() async throws -> RemoteProfileSnapshot {
        let request = BackendRequest(path: "api/v1/me", requiresAuthentication: true)
        let response = try await client.send(request, as: ProfileResponseDTO.self)
        return mapProfile(response)
    }

    func updateProfile(
        _ profile: UserProfile,
        baseVersion: Int,
        operationID: UUID
    ) async throws -> RemoteProfileSnapshot {
        let body = try await client.encode(
            ProfilePatchRequestDTO(
                baseVersion: baseVersion,
                nickname: profile.nickname,
                currentHeightCentimeters: profile.height.converted(to: .centimeters).value,
                currentWeightKilograms: profile.weight.converted(to: .kilograms).value,
                currentBodyFatPercentage: profile.bodyFatPercentage
            )
        )
        let request = BackendRequest(
            path: "api/v1/me/profile",
            method: .patch,
            body: body,
            requiresAuthentication: true,
            idempotencyKey: operationID
        )
        let response = try await client.send(request, as: ProfileResponseDTO.self)
        return mapProfile(response)
    }

    func workouts() async throws -> [WorkoutRecord] {
        var cursor: String?
        var records: [WorkoutRecord] = []
        repeat {
            var queryItems = [URLQueryItem(name: "limit", value: "100")]
            if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
            let request = BackendRequest(
                path: "api/v1/workouts",
                queryItems: queryItems,
                requiresAuthentication: true
            )
            let response = try await client.send(request, as: WorkoutListResponseDTO.self)
            records.append(contentsOf: try response.items.compactMap(mapWorkout))
            cursor = response.hasMore ? response.nextCursor : nil
        } while cursor != nil
        return records
    }

    func upload(
        _ workout: WorkoutRecord,
        source: RemoteWorkoutSource,
        operationID: UUID
    ) async throws {
        guard let type = backendWorkoutType(workout.type) else { throw BackendError.unsupportedWorkoutType }
        let duration = max(1, Int(workout.duration.rounded()))
        let body = try await client.encode(
            WorkoutCreateRequestDTO(
                workoutID: workout.id,
                type: type,
                source: source.rawValue,
                startedAt: BackendDateParser.string(from: workout.startedAt),
                endedAt: BackendDateParser.string(from: workout.startedAt.addingTimeInterval(workout.duration)),
                durationSeconds: duration,
                distanceMeters: workout.distance?.converted(to: .meters).value,
                energyKilocalories: workout.energy?.converted(to: .kilocalories).value,
                averageHeartRateBpm: nil,
                deviceTimezone: timeZone.identifier
            )
        )
        let request = BackendRequest(
            path: "api/v1/workouts",
            method: .post,
            body: body,
            requiresAuthentication: true,
            idempotencyKey: operationID
        )
        _ = try await client.send(request, as: WorkoutResponseDTO.self)
    }

    func configuration(appVersion: String) async throws -> BackendClientConfiguration {
        let request = BackendRequest(
            path: "api/v1/client-config",
            queryItems: [
                URLQueryItem(name: "platform", value: "ios"),
                URLQueryItem(name: "app_version", value: appVersion)
            ]
        )
        let response = try await client.send(request, as: ClientConfigResponseDTO.self)
        return BackendClientConfiguration(
            schemaVersion: response.schemaVersion,
            revision: response.revision,
            featureEnabled: response.config.featureEnabled,
            syncIntervalSeconds: response.config.syncIntervalSeconds
        )
    }

    private func mapProfile(_ response: ProfileResponseDTO) -> RemoteProfileSnapshot {
        RemoteProfileSnapshot(
            nickname: response.nickname,
            height: response.currentHeightCentimeters.map { Measurement(value: $0, unit: .centimeters) },
            weight: response.currentWeightKilograms.map { Measurement(value: $0, unit: .kilograms) },
            bodyFatPercentage: response.currentBodyFatPercentage,
            version: response.version
        )
    }

    private func mapRegistrationError(_ error: Error) -> Error {
        guard let backendError = error as? BackendError else { return error }
        guard case let .server(status, code, _, retryAfterSeconds) = backendError else {
            return backendError
        }
        switch code {
        case "verification_delivery_unavailable", "verification_provider_unavailable":
            return RegistrationVerificationError.deliveryUnavailable
        case "verification_code_invalid":
            return RegistrationVerificationError.invalidCode
        case "registration_verification_invalid":
            return RegistrationVerificationError.invalidProof
        case "auth_rate_limited" where status == 429:
            return RegistrationVerificationError.rateLimited(
                retryAfterSeconds: retryAfterSeconds ?? 60
            )
        default:
            return backendError
        }
    }

    private func mapWorkout(_ response: WorkoutResponseDTO) throws -> WorkoutRecord? {
        guard response.deletedAt == nil else { return nil }
        guard let type = workoutType(response.type),
              let startedAt = BackendDateParser.date(from: response.startedAt) else {
            throw BackendError.invalidResponse
        }
        let source: WorkoutDataSource = response.source == "healthkit_import" ? .appleHealth : .moveFit
        return WorkoutRecord(
            id: response.id,
            type: type,
            startedAt: startedAt,
            duration: TimeInterval(response.durationSeconds),
            distance: response.distanceMeters.map { Measurement(value: $0, unit: .meters) },
            energy: response.energyKilocalories.map { Measurement(value: $0, unit: .kilocalories) },
            route: [],
            source: source
        )
    }

    private func backendWorkoutType(_ type: WorkoutType) -> String? {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .yoga: return "yoga"
        case .strength: return "strength"
        case .hiit: return "hiit"
        default: return nil
        }
    }

    private func workoutType(_ value: String) -> WorkoutType? {
        switch value {
        case "running": return .running
        case "walking": return .walking
        case "cycling": return .cycling
        case "yoga": return .yoga
        case "strength": return .strength
        case "hiit": return .hiit
        default: return nil
        }
    }
}
