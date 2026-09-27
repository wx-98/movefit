import Combine
import Foundation

@MainActor
final class RegistrationViewModel: ObservableObject {
    @Published var kind = AccountIdentifierKind.email {
        didSet {
            guard kind != oldValue else { return }
            identifierDidChange()
        }
    }

    @Published var identifier = "" {
        didSet {
            guard identifier != oldValue else { return }
            identifierDidChange()
        }
    }

    @Published var password = ""
    @Published var code = ""
    @Published private(set) var phase = RegistrationFlowPhase.idle
    @Published private(set) var message: String?
    @Published private(set) var completion: RegistrationCompletion?
    @Published private(set) var challengeContext: RegistrationChallengeContext?
    @Published private(set) var cooldownUntil: Date?

    private let requestUseCase: RequestRegistrationCodeUseCase
    private let completeUseCase: CompleteVerifiedRegistrationUseCase
    private let dateProvider: DateProviding
    private let uuidProvider: UUIDProviding
    private var flowState = RegistrationFlowState()
    private var requestTask: Task<RegistrationChallengeContext, Error>?
    private var completionTask: Task<RegistrationCompletion, Error>?
    private var isResettingInput = false

    init(
        requestUseCase: RequestRegistrationCodeUseCase,
        completeUseCase: CompleteVerifiedRegistrationUseCase,
        dateProvider: DateProviding,
        uuidProvider: UUIDProviding
    ) {
        self.requestUseCase = requestUseCase
        self.completeUseCase = completeUseCase
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
    }

    var isBusy: Bool {
        switch phase {
        case .requesting, .confirming, .registering:
            return true
        case .idle, .codeEntry, .completed:
            return false
        }
    }

    func requestCode() async {
        guard !isBusy, remainingCooldownSeconds(at: dateProvider.now) == 0 else { return }
        let normalizedIdentifier: RegistrationIdentifier
        do {
            normalizedIdentifier = try RegistrationIdentifier(kind: kind, rawValue: identifier)
            _ = try RegistrationPassword(password)
        } catch RegistrationInputError.invalidPassword {
            message = "密码需 12–128 个字符。"
            return
        } catch {
            message = "请输入有效的邮箱或含国家码的手机号。"
            return
        }

        let generation = uuidProvider.make()
        flowState.startRequest(identifier: normalizedIdentifier, generation: generation)
        publishPhase()
        message = nil
        completion = nil

        let useCase = requestUseCase
        let submittedKind = kind
        let submittedIdentifier = identifier
        let task = Task {
            try await useCase.execute(kind: submittedKind, identifier: submittedIdentifier)
        }
        requestTask = task
        defer {
            if flowState.activeGeneration == generation {
                requestTask = nil
            }
        }

        do {
            let context = try await task.value
            guard flowState.activeGeneration == generation else { return }
            challengeContext = context
            cooldownUntil = context.cooldownUntil
            _ = flowState.receiveChallenge(
                context.challengeID,
                cooldownUntil: context.cooldownUntil,
                generation: generation
            )
            publishPhase()
            message = "验证码已请求，请检查对应的邮箱或手机号。"
        } catch is CancellationError {
            resetFlow(clearIdentifier: false)
        } catch {
            guard flowState.activeGeneration == generation else { return }
            applyRequestError(error)
        }
    }

    func completeRegistration() async {
        guard !isBusy,
              let context = challengeContext,
              let generation = flowState.activeGeneration,
              flowState.beginConfirmation(generation: generation) else {
            return
        }
        publishPhase()
        message = nil

        let useCase = completeUseCase
        let submittedCode = code
        let submittedPassword = password
        let task = Task { [weak self] in
            try await useCase.execute(
                context: context,
                code: submittedCode,
                password: submittedPassword,
                onProofConfirmed: { [weak self] in
                    await MainActor.run {
                        self?.markRegistering(generation: generation)
                    }
                }
            )
        }
        completionTask = task
        defer {
            if flowState.activeGeneration == generation {
                completionTask = nil
            }
        }

        do {
            let result = try await task.value
            guard flowState.activeGeneration == generation else { return }
            guard flowState.complete(generation: generation) else { return }
            completion = result
            challengeContext = nil
            cooldownUntil = nil
            clearSecrets()
            publishPhase()
            message = "注册成功，请使用新账号登录。"
        } catch is CancellationError {
            resetFlow(clearIdentifier: false)
        } catch {
            guard flowState.activeGeneration == generation else { return }
            applyCompletionError(error, context: context, generation: generation)
        }
    }

    func remainingCooldownSeconds(at date: Date) -> Int {
        guard let cooldownUntil else { return 0 }
        return max(0, Int(ceil(cooldownUntil.timeIntervalSince(date))))
    }

    func cancel() {
        requestTask?.cancel()
        completionTask?.cancel()
        requestTask = nil
        completionTask = nil
        resetFlow(clearIdentifier: true)
    }

    func prepareForAnotherRegistration() {
        resetFlow(clearIdentifier: false)
        completion = nil
        message = nil
    }

    private func markRegistering(generation: UUID) {
        guard flowState.beginRegistration(generation: generation) else { return }
        publishPhase()
    }

    private func identifierDidChange() {
        guard !isResettingInput,
              phase != .idle,
              phase != .completed else {
            return
        }
        let current = try? RegistrationIdentifier(kind: kind, rawValue: identifier)
        guard current != flowState.identifier else { return }
        requestTask?.cancel()
        completionTask?.cancel()
        resetFlow(clearIdentifier: false)
    }

    private func applyRequestError(_ error: Error) {
        flowState.cancel()
        challengeContext = nil
        code = ""
        if case let RegistrationVerificationError.rateLimited(seconds) = error {
            cooldownUntil = dateProvider.now.addingTimeInterval(TimeInterval(seconds))
        } else {
            cooldownUntil = nil
        }
        publishPhase()
        message = userMessage(for: error)
    }

    private func applyCompletionError(
        _ error: Error,
        context: RegistrationChallengeContext,
        generation: UUID
    ) {
        code = ""
        switch error {
        case RegistrationVerificationError.invalidCode:
            _ = flowState.returnToCodeEntry(
                cooldownUntil: context.cooldownUntil,
                generation: generation
            )
        case RegistrationInputError.invalidVerificationCode,
             RegistrationInputError.invalidPassword:
            _ = flowState.returnToCodeEntry(
                cooldownUntil: context.cooldownUntil,
                generation: generation
            )
        case let RegistrationVerificationError.rateLimited(seconds):
            cooldownUntil = dateProvider.now.addingTimeInterval(TimeInterval(seconds))
            _ = flowState.returnToCodeEntry(
                cooldownUntil: cooldownUntil ?? context.cooldownUntil,
                generation: generation
            )
        default:
            flowState.cancel()
            challengeContext = nil
            cooldownUntil = nil
        }
        publishPhase()
        message = userMessage(for: error)
    }

    private func userMessage(for error: Error) -> String {
        switch error {
        case RegistrationInputError.invalidVerificationCode:
            return "请输入六位数字验证码。"
        case RegistrationInputError.invalidPassword:
            return "密码需 12–128 个字符。"
        default:
            break
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "注册请求失败，请稍后重试。"
    }

    private func resetFlow(clearIdentifier: Bool) {
        flowState.cancel()
        challengeContext = nil
        cooldownUntil = nil
        completion = nil
        clearSecrets()
        if clearIdentifier {
            isResettingInput = true
            identifier = ""
            isResettingInput = false
        }
        publishPhase()
    }

    private func clearSecrets() {
        password = ""
        code = ""
    }

    private func publishPhase() {
        phase = flowState.phase
    }
}
