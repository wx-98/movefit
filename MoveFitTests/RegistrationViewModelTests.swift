import XCTest
@testable import MoveFit

@MainActor
final class RegistrationViewModelTests: XCTestCase {
    func testRequestCodeEntersCodeEntryWithAbsoluteCooldown() async {
        let context = makeContext()
        context.dateProvider.now = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = context.makeViewModel()
        viewModel.kind = .email
        viewModel.identifier = " Tester@Example.COM "
        viewModel.password = "fictional-password-123"

        await viewModel.requestCode()

        XCTAssertEqual(
            viewModel.phase,
            .codeEntry(cooldownUntil: context.dateProvider.now.addingTimeInterval(60))
        )
        XCTAssertEqual(context.verification.requestCallCount, 1)
        XCTAssertEqual(context.verification.requestedIdentifier?.value, "tester@example.com")
    }

    func testDoubleTapDoesNotCreateConcurrentChallengeRequests() async {
        let context = makeContext()
        context.verification.shouldSuspendRequest = true
        let viewModel = context.makeViewModel()
        viewModel.identifier = "tester@example.com"
        viewModel.password = "fictional-password-123"

        let first = Task { await viewModel.requestCode() }
        await waitUntil { context.verification.requestContinuation != nil }
        await viewModel.requestCode()
        context.verification.resumeRequest()
        await first.value

        XCTAssertEqual(context.verification.requestCallCount, 1)
        guard case .codeEntry = viewModel.phase else {
            return XCTFail("Expected code entry phase")
        }
    }

    func testCancellationRejectsLateChallengeResponseAndClearsSensitiveFields() async {
        let context = makeContext()
        context.verification.shouldSuspendRequest = true
        let viewModel = context.makeViewModel()
        viewModel.identifier = "tester@example.com"
        viewModel.password = "fictional-password-123"
        viewModel.code = "123456"

        let request = Task { await viewModel.requestCode() }
        await waitUntil { context.verification.requestContinuation != nil }
        viewModel.cancel()
        context.verification.resumeRequest()
        await request.value

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertTrue(viewModel.password.isEmpty)
        XCTAssertTrue(viewModel.code.isEmpty)
        XCTAssertNil(viewModel.challengeContext)
    }

    func testIdentifierChangeInvalidatesChallengeAndCancelsCurrentFlow() async {
        let context = makeContext()
        let viewModel = context.makeViewModel()
        viewModel.identifier = "first@example.com"
        viewModel.password = "fictional-password-123"
        await viewModel.requestCode()
        guard case .codeEntry = viewModel.phase else {
            return XCTFail("Expected code entry phase")
        }

        viewModel.identifier = "second@example.com"

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertNil(viewModel.challengeContext)
        XCTAssertTrue(viewModel.code.isEmpty)
        XCTAssertTrue(viewModel.password.isEmpty)
    }

    func testSuccessfulConfirmationRegistersAndClearsSecrets() async {
        let context = makeContext()
        let viewModel = context.makeViewModel()
        viewModel.kind = .phone
        viewModel.identifier = "+8613800000000"
        viewModel.password = "fictional-password-123"
        await viewModel.requestCode()
        viewModel.code = "123456"

        await viewModel.completeRegistration()

        XCTAssertEqual(viewModel.phase, .completed)
        XCTAssertEqual(viewModel.completion?.loginIdentifier, "+8613800000000")
        XCTAssertEqual(context.authentication.registeredProof, context.verification.proof)
        XCTAssertTrue(viewModel.code.isEmpty)
        XCTAssertTrue(viewModel.password.isEmpty)
        XCTAssertNil(viewModel.challengeContext)
    }

