import XCTest
@testable import MoveFit

final class RegistrationVerificationDomainTests: XCTestCase {
    func testEmailIdentifierIsTrimmedAndNormalizedWhenValid() throws {
        let identifier = try RegistrationIdentifier(
            kind: .email,
            rawValue: "  MoveFit.Tester@Example.COM  "
        )

        XCTAssertEqual(identifier.value, "movefit.tester@example.com")
    }

    func testPhoneIdentifierRequiresE164Format() {
        XCTAssertThrowsError(
            try RegistrationIdentifier(kind: .phone, rawValue: "13800000000")
        )
        XCTAssertNoThrow(
            try RegistrationIdentifier(kind: .phone, rawValue: "+8613800000000")
        )
    }

    func testVerificationCodeRequiresSixASCIIDigits() {
        XCTAssertNoThrow(try RegistrationVerificationCode("123456"))
        XCTAssertThrowsError(try RegistrationVerificationCode("12345"))
        XCTAssertThrowsError(try RegistrationVerificationCode("１２３４５６"))
        XCTAssertThrowsError(try RegistrationVerificationCode("12345a"))
    }

    func testIdentifierChangeInvalidatesExistingChallenge() throws {
        let email = try RegistrationIdentifier(kind: .email, rawValue: "first@example.com")
        let replacement = try RegistrationIdentifier(kind: .email, rawValue: "second@example.com")
        let generation = UUID()
        var state = RegistrationFlowState()
        state.startRequest(identifier: email, generation: generation)
        XCTAssertTrue(
            state.receiveChallenge(
                UUID(),
                cooldownUntil: Date(timeIntervalSince1970: 120),
                generation: generation
            )
        )

        state.changeIdentifier(to: replacement)

        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.challengeID)
        XCTAssertNil(state.activeGeneration)
    }

    func testLateChallengeResponseIsRejectedAfterNewRequest() throws {
        let identifier = try RegistrationIdentifier(kind: .email, rawValue: "tester@example.com")
        let firstGeneration = UUID()
        let currentGeneration = UUID()
        let lateChallengeID = UUID()
        var state = RegistrationFlowState()
        state.startRequest(identifier: identifier, generation: firstGeneration)
        state.startRequest(identifier: identifier, generation: currentGeneration)

        let accepted = state.receiveChallenge(
            lateChallengeID,
            cooldownUntil: Date(timeIntervalSince1970: 120),
            generation: firstGeneration
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(state.phase, .requesting)
        XCTAssertNil(state.challengeID)
        XCTAssertEqual(state.activeGeneration, currentGeneration)
    }

    func testCancellationReturnsFlowToIdle() throws {
        let identifier = try RegistrationIdentifier(kind: .phone, rawValue: "+8613800000000")
        var state = RegistrationFlowState()
        state.startRequest(identifier: identifier, generation: UUID())

        state.cancel()

        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.identifier)
        XCTAssertNil(state.challengeID)
        XCTAssertNil(state.activeGeneration)
    }
}
