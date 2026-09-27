import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    todayHeader
                    healthSourceCard
                    activityCard
                    trendCard
                    sleepCard
                    healthMetrics
                    personalHealthManagement
                    quickStart
                }
                .padding()
            }
            .accessibilityIdentifier("homeScrollView")
            .background(AppColor.pageBackground.ignoresSafeArea())
            .navigationTitle("MoveFit")
            .refreshable { await model.refreshHealthData() }
        }
    }

    private var todayHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Text("今日概览").font(.largeTitle.bold())
                Text(Date(), format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "heart.fill")
                .foregroundColor(AppColor.move)
                .frame(width: 38, height: 38)
                .background(AppColor.move.opacity(0.12))
                .clipShape(Circle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var healthSourceCard: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: healthStatusSymbol)
                .foregroundColor(healthStatusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(healthStatusTitle).font(.subheadline.bold())
                Text(healthStatusMessage).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button {
                Task { await model.connectHealth() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 36, height: 36)
                    .background(AppColor.raisedSurface)
                    .clipShape(Circle())
            }
            .accessibilityLabel("连接或刷新 Apple 健康")
        }
        .padding(AppSpacing.small)
        .background(AppColor.raisedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
    }

    private var activityCard: some View {
        AppCard {
            VStack(spacing: AppSpacing.large) {
                HStack {
                    HealthSectionHeader(title: "今日活动", detail: "来自 Apple 健康", symbol: "figure.mixed.cardio")
                    Spacer()
                }

                ActivityRingsView(metrics: activityMetrics)
                    .frame(width: 224, height: 224)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(alignment: .top, spacing: AppSpacing.small) {
                    ForEach(activityMetrics) { metric in
                        VStack(spacing: 5) {
                            Circle().fill(metric.color).frame(width: 9, height: 9)
                            Text(metric.title).font(.caption2).foregroundColor(.secondary)
                            Text(metric.displayValue)
                                .font(.headline.monospacedDigit())
                                .foregroundColor(metric.color)
                                .minimumScaleFactor(0.7)
                            Text("目标 \(metric.goalText)").font(.caption2).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var trendCard: some View {
        NavigationLink(destination: HealthTrendDetailView().environmentObject(model)) {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack {
                        Label("健康趋势", systemImage: "chart.bar.fill")
                            .font(.headline)
                            .foregroundColor(AppColor.stand)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(trendAverageText).font(.largeTitle.bold()).monospacedDigit()
                        Text("日均步数").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text("近 7 天").font(.caption.bold()).foregroundColor(AppColor.stand)
                    }
                    if model.weeklyStepTrend.availablePoints.isEmpty {
                        Text("暂无趋势样本，连接 Apple 健康后查看真实历史数据。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        TrendBarChart(points: model.weeklyStepTrend.points, color: AppColor.stand)
                            .frame(height: 92)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("healthTrendCard")
    }

    private var sleepCard: some View {
        NavigationLink(destination: SleepDetailView().environmentObject(model)) {
            GradientCard(colors: [AppColor.sleep, AppColor.sleep.opacity(0.68)]) {
                HStack(spacing: AppSpacing.large) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.16)).frame(width: 86, height: 86)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("睡眠").font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        if let summary = model.sleepSummary {
                            Text(summary.score.map { "\($0) 分" } ?? "评分数据不足")
                                .font(.title.bold())
                            Text("睡眠 \(AppFormat.duration(summary.totalSleep)) · 效率 \(percent(summary.efficiency))")
                                .font(.caption)
                        } else {
                            Text("暂无睡眠数据").font(.title3.bold())
                            Text("授权睡眠分析后展示阶段、效率与本地评分。")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sleepCard")
    }

    private var healthMetrics: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HealthSectionHeader(title: "重点指标", detail: "点击查看详情", symbol: "heart.text.square")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.medium) {
            metricCard(metric: .steps, value: integerText(model.health.steps), detail: "今日", color: AppColor.stand)
            metricCard(metric: .distance, value: distanceText, detail: "公里", color: AppColor.exercise)
            metricCard(metric: .heartRate, value: bpmText(model.health.heartRate), detail: "最新样本", color: AppColor.move)
            metricCard(metric: .restingHeartRate, value: bpmText(model.health.restingHeartRate), detail: "最新样本", color: AppColor.orange)
            }
        }
    }

    private func metricCard(
        metric: HomeHealthMetric,
        value: String,
        detail: String,
        color: Color
    ) -> some View {
        NavigationLink(destination: HealthMetricDetailView(metric: metric).environmentObject(model)) {
            HealthMetricCard(title: metric.title, value: value, detail: detail, symbol: metric.symbol, tint: color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("healthMetric-\(metric.rawValue)")
    }

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HealthSectionHeader(title: "快速开始", detail: "开始一次训练", symbol: "play.circle.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.medium) {
                    quickStartButton(.running, color: AppColor.move)
                    quickStartButton(.walking, color: AppColor.exercise)
                    quickStartButton(.cycling, color: AppColor.stand)
                }
            }
        }
    }

    private var personalHealthManagement: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HealthSectionHeader(title: "健康管理", detail: "仅本机存储", symbol: "cross.case.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.medium) {
                personalHealthLink(.symptom, color: AppColor.move)
                personalHealthLink(.medication, color: AppColor.orange)
                personalHealthLink(.nutrition, color: AppColor.exercise)
                personalHealthLink(.medicalCheck, color: AppColor.stand)
            }
            Text("症状、用药、饮食和检查记录只保存在本机；提示仅用于自我管理，不构成医疗诊断。")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func personalHealthLink(_ category: PersonalHealthCategory, color: Color) -> some View {
        NavigationLink(destination: PersonalHealthManagementView(category: category).environmentObject(model)) {
            AppCard {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: category.symbol)
                        .font(.title3)
                        .foregroundColor(color)
                        .frame(width: 34, height: 34)
                        .background(color.opacity(0.13))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                        Text(category.title).font(.subheadline.bold())
                        Text(personalHealthSummary(category)).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("personalHealthLink-\(category.rawValue)")
    }

    private func personalHealthSummary(_ category: PersonalHealthCategory) -> String {
        let statistics = model.personalHealthStatistics
        switch category {
        case .symptom: return "记录感受与程度"
        case .medication: return statistics.medicationAdherence.map { "今日完成 \(Int(($0 * 100).rounded()))%" } ?? "管理用药计划"
        case .nutrition: return statistics.nutritionCalories > 0 ? "今日 \(Int(statistics.nutritionCalories)) 千卡" : "记录每餐营养"
        case .medicalCheck: return statistics.checkCount > 0 ? "已存 \(statistics.checkCount) 项" : "整理检查结果"
        }
    }

    private func quickStartButton(_ type: WorkoutType, color: Color) -> some View {
        NavigationLink(destination: WorkoutSessionView(type: type).environmentObject(model)) {
            VStack(spacing: AppSpacing.small) {
                Image(systemName: type.symbol)
                    .font(.system(size: 28))
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
                Text(type.rawValue).font(.subheadline.bold())
            }
            .frame(width: 126, height: 120)
            .background(color)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var activityMetrics: [ActivityRingMetric] {
        let energy = model.health.activeEnergy?.converted(to: .kilocalories).value
        let exercise = model.health.exerciseMinutes.map(Double.init)
        let stand = model.health.standHours.map(Double.init)
        return [
            ActivityRingMetric(
                id: "move",
                title: "活动",
                displayValue: energy.map { "\(Int($0.rounded())) 千卡" } ?? "—",
                goalText: "600 千卡",
                progress: energy.map { $0 / 600 },
                color: AppColor.move
            ),
            ActivityRingMetric(
                id: "exercise",
                title: "锻炼",
                displayValue: exercise.map { "\(Int($0)) 分钟" } ?? "—",
                goalText: "30 分钟",
                progress: exercise.map { $0 / 30 },
                color: AppColor.exercise
            ),
            ActivityRingMetric(
                id: "stand",
                title: "站立",
                displayValue: stand.map { "\(Int($0)) 小时" } ?? "—",
                goalText: "12 小时",
                progress: stand.map { $0 / 12 },
                color: AppColor.stand
            )
        ]
    }

    private var trendAverageText: String {
        model.weeklyStepTrend.average.map { Int($0.rounded()).formatted() } ?? "—"
    }

    private var distanceText: String {
        guard let distance = model.health.distance else { return "—" }
        return String(format: "%.1f", distance.converted(to: .kilometers).value)
    }

    private func integerText(_ value: Int?) -> String { value?.formatted() ?? "—" }
    private func bpmText(_ value: Int?) -> String { value.map { "\($0) BPM" } ?? "—" }
    private func percent(_ value: Double?) -> String {
        value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }

    private var healthStatusTitle: String {
        switch model.healthStatus {
        case .notLoaded: return "正在读取 Apple 健康"
        case .unavailable: return "Apple 健康不可用"
        case .noData: return "暂无可用健康数据"
        case .available: return "Apple 健康已连接"
        case .failed: return "健康数据读取失败"
        }
    }

    private var healthStatusMessage: String {
        switch model.healthStatus {
        case .notLoaded: return "正在查询真实设备样本"
        case .unavailable: return "当前设备不支持 HealthKit"
        case .noData: return "未授权或今天没有样本"
        case .available: return "今日数据已刷新"
        case .failed: return "点击右侧按钮重试"
        }
    }

    private var healthStatusSymbol: String {
        switch model.healthStatus {
        case .available: return "checkmark.circle.fill"
        case .unavailable, .failed: return "exclamationmark.triangle.fill"
        case .notLoaded, .noData: return "heart.text.square"
        }
    }

    private var healthStatusColor: Color {
        model.healthStatus == .available ? AppColor.exercise : AppColor.primary
    }
}