    func testConfirmationExposesRegisteringPhaseWithoutExposingProof() async {
        let context = makeContext()
        context.authentication.shouldSuspendRegistration = true
        let viewModel = context.makeViewModel()
        viewModel.identifier = "tester@example.com"
        viewModel.password = "fictional-password-123"
        await viewModel.requestCode()
        viewModel.code = "123456"

        let completion = Task { await viewModel.completeRegistration() }
        await waitUntil { context.authentication.registrationContinuation != nil }

        XCTAssertEqual(viewModel.phase, .registering)
        XCTAssertNil(viewModel.completion)
        context.authentication.resumeRegistration()
        await completion.value
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func testInvalidSixCharacterCodeKeepsChallengeAndShowsValidationMessage() async {
        let context = makeContext()
        let viewModel = context.makeViewModel()
        viewModel.identifier = "tester@example.com"
        viewModel.password = "fictional-password-123"
        await viewModel.requestCode()
        viewModel.code = "abcdef"

        await viewModel.completeRegistration()

        guard case .codeEntry = viewModel.phase else {
            return XCTFail("Invalid local code must keep the active challenge")
        }
        XCTAssertNotNil(viewModel.challengeContext)
        XCTAssertEqual(context.verification.confirmCallCount, 0)
        XCTAssertEqual(viewModel.message, "请输入六位数字验证码。")
    }

    func testResendIsBlockedUntilCooldownExpires() async {
        let context = makeContext()
        context.dateProvider.now = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = context.makeViewModel()
        viewModel.identifier = "tester@example.com"
        viewModel.password = "fictional-password-123"

        await viewModel.requestCode()
        await viewModel.requestCode()
        XCTAssertEqual(context.verification.requestCallCount, 1)

        context.dateProvider.now = context.dateProvider.now.addingTimeInterval(61)
        await viewModel.requestCode()
        XCTAssertEqual(context.verification.requestCallCount, 2)
    }

    func testRateLimitCooldownUsesAbsoluteTimeAndRecomputesAfterResume() async {
        let context = makeContext()
        context.dateProvider.now = Date(timeIntervalSince1970: 1_700_000_000)
        context.verification.requestError = RegistrationVerificationError.rateLimited(
            retryAfterSeconds: 120
        )
        let viewModel = context.makeViewModel()
        viewModel.identifier = "tester@example.com"
        viewModel.password = "fictional-password-123"

        await viewModel.requestCode()

        XCTAssertEqual(
            viewModel.remainingCooldownSeconds(
                at: context.dateProvider.now.addingTimeInterval(30)
            ),
            90
        )
        XCTAssertEqual(
            viewModel.remainingCooldownSeconds(
                at: context.dateProvider.now.addingTimeInterval(121)
            ),
            0
        )
    }

    private func makeContext() -> RegistrationViewModelTestContext {
        RegistrationViewModelTestContext()
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }
}

@MainActor
private final class RegistrationViewModelTestContext {
    let verification = RegistrationVerificationProviderFake()
    let authentication = RegistrationAuthenticationProviderFake()
    let dateProvider = MutableRegistrationDateProvider()

    func makeViewModel() -> RegistrationViewModel {
        RegistrationViewModel(
            requestUseCase: RequestRegistrationCodeUseCase(
                provider: verification,
                installationIdentity: RegistrationInstallationIdentityFake(),
                dateProvider: dateProvider,
                cooldownSeconds: 60
            ),
            completeUseCase: CompleteVerifiedRegistrationUseCase(
                verificationProvider: verification,
                authenticationProvider: authentication
            ),
            dateProvider: dateProvider,
            uuidProvider: SystemUUIDProvider()
        )
    }
}

private final class RegistrationVerificationProviderFake: RegistrationVerificationProviding {
    let challengeID = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
    var proof = "proof-from-view-model-test"
    var requestError: Error?
    var confirmError: Error?
    var shouldSuspendRequest = false
    var requestContinuation: CheckedContinuation<UUID, Error>?
    private(set) var requestCallCount = 0
    private(set) var confirmCallCount = 0
    private(set) var requestedIdentifier: RegistrationIdentifier?

    func requestRegistrationChallenge(
        identifier: RegistrationIdentifier,
        deviceID: String
    ) async throws -> UUID {
        requestCallCount += 1
        requestedIdentifier = identifier
        if let requestError { throw requestError }
        if shouldSuspendRequest {
            return try await withCheckedThrowingContinuation { continuation in
                requestContinuation = continuation
            }
        }
        return challengeID
    }

    func confirmRegistrationChallenge(
        challengeID: UUID,
        code: RegistrationVerificationCode,
        deviceID: String
    ) async throws -> String {
        confirmCallCount += 1
        if let confirmError { throw confirmError }
        return proof
    }

    func resumeRequest() {
        requestContinuation?.resume(returning: challengeID)
        requestContinuation = nil
    }
}

private final class RegistrationAuthenticationProviderFake: AuthenticationProviding {
    private(set) var registeredProof: String?
    var shouldSuspendRegistration = false
    var registrationContinuation: CheckedContinuation<Void, Never>?

    func restoreSession() async throws -> AccountSession? { nil }
    func signIn(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String
    ) async throws -> AccountSession {
        throw RegistrationViewModelTestError.unexpectedCall
    }

    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async throws {
        registeredProof = verificationProof
        if shouldSuspendRegistration {
            await withCheckedContinuation { continuation in
                registrationContinuation = continuation
            }
        }
    }

    func signOut(allSessions: Bool) async {}

    func resumeRegistration() {
        registrationContinuation?.resume()
        registrationContinuation = nil
    }
}

private final class MutableRegistrationDateProvider: DateProviding {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
}

private struct RegistrationInstallationIdentityFake: InstallationIdentifying {
    func installationID() throws -> String { "installation-view-model-test" }
}

private enum RegistrationViewModelTestError: Error {
    case unexpectedCall
}
