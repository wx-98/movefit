import SwiftUI

struct PersonalHealthManagementView: View {
    @EnvironmentObject private var model: AppModel

    let category: PersonalHealthCategory

    @State private var title = ""
    @State private var detail = ""
    @State private var primaryValue = ""
    @State private var secondaryValue = ""
    @State private var tertiaryValue = ""
    @State private var isCompleted = false

    private var records: [PersonalHealthRecord] {
        model.personalHealthRecords.filter { $0.category == category }
    }

    private var trendPoints: [PersonalHealthTrendPoint] {
        model.personalHealthTrendPoints(for: category)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                overviewCard
                statisticsCard
                recordForm
                recordsSection
                safetyCard
            }
            .padding()
        }
        .background(AppColor.pageBackground.ignoresSafeArea())
        .navigationTitle(model.localizer.text(category.title))
        .accessibilityIdentifier("personalHealth-\(category.rawValue)")
    }

    private var overviewCard: some View {
        GradientCard(colors: [tint, tint.opacity(0.66)]) {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: category.symbol)
                    .font(.system(size: 36))
                    .frame(width: 68, height: 68)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    Text(model.localizer.text(category.title)).font(.title3.bold())
                    Text(overviewText).font(.footnote)
                }
                Spacer()
            }
            .foregroundColor(.white)
        }
    }

    private var statisticsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Label(model.localizer.text("近 7 天趋势"), systemImage: "chart.xyaxis.line")
                        .font(.headline)
                    Spacer()
                    Text(statisticText).font(.caption.bold()).foregroundColor(tint)
                }
                PersonalHealthTrendChart(points: trendPoints, color: tint)
                    .frame(height: 96)
                Text(model.localizer.text(PersonalHealthInsightEngine.message(
                    for: category,
                    records: records,
                    statistics: model.personalHealthStatistics
                )))
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
    }

    private var recordForm: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Label(model.localizer.text("添加记录"), systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(tint)
                TextField(titlePlaceholder, text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField(detailPlaceholder, text: $detail)
                    .textFieldStyle(.roundedBorder)
                valueFields
                if category == .medication {
                    Toggle(model.localizer.text("已按计划完成"), isOn: $isCompleted)
                }
                Button {
                    Task { await saveRecord() }
                } label: {
                    Text(model.localizer.text("保存本地记录"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .accessibilityIdentifier("savePersonalHealthRecord")
            }
        }
    }

    @ViewBuilder
    private var valueFields: some View {
        switch category {
        case .symptom:
            TextField(model.localizer.text("程度（1–10）"), text: $primaryValue)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        case .medication:
            TextField(model.localizer.text("剂量或数量（可选）"), text: $primaryValue)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        case .nutrition:
            HStack(spacing: AppSpacing.small) {
                valueField(model.localizer.text("千卡"), text: $primaryValue)
                valueField(model.localizer.text("蛋白质 g"), text: $secondaryValue)
                valueField(model.localizer.text("碳水 g"), text: $tertiaryValue)
            }
        case .medicalCheck:
            TextField(model.localizer.text("指标数值（可选）"), text: $primaryValue)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func valueField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HealthSectionHeader(
                    title: model.localizer.text("历史记录"),
                    detail: model.localizer.formatted("personal.records.count.format", records.count),
                    symbol: "clock.arrow.circlepath"
                )
            if records.isEmpty {
                AppCard {
                    Text(model.localizer.text("尚无记录。添加第一条记录后，这里会展示趋势和可回顾的详细时间线。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(records) { record in
                    recordCard(record)
                }
            }
        }
    }

    private func recordCard(_ record: PersonalHealthRecord) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                Image(systemName: category.symbol)
                    .foregroundColor(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    Text(record.title).font(.subheadline.bold())
                    if !record.detail.isEmpty {
                        Text(record.detail).font(.footnote).foregroundColor(.secondary)
                    }
                    HStack {
                        Text(record.occurredAt, format: .dateTime.month().day().hour().minute())
                        if let valueText = displayValues(for: record) {
                            Text(valueText)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                if category == .medication {
                    Button {
                        Task {
                            await model.setPersonalHealthRecordCompletion(
                                id: record.id,
                                isCompleted: !record.isCompleted
                            )
                        }
                    } label: {
                        Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(record.isCompleted ? AppColor.exercise : .secondary)
                    }
                    .accessibilityLabel(model.localizer.text(record.isCompleted ? "标记为未完成" : "标记为已完成"))
                }
                Button(role: .destructive) {
                    Task { await model.deletePersonalHealthRecord(id: record.id) }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(model.localizer.text("删除记录"))
            }
        }
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundColor(AppColor.teal)
            Text(model.localizer.text("这些记录仅保存在此设备，用于自我管理。系统提供的是非诊断性提示，不能替代医生、药师或营养师的建议；紧急或严重症状请及时寻求医疗帮助。"))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(AppSpacing.medium)
        .background(AppColor.raisedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
    }

    private var tint: Color {
        switch category {
        case .symptom: return AppColor.move
        case .medication: return AppColor.orange
        case .nutrition: return AppColor.exercise
        case .medicalCheck: return AppColor.stand
        }
    }

    private var overviewText: String {
        switch category {
        case .symptom: return model.localizer.text("记录感受、部位与程度，回顾变化趋势。")
        case .medication: return model.localizer.text("逐项标记今天的用药计划与完成情况。")
        case .nutrition: return model.localizer.text("汇总膳食能量与宏量营养素记录。")
        case .medicalCheck: return model.localizer.text("整理检查项目、来源与结果摘要。")
        }
    }

    private var titlePlaceholder: String {
        switch category {
        case .symptom: return model.localizer.text("症状名称，例如头痛")
        case .medication: return model.localizer.text("药品名称")
        case .nutrition: return model.localizer.text("餐次或食物，例如午餐")
        case .medicalCheck: return model.localizer.text("检查项目，例如血常规")
        }
    }

    private var detailPlaceholder: String {
        switch category {
        case .symptom: return model.localizer.text("部位、持续时间或诱因（可选）")
        case .medication: return model.localizer.text("医嘱、服用时间或备注（可选）")
        case .nutrition: return model.localizer.text("食物组成或备注（可选）")
        case .medicalCheck: return model.localizer.text("机构、结论摘要或备注（可选）")
        }
    }

    private var statisticText: String {
        let statistics = model.personalHealthStatistics
        switch category {
        case .symptom:
            return statistics.symptomAverageSeverity
                .map { model.localizer.formatted("personal.symptom.average.format", String(format: "%.1f", $0)) }
                ?? model.localizer.text("暂无程度数据")
        case .medication:
            return statistics.medicationAdherence
                .map { model.localizer.formatted("personal.medication.adherence.format", "\(Int(($0 * 100).rounded()))%") }
                ?? model.localizer.text("暂无今日计划")
        case .nutrition:
            return model.localizer.formatted("personal.nutrition.calories.format", Int(statistics.nutritionCalories.rounded()))
        case .medicalCheck:
            return model.localizer.formatted("personal.checks.count.format", statistics.checkCount)
        }
    }

    private func displayValues(for record: PersonalHealthRecord) -> String? {
        switch category {
        case .symptom:
            return record.primaryValue.map { model.localizer.formatted("personal.symptom.value.format", String(format: "%.1f", $0)) }
        case .medication:
            return record.primaryValue.map { model.localizer.formatted("personal.medication.dose.format", String(format: "%.1f", $0)) }
        case .nutrition:
            let values = [
                record.primaryValue.map { model.localizer.formatted("personal.nutrition.kcal.format", Int($0.rounded())) },
                record.secondaryValue.map { model.localizer.formatted("personal.protein.format", Int($0.rounded())) },
                record.tertiaryValue.map { model.localizer.formatted("personal.carbs.format", Int($0.rounded())) }
            ].compactMap { $0 }
            return values.isEmpty ? nil : values.joined(separator: " · ")
        case .medicalCheck:
            return record.primaryValue.map { model.localizer.formatted("personal.check.value.format", String(format: "%.2f", $0)) }
        }
    }

    private func saveRecord() async {
        let didSave = await model.savePersonalHealthRecord(
            category: category,
            title: title,
            detail: detail,
            primaryValue: Double(primaryValue),
            secondaryValue: Double(secondaryValue),
            tertiaryValue: Double(tertiaryValue),
            isCompleted: isCompleted
        )
        guard didSave else { return }
        title = ""
        detail = ""
        primaryValue = ""
        secondaryValue = ""
        tertiaryValue = ""
        isCompleted = false
    }
}

private struct PersonalHealthTrendChart: View {
    let points: [PersonalHealthTrendPoint]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(points.map(\.value).max() ?? 0, 1)
            HStack(alignment: .bottom, spacing: AppSpacing.small) {
                ForEach(points) { point in
                    VStack(spacing: AppSpacing.tiny) {
                        Capsule()
                            .fill(point.value == 0 ? color.opacity(0.16) : color)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 3,
                                maxHeight: max(3, proxy.size.height - 20) * CGFloat(point.value / maximum)
                            )
                        Text(point.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("近七天健康管理记录趋势"))
    }
}
