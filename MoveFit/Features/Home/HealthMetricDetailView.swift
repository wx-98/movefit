import SwiftUI

struct HealthMetricDetailView: View {
    @EnvironmentObject private var model: AppModel
    let metric: HomeHealthMetric
    @State private var selectedBucketID: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                content
            }
            .padding()
        }
        .background(AppColor.pageBackground.ignoresSafeArea())
        .navigationTitle(model.localizer.text(metric.title))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: metric) { await model.loadHealthMetricDetail(metric) }
    }

    @ViewBuilder
    private var content: some View {
        switch model.healthMetricDetailStatus {
        case .idle, .loading:
            ProgressView(model.localizer.text("正在读取 Apple 健康数据"))
                .frame(maxWidth: .infinity, minHeight: 260)
        case .unavailable:
            EmptyStateView(
                title: model.localizer.text("Apple 健康不可用"),
                message: model.localizer.formatted(
                    "health.metric.unavailable.format", model.localizer.text(metric.title)
                ),
                symbol: metric.symbol
            )
        case .noData:
            EmptyStateView(
                title: model.localizer.formatted(
                    "health.metric.no.data.format", model.localizer.text(metric.title)
                ),
                message: model.localizer.text("请确认已授权 Apple 健康并在健康 App 中积累样本。无样本不代表你拒绝了授权。"),
                symbol: metric.symbol
            )
        case .failed:
            EmptyStateView(
                title: model.localizer.text("数据读取失败"),
                message: model.localizer.text("请稍后重试，或在系统设置中检查 Apple 健康读取权限。"),
                symbol: "exclamationmark.triangle"
            )
        case .available:
            if let detail = model.healthMetricDetail, detail.metric == metric {
                detailContent(detail)
            }
        }
    }

    private func detailContent(_ detail: HealthMetricDetail) -> some View {
        VStack(spacing: AppSpacing.large) {
            GradientCard(colors: [color, color.opacity(0.65)]) {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Label(model.localizer.text(metric.title), systemImage: metric.symbol)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.88))
                    Text(valueText(detail.currentValue, unit: detail.unit))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(model.localizer.text("今天 / 最新可读样本"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.82))
                }
            }

            statisticsCard(detail)
            trendCard(detail)
            insightCard
            if metric == .heartRate || metric == .restingHeartRate {
                electrocardiogramCard
            }
            sourceCard(detail)
        }
    }

    private func statisticsCard(_ detail: HealthMetricDetail) -> some View {
        AppCard {
            HStack {
                MetricView(
                    title: model.localizer.text("近 30 天平均"),
                    value: valueText(detail.average, unit: detail.unit),
                    detail: model.localizer.text("有效样本")
                )
                MetricView(
                    title: model.localizer.text(metric == .distance ? "累计距离" : "累计值"),
                    value: valueText(detail.total, unit: detail.unit),
                    detail: model.localizer.text("当前周期")
                )
                MetricView(
                    title: model.localizer.text("有效天数"),
                    value: "\(detail.trend.availablePoints.count)",
                    detail: model.localizer.text("Apple 健康")
                )
            }
        }
    }

    private func trendCard(_ detail: HealthMetricDetail) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Text(model.localizer.text("近 30 天趋势")).font(.headline)
                    Spacer()
                    Text(model.localizer.text("点击柱体查看日期"))
                        .font(.caption).foregroundColor(.secondary)
                }
                let buckets = HistoryTrendBucketer().buckets(
                    for: detail.trend,
                    calendar: .autoupdatingCurrent,
                    timeZone: .autoupdatingCurrent
                )
                InteractiveTrendChart(
                    buckets: buckets,
                    color: color,
                    average: detail.average,
                    today: Date(),
                    calendar: .autoupdatingCurrent,
                    selectedBucketID: $selectedBucketID
                )
                .frame(height: 190)
                if let selectedBucket = buckets.first(where: { $0.id == selectedBucketID }) {
                    Text(model.localizer.formatted(
                        "health.metric.day.value.format",
                        selectedBucket.startDate.formatted(
                            .dateTime.year().month().day()
                                .locale(Locale(identifier: model.contentLocale))
                        ),
                        valueText(selectedBucket.value, unit: detail.unit)
                    ))
                        .font(.footnote.bold())
                        .foregroundColor(color)
                }
            }
        }
    }

    private var insightCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Label(model.localizer.text("健康洞察"), systemImage: "sparkles")
                        .font(.headline)
                        .foregroundColor(AppColor.challenge)
                    Spacer()
                    Button(model.localizer.text("刷新")) {
                        Task { await model.requestHealthInsights() }
                    }
                        .font(.caption.bold())
                }
                switch model.healthInsightAccess {
                case .localOnly:
                    Text(model.localizer.text("当前为本地趋势洞察。AI 服务上线后可由后端按权益启用远程分析。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                case let .upgradeRequired(productID):
                    Text(model.localizer.formatted("health.insight.upgrade.format", productID))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                case let .remoteAvailable(capabilityVersion):
                    Text(model.localizer.formatted("health.insight.remote.format", capabilityVersion))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                ForEach(model.healthInsights) { insight in
                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                        Text(insight.title).font(.subheadline.bold())
                        Text(insight.message).font(.subheadline)
                        Text(model.localizer.text(insight.source.label))
                            .font(.caption).foregroundColor(.secondary)
                        Text(model.localizer.text(insight.safetyNotice))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(AppSpacing.medium)
                    .background(AppColor.challenge.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                }
            }
        }
    }

    private var electrocardiogramCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Label(model.localizer.text("心电图记录"), systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundColor(AppColor.move)
                if model.electrocardiograms.isEmpty {
                    Text(model.localizer.text("未读取到可用 ECG 记录。请确认设备支持、已在 Apple 健康中授权，并已保存 ECG 记录。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(model.electrocardiograms.prefix(3)) { record in
                        Button {
                            Task { await model.loadElectrocardiogramWaveform(recordID: record.id) }
                        } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            Text(model.localizer.text(record.classification.title))
                                .font(.subheadline.bold())
                            Text(record.recordedAt.formatted(.dateTime.year().month().day().hour().minute()))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(model.localizer.text(record.classification.safetyMessage))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(model.localizer.text("点按查看历史波形"))
                                .font(.caption).foregroundColor(AppColor.move)
                        }
                        }
                        .buttonStyle(.plain)
                        if model.selectedElectrocardiogramID == record.id {
                            if model.electrocardiogramWaveformLoading {
                                ProgressView(model.localizer.text("正在读取波形"))
                            } else if let waveform = model.electrocardiogramWaveform {
                                ECGWaveformChart(waveform: waveform).frame(height: 120)
                            } else if let message = model.electrocardiogramWaveformMessage {
                                Label(message, systemImage: "exclamationmark.circle")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(AppSpacing.small)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppColor.raisedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                            }
                        }
                    }
                }
                Text(model.localizer.text("MoveFit 仅在您点按记录后于内存中显示 HealthKit 提供的波形，不保存、上传或分析原始心电图，也不提供诊断。"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sourceCard(_ detail: HealthMetricDetail) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Label(model.localizer.text("数据来源"), systemImage: "heart.text.square.fill")
                    .font(.headline)
                Text(model.localizer.text(detail.dataSource)).font(.subheadline)
                Text(detail.lastUpdated.map {
                    model.localizer.formatted(
                        "health.metric.last.read.format",
                        $0.formatted(
                            .dateTime.year().month().day().hour().minute()
                                .locale(Locale(identifier: model.contentLocale))
                        )
                    )
                } ?? model.localizer.text("暂无可读取样本"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var color: Color {
        switch metric {
        case .steps: return AppColor.stand
        case .distance: return AppColor.exercise
        case .heartRate: return AppColor.move
        case .restingHeartRate: return AppColor.orange
        }
    }

    private func valueText(_ value: Double?, unit: String) -> String {
        guard let value else { return "—" }
        let digits = metric == .distance ? 1 : 0
        let number = value.formatted(
            .number.precision(.fractionLength(digits))
                .locale(Locale(identifier: model.contentLocale))
        )
        return "\(number) \(model.localizer.text(unit))"
    }
}
