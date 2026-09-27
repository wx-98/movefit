import Foundation

protocol RegistrationVerificationProviding {
    func requestRegistrationChallenge(
        identifier: RegistrationIdentifier,
        deviceID: String
    ) async throws -> UUID

    func confirmRegistrationChallenge(
        challengeID: UUID,
        code: RegistrationVerificationCode,
        deviceID: String
    ) async throws -> String
}

protocol InstallationIdentifying {
    func installationID() throws -> String
}

struct RegistrationChallengeContext: Equatable {
    let identifier: RegistrationIdentifier
    let challengeID: UUID
    let deviceID: String
    let cooldownUntil: Date
}

struct RegistrationCompletion: Equatable {
    let kind: AccountIdentifierKind
    let loginIdentifier: String
}

struct RequestRegistrationCodeUseCase {
    private let provider: RegistrationVerificationProviding
    private let installationIdentity: InstallationIdentifying
    private let dateProvider: DateProviding
    private let cooldownSeconds: TimeInterval

    init(
        provider: RegistrationVerificationProviding,
        installationIdentity: InstallationIdentifying,
        dateProvider: DateProviding,
        cooldownSeconds: TimeInterval = 60
    ) {
        self.provider = provider
        self.installationIdentity = installationIdentity
        self.dateProvider = dateProvider
        self.cooldownSeconds = cooldownSeconds
    }

    func execute(
        kind: AccountIdentifierKind,
        identifier: String
    ) async throws -> RegistrationChallengeContext {
        let normalizedIdentifier = try RegistrationIdentifier(kind: kind, rawValue: identifier)
        let deviceID = try installationIdentity.installationID()
        guard !deviceID.isEmpty, deviceID.count <= 255 else {
            throw RegistrationInputError.invalidInstallationIdentity
        }
        let challengeID = try await provider.requestRegistrationChallenge(
            identifier: normalizedIdentifier,
            deviceID: deviceID
        )
        return RegistrationChallengeContext(
            identifier: normalizedIdentifier,
            challengeID: challengeID,
            deviceID: deviceID,
            cooldownUntil: dateProvider.now.addingTimeInterval(cooldownSeconds)
        )
    }
}

struct CompleteVerifiedRegistrationUseCase {
    private let verificationProvider: RegistrationVerificationProviding
    private let authenticationProvider: AuthenticationProviding

    init(
        verificationProvider: RegistrationVerificationProviding,
        authenticationProvider: AuthenticationProviding
    ) {
        self.verificationProvider = verificationProvider
        self.authenticationProvider = authenticationProvider
    }

    func execute(
        context: RegistrationChallengeContext,
        code: String,
        password: String,
        onProofConfirmed: (() async -> Void)? = nil
    ) async throws -> RegistrationCompletion {
        let verificationCode = try RegistrationVerificationCode(code)
        let validatedPassword = try RegistrationPassword(password)
        let proof = try await verificationProvider.confirmRegistrationChallenge(
            challengeID: context.challengeID,
            code: verificationCode,
            deviceID: context.deviceID
        )
        guard !proof.isEmpty else {
            throw RegistrationInputError.invalidVerificationProof
        }
        await onProofConfirmed?()
        try await authenticationProvider.register(
            kind: context.identifier.kind,
            identifier: context.identifier.value,
            password: validatedPassword.value,
            verificationProof: proof
        )
        return RegistrationCompletion(
            kind: context.identifier.kind,
            loginIdentifier: context.identifier.value
        )
    }
}
