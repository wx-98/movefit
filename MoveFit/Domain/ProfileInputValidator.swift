import Foundation

enum ProfileValidationError: LocalizedError, Equatable {
    case emptyNickname
    case invalidHeight
    case invalidWeight
    case invalidBodyFat

    var errorDescription: String? {
        switch self {
        case .emptyNickname: return "请输入昵称。"
        case .invalidHeight: return "身高应在 80–250 厘米之间。"
        case .invalidWeight: return "体重应在 20–300 千克之间。"
        case .invalidBodyFat: return "体脂率应在 3%–70% 之间。"
        }
    }
}

struct ProfileInputValidator {
    func validate(
        nickname: String,
        heightCentimeters: Double,
        weightKilograms: Double,
        bodyFatPercentage: Double
    ) throws -> UserProfile {
        let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedNickname.isEmpty else { throw ProfileValidationError.emptyNickname }
        guard (80...250).contains(heightCentimeters) else { throw ProfileValidationError.invalidHeight }
        guard (20...300).contains(weightKilograms) else { throw ProfileValidationError.invalidWeight }
        guard (3...70).contains(bodyFatPercentage) else { throw ProfileValidationError.invalidBodyFat }
        return UserProfile(
            nickname: cleanedNickname,
            height: Measurement(value: heightCentimeters, unit: .centimeters),
            weight: Measurement(value: weightKilograms, unit: .kilograms),
            bodyFatPercentage: bodyFatPercentage
        )
    }
}
