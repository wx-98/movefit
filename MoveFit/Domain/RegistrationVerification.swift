import Foundation

enum RegistrationInputError: Error, Equatable {
    case invalidIdentifier
    case invalidPassword
    case invalidVerificationCode
    case invalidInstallationIdentity
    case invalidVerificationProof
}

enum RegistrationVerificationError: LocalizedError, Equatable {
    case deliveryUnavailable
    case invalidCode
    case invalidProof
    case rateLimited(retryAfterSeconds: Int)

    var errorDescription: String? {
        switch self {
        case .deliveryUnavailable:
            return "验证码服务暂不可用，请稍后重试。"
        case .invalidCode:
            return "验证码无效或已失效，请检查后重试。"
        case .invalidProof:
            return "本次验证已失效，请重新获取验证码。"
        case let .rateLimited(retryAfterSeconds):
            return "操作过于频繁，请在 \(retryAfterSeconds) 秒后重试。"
        }
    }
}

struct RegistrationIdentifier: Equatable {
    let kind: AccountIdentifierKind
    let value: String

    init(kind: AccountIdentifierKind, rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .email:
            let normalized = trimmed.lowercased()
            guard Self.isValidEmail(normalized) else {
                throw RegistrationInputError.invalidIdentifier
            }
            value = normalized
        case .phone:
            guard Self.isValidE164(trimmed) else {
                throw RegistrationInputError.invalidIdentifier
            }
            value = trimmed
        }
        self.kind = kind
    }

    private static func isValidEmail(_ value: String) -> Bool {
        guard value.count <= 254,
              !value.contains(where: { $0.isWhitespace }) else {
            return false
        }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              parts[1].contains(".") else {
            return false
        }
        return true
    }

    private static func isValidE164(_ value: String) -> Bool {
        value.range(of: #"^\+[1-9][0-9]{7,14}$"#, options: .regularExpression) != nil
    }
}

struct RegistrationVerificationCode: Equatable {
    let value: String

    init(_ value: String) throws {
        let scalars = value.unicodeScalars
        guard scalars.count == 6,
              scalars.allSatisfy({ (48 ... 57).contains($0.value) }) else {
            throw RegistrationInputError.invalidVerificationCode
        }
        self.value = value
    }
}

struct RegistrationPassword: Equatable {
    let value: String

    init(_ value: String) throws {
        guard (12 ... 128).contains(value.count) else {
            throw RegistrationInputError.invalidPassword
        }
        self.value = value
    }
}

enum RegistrationFlowPhase: Equatable {
    case idle
    case requesting
    case codeEntry(cooldownUntil: Date)
    case confirming
    case registering
    case completed
}

struct RegistrationFlowState: Equatable {
    private(set) var phase = RegistrationFlowPhase.idle
    private(set) var identifier: RegistrationIdentifier?
    private(set) var challengeID: UUID?
    private(set) var activeGeneration: UUID?

    mutating func startRequest(identifier: RegistrationIdentifier, generation: UUID) {
        self.identifier = identifier
        challengeID = nil
        activeGeneration = generation
        phase = .requesting
    }

    @discardableResult
    mutating func receiveChallenge(
        _ challengeID: UUID,
        cooldownUntil: Date,
        generation: UUID
    ) -> Bool {
        guard phase == .requesting,
              activeGeneration == generation,
              identifier != nil else {
            return false
        }
        self.challengeID = challengeID
        phase = .codeEntry(cooldownUntil: cooldownUntil)
        return true
    }

    mutating func changeIdentifier(to identifier: RegistrationIdentifier) {
        guard self.identifier != identifier else { return }
        reset()
    }

    @discardableResult
    mutating func beginConfirmation(generation: UUID) -> Bool {
        guard case .codeEntry = phase,
              activeGeneration == generation,
              challengeID != nil else {
            return false
        }
        phase = .confirming
        return true
    }

    @discardableResult
    mutating func beginRegistration(generation: UUID) -> Bool {
        guard phase == .confirming,
              activeGeneration == generation else {
            return false
        }
        phase = .registering
        return true
    }

    @discardableResult
    mutating func returnToCodeEntry(cooldownUntil: Date, generation: UUID) -> Bool {
        guard activeGeneration == generation,
              challengeID != nil else {
            return false
        }
        phase = .codeEntry(cooldownUntil: cooldownUntil)
        return true
    }

    @discardableResult
    mutating func complete(generation: UUID) -> Bool {
        guard phase == .registering,
              activeGeneration == generation else {
            return false
        }
        phase = .completed
        challengeID = nil
        activeGeneration = nil
        return true
    }

    mutating func cancel() {
        reset()
    }

    private mutating func reset() {
        phase = .idle
        identifier = nil
        challengeID = nil
        activeGeneration = nil
    }
}
