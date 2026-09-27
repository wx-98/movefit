import XCTest
@testable import MoveFit

final class RegistrationVerificationUseCaseTests: XCTestCase {
    func testRequestUseCaseNormalizesIdentifierAndBuildsChallengeContext() async throws {
        let provider = VerificationProviderSpy()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let useCase = RequestRegistrationCodeUseCase(
            provider: provider,
            installationIdentity: FixedInstallationIdentity(value: "installation-test-id"),
            dateProvider: FixedRegistrationDateProvider(now: now),
            cooldownSeconds: 60
        )

        let context = try await useCase.execute(
            kind: .email,
            identifier: " MoveFit.Tester@Example.COM "
        )

        XCTAssertEqual(provider.requestedIdentifier?.value, "movefit.tester@example.com")
        XCTAssertEqual(provider.requestedDeviceID, "installation-test-id")
        XCTAssertEqual(context.challengeID, provider.challengeID)
        XCTAssertEqual(context.cooldownUntil, now.addingTimeInterval(60))
    }

    func testCompleteUseCaseConfirmsThenRegistersWithOneTimeProof() async throws {
        let provider = VerificationProviderSpy()
        provider.proof = "one-time-proof-from-test-fake"
        let authentication = AuthenticationProviderSpy()
        let context = RegistrationChallengeContext(
            identifier: try RegistrationIdentifier(kind: .phone, rawValue: "+8613800000000"),
            challengeID: provider.challengeID,
            deviceID: "installation-test-id",
            cooldownUntil: Date(timeIntervalSince1970: 1_700_000_060)
        )
        let useCase = CompleteVerifiedRegistrationUseCase(
            verificationProvider: provider,
            authenticationProvider: authentication
        )

        let completion = try await useCase.execute(
            context: context,
            code: "123456",
            password: "fictional-password-123"
        )

        XCTAssertEqual(provider.confirmedChallengeID, provider.challengeID)
        XCTAssertEqual(provider.confirmedCode?.value, "123456")
        XCTAssertEqual(provider.confirmedDeviceID, "installation-test-id")
        XCTAssertEqual(authentication.registeredIdentifier, "+8613800000000")
        XCTAssertEqual(authentication.registeredProof, provider.proof)
        XCTAssertEqual(completion.loginIdentifier, "+8613800000000")
        XCTAssertEqual(completion.kind, .phone)
    }

    func testInvalidCodeStopsBeforeProviderCall() async throws {
        let provider = VerificationProviderSpy()
        let authentication = AuthenticationProviderSpy()
        let context = RegistrationChallengeContext(
            identifier: try RegistrationIdentifier(kind: .email, rawValue: "tester@example.com"),
            challengeID: provider.challengeID,
            deviceID: "installation-test-id",
            cooldownUntil: Date()
        )
        let useCase = CompleteVerifiedRegistrationUseCase(
            verificationProvider: provider,
            authenticationProvider: authentication
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await useCase.execute(
                context: context,
                code: "12345",
                password: "fictional-password-123"
            )
        }

        XCTAssertNil(provider.confirmedChallengeID)
        XCTAssertNil(authentication.registeredProof)
    }

    func testARegistrationRetryObtainsANewProofInsteadOfCachingThePreviousOne() async throws {
        let provider = VerificationProviderSpy()
        provider.proofs = ["first-proof", "second-proof"]
        let authentication = AuthenticationProviderSpy()
        authentication.error = RegistrationUseCaseTestError.rejected
        let context = RegistrationChallengeContext(
            identifier: try RegistrationIdentifier(kind: .email, rawValue: "tester@example.com"),
            challengeID: provider.challengeID,
            deviceID: "installation-test-id",
            cooldownUntil: Date()
        )
        let useCase = CompleteVerifiedRegistrationUseCase(
            verificationProvider: provider,
            authenticationProvider: authentication
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await useCase.execute(
                context: context,
                code: "123456",
                password: "fictional-password-123"
            )
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await useCase.execute(
                context: context,
                code: "123456",
                password: "fictional-password-123"
            )
        }

        XCTAssertEqual(provider.confirmCallCount, 2)
        XCTAssertEqual(authentication.receivedProofs, ["first-proof", "second-proof"])
    }
}

private final class VerificationProviderSpy: RegistrationVerificationProviding {
    let challengeID = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    var proof = "proof-from-test-fake"
    var proofs: [String] = []
    var requestedIdentifier: RegistrationIdentifier?
    var requestedDeviceID: String?
    var confirmedChallengeID: UUID?
    var confirmedCode: RegistrationVerificationCode?
    var confirmedDeviceID: String?
    var confirmCallCount = 0

    func requestRegistrationChallenge(
        identifier: RegistrationIdentifier,
        deviceID: String
    ) async throws -> UUID {
        requestedIdentifier = identifier
        requestedDeviceID = deviceID
        return challengeID
    }

    func confirmRegistrationChallenge(
        challengeID: UUID,
        code: RegistrationVerificationCode,
        deviceID: String
    ) async throws -> String {
        confirmedChallengeID = challengeID
        confirmedCode = code
        confirmedDeviceID = deviceID
        let result = proofs.isEmpty ? proof : proofs.removeFirst()
        confirmCallCount += 1
        return result
    }
}

private final class AuthenticationProviderSpy: AuthenticationProviding {
    var registeredIdentifier: String?
    var registeredProof: String?
    var receivedProofs: [String] = []
    var error: Error?

    func restoreSession() async throws -> AccountSession? { nil }

    func signIn(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String
    ) async throws -> AccountSession {
        throw RegistrationUseCaseTestError.unexpectedCall
    }

    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async throws {
        registeredIdentifier = identifier
        registeredProof = verificationProof
        receivedProofs.append(verificationProof)
        if let error { throw error }
    }

    func signOut(allSessions: Bool) async {}
}

private struct FixedInstallationIdentity: InstallationIdentifying {
    let value: String
    func installationID() throws -> String { value }
}

private struct FixedRegistrationDateProvider: DateProviding {
    let now: Date
}

private enum RegistrationUseCaseTestError: Error {
    case rejected
    case unexpectedCall
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected expression to throw", file: file, line: line)
        } catch {}
    }
}
