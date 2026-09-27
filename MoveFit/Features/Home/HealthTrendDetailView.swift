import SwiftUI

struct HealthTrendDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State private var metric = HealthTrendMetric.steps
    @State private var period = HealthTrendPeriod.week

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Picker("指标", selection: $metric) {
                    ForEach(HealthTrendMetric.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("周期", selection: $period) {
                    ForEach(HealthTrendPeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                summaryCard
                chartCard
                sourceCard
            }
            .padding()
        }
        .background(AppColor.pageBackground.ignoresSafeArea())
        .navigationTitle("健康趋势")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectionID) { await model.loadTrend(metric: metric, period: period) }
    }

    private var summaryCard: some View {
        GradientCard(colors: [metricColor, metricColor.opacity(0.68)]) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("\(period.title) · \(metric.title)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.85))
                HStack(alignment: .firstTextBaseline) {
                    Text(format(model.healthTrend.average))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("日均 \(metric.unit)").font(.caption)
                }
                .foregroundColor(.white)
                HStack {
                    summaryItem("总量", value: format(model.healthTrend.total))
                    summaryItem("有效天数", value: "\(model.healthTrend.availablePoints.count)")
                    summaryItem("最佳日", value: bestDate)
                }
            }
        }
    }

    private var chartCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("每日数据").font(.headline)
                if model.healthTrend.availablePoints.isEmpty {
                    EmptyStateView(
                        title: "暂无趋势数据",
                        message: "当前周期没有可读取的 Apple 健康样本。",
                        symbol: "chart.bar"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        TrendBarChart(
                            points: model.healthTrend.points,
                            color: metricColor,
                            showsLabels: period == .week
                        )
                        .frame(
                            width: max(310, CGFloat(model.healthTrend.points.count) * (period == .week ? 38 : 10)),
                            height: 220
                        )
                    }
                }
            }
        }
    }

    private var sourceCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Label("数据来源", systemImage: "heart.text.square.fill").font(.headline)
                Text("按本地日历边界从 Apple 健康实时聚合。无样本与未授权无法可靠区分，因此统一显示暂无数据。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func summaryItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.75))
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        let digits = metric == .distance ? 1 : 0
        return AppFormat.decimal(value, digits: digits)
    }

    private var bestDate: String {
        guard let date = model.healthTrend.bestPoint?.date else { return "—" }
        return date.formatted(.dateTime.month().day())
    }

    private var metricColor: Color {
        switch metric {
        case .steps: return AppColor.stand
        case .distance: return AppColor.exercise
        case .activeEnergy: return AppColor.move
        case .exerciseMinutes: return AppColor.orange
        case .heartRate: return AppColor.move
        case .restingHeartRate: return AppColor.orange
        }
    }

    private var selectionID: String { "\(metric.rawValue)-\(period.rawValue)" }
}
