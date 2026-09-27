import Foundation

enum PersonalHealthCategory: String, CaseIterable, Identifiable, Codable {
    case symptom
    case medication
    case nutrition
    case medicalCheck

    var id: String { rawValue }
    var title: String {
        switch self {
        case .symptom: return "症状记录"
        case .medication: return "用药提醒"
        case .nutrition: return "饮食与营养"
        case .medicalCheck: return "检查记录"
        }
    }
    var symbol: String {
        switch self {
        case .symptom: return "waveform.path.ecg"
        case .medication: return "pills.fill"
        case .nutrition: return "leaf.fill"
        case .medicalCheck: return "doc.text.fill"
        }
    }
}

struct PersonalHealthRecord: Identifiable, Equatable {
    let id: UUID
    let category: PersonalHealthCategory
    let occurredAt: Date
    let title: String
    let detail: String
    let primaryValue: Double?
    let secondaryValue: Double?
    let tertiaryValue: Double?
    let isCompleted: Bool
}

struct PersonalHealthStatistics: Equatable {
    let symptomAverageSeverity: Double?
    let medicationAdherence: Double?
    let nutritionCalories: Double
    let checkCount: Int

    static func make(records: [PersonalHealthRecord], calendar: Calendar, now: Date) -> PersonalHealthStatistics {
        let today = calendar.startOfDay(for: now)
        let todayRecords = records.filter { calendar.isDate($0.occurredAt, inSameDayAs: today) }
        let symptoms = records.filter { $0.category == .symptom }.compactMap(\.primaryValue)
        let medications = todayRecords.filter { $0.category == .medication }
        let completed = medications.filter(\.isCompleted).count
        return PersonalHealthStatistics(
            symptomAverageSeverity: symptoms.isEmpty ? nil : symptoms.reduce(0, +) / Double(symptoms.count),
            medicationAdherence: medications.isEmpty ? nil : Double(completed) / Double(medications.count),
            nutritionCalories: todayRecords.filter { $0.category == .nutrition }.compactMap(\.primaryValue).reduce(0, +),
            checkCount: records.filter { $0.category == .medicalCheck }.count
        )
    }
}

enum PersonalHealthInsightEngine {
    static func message(
        for category: PersonalHealthCategory,
        records: [PersonalHealthRecord],
        statistics: PersonalHealthStatistics
    ) -> String {
        switch category {
        case .symptom:
            guard let severity = statistics.symptomAverageSeverity else {
                return "记录症状出现的时间、部位和程度，有助于回顾变化趋势。"
            }
            return severity >= 7
                ? "近期记录的症状程度偏高；如症状持续、加重或让您担心，请及时咨询医生。"
                : "症状程度目前以记录为准；这不是诊断结论，持续观察变化即可。"
        case .medication:
            guard let adherence = statistics.medicationAdherence else {
                return "添加今天的用药计划后，可在此查看完成情况。"
            }
            return adherence == 1
                ? "今日已标记的用药计划均已完成。请始终按医嘱用药。"
                : "今天仍有用药计划未标记完成。请核对医嘱和实际情况后再更新记录。"
        case .nutrition:
            return records.isEmpty
                ? "记录每餐的能量与宏量营养素，帮助您了解饮食构成。"
                : "营养统计仅用于自我管理，不替代医生、营养师或个性化饮食建议。"
        case .medicalCheck:
            return records.isEmpty
                ? "保存检查名称、日期和结论摘要，方便就诊时回顾。"
                : "检查记录仅供您整理资料；结果解读请以医疗专业人员意见为准。"
        }
    }
}

struct PersonalHealthTrendPoint: Identifiable, Equatable {
    let date: Date
    let value: Double

    var id: Date { date }

    static func make(
        category: PersonalHealthCategory,
        records: [PersonalHealthRecord],
        calendar: Calendar,
        now: Date
    ) -> [PersonalHealthTrendPoint] {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        return (0 ..< 7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dailyRecords = records.filter {
                $0.category == category && calendar.isDate($0.occurredAt, inSameDayAs: date)
            }
            let value: Double
            switch category {
            case .symptom:
                let severities = dailyRecords.compactMap(\.primaryValue)
                value = severities.isEmpty ? 0 : severities.reduce(0, +) / Double(severities.count)
            case .medication:
                value = Double(dailyRecords.filter(\.isCompleted).count)
            case .nutrition:
                value = dailyRecords.compactMap(\.primaryValue).reduce(0, +)
            case .medicalCheck:
                value = Double(dailyRecords.count)
            }
            return PersonalHealthTrendPoint(date: date, value: value)
        }
    }
}
