import Foundation

extension BackendRepository: SocialIdentityProviding {
    func signIn(
        provider: SocialProvider,
        authorization: SocialAuthorization
    ) async throws -> AccountSession {
        guard provider != .google else { throw RemoteServiceError.invalidRequest }
        let body = try await socialAuthorizationBody(authorization, provider: provider)
        do {
            let data = try await client.sendForSession(
                BackendRequest(path: "api/v1/auth/login/\(provider.rawValue)", method: .post, body: body)
            )
            let sessionID = uuidProvider.make()
            try await client.storeSocialSession(
                tokenResponseData: data,
                provider: provider,
                sessionID: sessionID
            )
            return AccountSession(
                id: sessionID,
                displayName: provider.authenticationMethod.rawValue,
                method: provider.authenticationMethod,
                isLocalSimulation: false
            )
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func beginGoogleAuthorization(
        redirectURI: URL,
        codeChallenge: String,
        deviceID: String
    ) async throws -> GoogleAuthorizationHandoff {
        guard (43...128).contains(codeChallenge.count),
              !deviceID.isEmpty, deviceID.count <= 191,
              !redirectURI.absoluteString.isEmpty else {
            throw RemoteServiceError.invalidRequest
        }
        let body = try await client.encode(
            SocialIdentityDTO.GoogleHandoffRequest(
                redirectURI: redirectURI.absoluteString,
                codeChallenge: codeChallenge,
                deviceID: deviceID
            )
        )
        do {
            let response = try await client.send(
                BackendRequest(path: "api/v1/auth/login/google/authorization", method: .post, body: body),
                as: SocialIdentityDTO.GoogleHandoff.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func completeGoogleSignIn(_ completion: GoogleAuthorizationCompletion) async throws -> AccountSession {
        let body = try await googleCompletionBody(completion)
        do {
            let data = try await client.sendForSession(
                BackendRequest(path: "api/v1/auth/login/google", method: .post, body: body)
            )
            let sessionID = uuidProvider.make()
            try await client.storeSocialSession(
                tokenResponseData: data,
                provider: .google,
                sessionID: sessionID
            )
            return AccountSession(
                id: sessionID,
                displayName: SocialProvider.google.authenticationMethod.rawValue,
                method: .google,
                isLocalSimulation: false
            )
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func identities() async throws -> [SocialIdentity] {
        do {
            let response = try await client.send(
                BackendRequest(path: "api/v1/auth/identities", requiresAuthentication: true),
                as: SocialIdentityDTO.List.self
            )
            return try response.items.map { try $0.domain() }
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func link(
        provider: SocialProvider,
        authorization: SocialAuthorization,
        operationID: UUID
    ) async throws -> SocialIdentity {
        guard provider != .google else { throw RemoteServiceError.invalidRequest }
        let body = try await socialAuthorizationBody(authorization, provider: provider)
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/auth/identities/\(provider.rawValue)/link",
                    method: .post,
                    body: body,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                ),
                as: SocialIdentityDTO.Item.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func linkGoogle(
        _ completion: GoogleAuthorizationCompletion,
        operationID: UUID
    ) async throws -> SocialIdentity {
        let body = try await googleCompletionBody(completion)
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/auth/identities/google/link",
                    method: .post,
                    body: body,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                ),
                as: SocialIdentityDTO.Item.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func unlink(provider: SocialProvider, operationID: UUID) async throws {
        do {
            try await client.sendWithoutResponse(
                BackendRequest(
                    path: "api/v1/auth/identities/\(provider.rawValue)",
                    method: .delete,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                )
            )
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    private func socialAuthorizationBody(
        _ authorization: SocialAuthorization,
        provider: SocialProvider
    ) async throws -> Data {
        guard !authorization.authorizationCode.isEmpty,
              authorization.authorizationCode.count <= 2_048,
              !authorization.deviceID.isEmpty,
              authorization.deviceID.count <= 191,
              provider != .apple || !(authorization.nonce?.isEmpty ?? true) else {
            throw RemoteServiceError.invalidRequest
        }
        return try await client.encode(
            SocialIdentityDTO.AuthorizationRequest(
                authorizationCode: authorization.authorizationCode,
                nonce: authorization.nonce,
                deviceID: authorization.deviceID
            )
        )
    }

    private func googleCompletionBody(_ completion: GoogleAuthorizationCompletion) async throws -> Data {
        guard !completion.authorizationCode.isEmpty,
              !completion.state.isEmpty,
              (43...128).contains(completion.codeVerifier.count),
              !completion.deviceID.isEmpty,
              completion.deviceID.count <= 191 else {
            throw RemoteServiceError.invalidRequest
        }
        return try await client.encode(
            SocialIdentityDTO.GoogleCompletionRequest(
                authorizationCode: completion.authorizationCode,
                state: completion.state,
                codeVerifier: completion.codeVerifier,
                redirectURI: completion.redirectURI.absoluteString,
                deviceID: completion.deviceID
            )
        )
    }
}
