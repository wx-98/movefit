import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var period = HistoryPeriod.week
    @State private var source = WorkoutSourceFilter.all
    @State private var selectedBucketID: Date?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    historyIntro
                    Picker(model.localizer.text("统计周期"), selection: $period) {
                        ForEach(HistoryPeriod.allCases) {
                            Text(model.localizer.text($0.rawValue)).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    GradientCard(colors: [AppColor.stand, AppColor.challenge]) {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            HStack {
                                Text(model.localizer.text("运动汇总"))
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(model.localizer.text(period.rawValue)).font(.caption.bold())
                            }
                            Text(model.localizer.formatted(
                                "history.workout.count.format", periodWorkouts.count
                            ))
                            .font(.largeTitle.bold())
                            HStack {
                                summaryMetric(
                                    title: model.localizer.text("时长"),
                                    value: model.localizer.duration(seconds: totalDuration)
                                )
                                summaryMetric(title: model.localizer.text("距离"), value: distanceText(totalDistance))
                                summaryMetric(title: model.localizer.text("能量"), value: energyText)
                            }
                        }
                        .foregroundColor(.white)
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            HealthSectionHeader(
                                title: model.localizer.text("步数趋势"),
                                detail: comparison.average.map {
                                    model.localizer.formatted(
                                        "history.average.steps.format",
                                        Int($0).formatted(.number.locale(Locale(identifier: model.contentLocale)))
                                    )
                                } ?? model.localizer.text("暂无数据"),
                                symbol: "chart.bar.xaxis"
                            )
                            if model.healthTrend.availablePoints.isEmpty {
                                Text(model.localizer.text("授权 Apple 健康且设备有步数样本后显示。"))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 90)
                            } else {
                                InteractiveTrendChart(
                                    buckets: trendBuckets,
                                    color: AppColor.exercise,
                                    average: comparison.average,
                                    today: Date(),
                                    calendar: trendCalendar,
                                    selectedBucketID: $selectedBucketID
                                )
                                .frame(height: 190)

                                HStack(alignment: .top, spacing: AppSpacing.small) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(AppColor.exercise)
                                    Text(model.localizer.text(comparison.message))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                if let bucket = selectedTrendBucket {
                                    selectedBucketDetail(bucket)
                                } else {
                                    Text(model.localizer.text("点击柱体查看对应日期的步数和相对平均值。"))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    if let workout = periodWorkouts.first(where: { !$0.route.isEmpty }) {
                        RouteSummaryView(workout: workout)
                    }

                    HStack {
                        HealthSectionHeader(
                            title: model.localizer.text("最近运动"),
                            detail: nil,
                            symbol: "clock.arrow.circlepath"
                        )
                        NavigationLink(
                            model.localizer.text("手动添加"),
                            destination: ManualWorkoutView().environmentObject(model)
                        )
                            .font(.subheadline.weight(.semibold))
                    }

                    Picker(model.localizer.text("数据来源"), selection: $source) {
                        ForEach(WorkoutSourceFilter.allCases) {
                            Text(model.localizer.text($0.rawValue)).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let message = model.remoteWorkoutMessage {
                        Label(message, systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if filteredWorkouts.isEmpty {
                        EmptyStateView(
                            title: model.localizer.text("暂无运动记录"),
                            message: emptyMessage,
                            symbol: "figure.walk"
                        )
                    } else {
                        LazyVStack(spacing: AppSpacing.medium) {
                            ForEach(filteredWorkouts) { workout in
                                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                    workoutCard(workout)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("workoutHistoryItem")
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColor.pageBackground.ignoresSafeArea())
            .navigationTitle(model.localizer.text("历史"))
            .onChange(of: period) { value in
                selectedBucketID = nil
                Task { await model.loadTrend(metric: .steps, period: value.healthTrendPeriod) }
            }
            .task { await model.loadTrend(metric: .steps, period: period.healthTrendPeriod) }
        }
    }

    private var historyIntro: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Text(model.localizer.text("活动记录")).font(.largeTitle.bold())
                Text(model.localizer.text("回顾每一次真实运动与进步"))
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.title)
                .foregroundColor(AppColor.stand)
        }
    }

    private var periodWorkouts: [WorkoutRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -period.dayCount, to: Date()) ?? .distantPast
        return model.workouts.filter { $0.startedAt >= start }
    }

    private var filteredWorkouts: [WorkoutRecord] {
        periodWorkouts.filter {
            source == .all
                || (source == .moveFit && $0.source == .moveFit)
                || (source == .appleHealth && $0.source == .appleHealth)
        }
    }

    private var totalDuration: TimeInterval { periodWorkouts.map(\.duration).reduce(0, +) }

    private var trendCalendar: Calendar { .autoupdatingCurrent }

    private var trendBuckets: [HistoryTrendBucket] {
        HistoryTrendBucketer().buckets(
            for: model.healthTrend,
            calendar: trendCalendar,
            timeZone: .autoupdatingCurrent
        )
    }

    private var comparison: HistoryTrendComparison {
        HistoryTrendComparison(
            points: model.healthTrend.points,
            calendar: trendCalendar,
            timeZone: .autoupdatingCurrent,
            now: Date()
        )
    }

    private var selectedTrendBucket: HistoryTrendBucket? {
        guard let selectedBucketID else { return nil }
        return trendBuckets.first { $0.id == selectedBucketID }
    }

    private var totalDistance: Measurement<UnitLength>? {
        let meters = periodWorkouts.compactMap { $0.distance?.converted(to: .meters).value }.reduce(0, +)
        return meters > 0 ? Measurement(value: meters, unit: UnitLength.meters) : nil
    }

    private var energyText: String {
        let value = periodWorkouts.compactMap { $0.energy?.converted(to: .kilocalories).value }.reduce(0, +)
        return value > 0 ? model.localizer.formatted("history.kcal.format", Int(value)) : "—"
    }

    private var emptyMessage: String {
        model.healthStatus == .unavailable
            ? model.localizer.text("此设备不支持 Apple 健康；MoveFit 本地运动仍会显示。")
            : model.localizer.text("请授权 Apple 健康读取运动，或开始一次 MoveFit 运动。")
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
            Text(title).font(.caption).opacity(0.76)
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedBucketDetail(_ bucket: HistoryTrendBucket) -> some View {
        let value = bucket.value.map {
            model.localizer.formatted("history.steps.format", Int($0.rounded()))
        } ?? model.localizer.text("暂无样本")
        let difference = (bucket.value ?? 0) - (comparison.average ?? 0)
        let relativeText: String
        if bucket.value == nil || comparison.average == nil {
            relativeText = model.localizer.text("没有足够数据计算相对平均值。")
        } else if abs(difference) < max(100, (comparison.average ?? 0) * 0.05) {
            relativeText = model.localizer.text("与当前周期平均水平接近。")
        } else {
            relativeText = model.localizer.text(
                difference > 0 ? "高于当前周期平均水平。" : "低于当前周期平均水平。"
            )
        }
        return VStack(alignment: .leading, spacing: AppSpacing.tiny) {
            Text(bucketDateRange(bucket)).font(.subheadline.bold())
            Text(value).font(.title3.bold()).foregroundColor(AppColor.exercise)
            Text(relativeText).font(.footnote).foregroundColor(.secondary)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.exercise.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func bucketDateRange(_ bucket: HistoryTrendBucket) -> String {
        let end = trendCalendar.date(byAdding: .second, value: -1, to: bucket.endDate) ?? bucket.endDate
        if trendCalendar.isDate(bucket.startDate, inSameDayAs: end) {
            return bucket.startDate.formatted(
                .dateTime.year().month().day().locale(Locale(identifier: model.contentLocale))
            )
        }
        let dateStyle = Date.FormatStyle.dateTime.month().day()
            .locale(Locale(identifier: model.contentLocale))
        return "\(bucket.startDate.formatted(dateStyle)) – \(end.formatted(dateStyle))"
    }

    private func workoutCard(_ workout: WorkoutRecord) -> some View {
        AppCard {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: workout.type.symbol)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(workout.source == .appleHealth ? AppColor.exercise : AppColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    HStack {
                        Text(model.localizer.text(workout.type.rawValue)).font(.headline)
                        Text(model.localizer.text(workout.source.rawValue))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColor.raisedSurface)
                            .clipShape(Capsule())
                    }
                    Text(workout.startedAt.formatted(
                        .dateTime.year().month().day().hour().minute()
                            .locale(Locale(identifier: model.contentLocale))
                    ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(model.localizer.formatted(
                        "history.workout.summary.format",
                        model.localizer.duration(seconds: workout.duration),
                        distanceText(workout.distance)
                    ))
                        .font(.caption.bold())
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
        }
    }

    private func distanceText(_ distance: Measurement<UnitLength>?) -> String {
        guard let distance else { return "—" }
        let kilometers = distance.converted(to: .kilometers).value
        let value = kilometers.formatted(
            .number.precision(.fractionLength(1))
                .locale(Locale(identifier: model.contentLocale))
        )
        return model.localizer.formatted("history.distance.format", value)
    }
}

private enum WorkoutSourceFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case appleHealth = "Apple 健康"
    case moveFit = "MoveFit"

    var id: String { rawValue }
}

private extension HistoryPeriod {
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 183
        case .year: return 365
        }
    }

    var healthTrendPeriod: HealthTrendPeriod {
        switch self {
        case .week: return .week
        case .month: return .month
        case .sixMonths: return .sixMonths
        case .year: return .year
        }
    }
}
