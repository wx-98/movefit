import Foundation

@MainActor
struct RegistrationViewModelFactory {
    private let makeViewModel: () -> RegistrationViewModel

    init(
        verificationProvider: RegistrationVerificationProviding,
        authenticationProvider: AuthenticationProviding,
        installationIdentity: InstallationIdentifying = KeychainInstallationIdentity(),
        dateProvider: DateProviding = SystemDateProvider(),
        uuidProvider: UUIDProviding = SystemUUIDProvider(),
        initialPassword: String? = nil
    ) {
        makeViewModel = {
            let viewModel = RegistrationViewModel(
                requestUseCase: RequestRegistrationCodeUseCase(
                    provider: verificationProvider,
                    installationIdentity: installationIdentity,
                    dateProvider: dateProvider
                ),
                completeUseCase: CompleteVerifiedRegistrationUseCase(
                    verificationProvider: verificationProvider,
                    authenticationProvider: authenticationProvider
                ),
                dateProvider: dateProvider,
                uuidProvider: uuidProvider
            )
            viewModel.password = initialPassword ?? ""
            return viewModel
        }
    }

    func make() -> RegistrationViewModel {
        makeViewModel()
    }
}

#if DEBUG
private struct UIRegistrationVerificationProvider: RegistrationVerificationProviding {
    let rateLimited: Bool

    func requestRegistrationChallenge(
        identifier: RegistrationIdentifier,
        deviceID: String
    ) async throws -> UUID {
        if rateLimited {
            throw RegistrationVerificationError.rateLimited(retryAfterSeconds: 120)
        }
        return UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
    }

    func confirmRegistrationChallenge(
        challengeID: UUID,
        code: RegistrationVerificationCode,
        deviceID: String
    ) async throws -> String {
        "ui-test-registration-proof"
    }
}

private struct UIRegistrationInstallationIdentity: InstallationIdentifying {
    func installationID() throws -> String {
        "ui-test-installation-id"
    }
}

extension RegistrationViewModelFactory {
    static func uiTesting(
        authenticationProvider: AuthenticationProviding,
        rateLimited: Bool = false
    ) -> Self {
        Self(
            verificationProvider: UIRegistrationVerificationProvider(rateLimited: rateLimited),
            authenticationProvider: authenticationProvider,
            installationIdentity: UIRegistrationInstallationIdentity(),
            initialPassword: "abcdefghijkl"
        )
    }
}
#endif
