import SwiftUI

struct SleepDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                scoreCard
                if let summary = model.sleepSummary {
                    stageCard(summary)
                    timelineCard(summary)
                    explanationCard(summary)
                } else {
                    EmptyStateView(
                        title: model.localizer.text("暂无睡眠数据"),
                        message: model.localizer.text("请在 Apple 健康中记录睡眠并允许 MoveFit 读取睡眠分析。"),
                        symbol: "moon.zzz"
                    )
                }
                disclaimerCard
            }
            .padding()
        }
        .background(AppColor.pageBackground.ignoresSafeArea())
        .navigationTitle(model.localizer.text("睡眠"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreCard: some View {
        GradientCard(colors: [AppColor.sleep, AppColor.sleep.opacity(0.62)]) {
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: "moon.stars.fill").font(.system(size: 36))
                Text(model.localizer.text("最近一次睡眠")).font(.headline)
                Text(model.sleepSummary?.score.map(String.init) ?? "—")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text(model.localizer.text(
                    model.sleepSummary?.score == nil ? "评分数据不足" : "MoveFit 本地睡眠评分"
                ))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
        }
    }

    private func stageCard(_ summary: SleepSummary) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(model.localizer.text("睡眠阶段")).font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    stageMetric("总睡眠", duration: summary.totalSleep, color: AppColor.sleep)
                    stageMetric("在床", duration: summary.timeInBed, color: AppColor.stand)
                    stageMetric("核心", duration: summary.coreDuration, color: AppColor.teal)
                    stageMetric("深睡", duration: summary.deepDuration, color: AppColor.challenge)
                    stageMetric("快速眼动", duration: summary.remDuration, color: AppColor.stand)
                    stageMetric("清醒", duration: summary.awakeDuration, color: AppColor.orange)
                }
            }
        }
    }

    private func timelineCard(_ summary: SleepSummary) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Text(model.localizer.text("阶段时间轴")).font(.headline)
                    Spacer()
                    Text("\(summary.startDate.formatted(date: .omitted, time: .shortened))–\(summary.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                GeometryReader { proxy in
                    let total = max(summary.endDate.timeIntervalSince(summary.startDate), 1)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1))
                        ForEach(summary.segments) { segment in
                            let start = segment.startDate.timeIntervalSince(summary.startDate) / total
                            let width = segment.duration / total
                            RoundedRectangle(cornerRadius: 5)
                                .fill(stageColor(segment.stage))
                                .frame(width: max(2, proxy.size.width * width), height: 34)
                                .offset(x: proxy.size.width * start)
                        }
                    }
                }
                .frame(height: 34)
            }
        }
    }

    private func explanationCard(_ summary: SleepSummary) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(model.localizer.text("评分依据")).font(.headline)
                Label(model.localizer.text("睡眠时长：最高 60 分"), systemImage: "clock.fill")
                Label(
                    model.localizer.formatted("sleep.efficiency.format", percent(summary.efficiency)),
                    systemImage: "gauge"
                )
                Label(model.localizer.text("作息规律：最高 15 分；历史不足时为 0 分"), systemImage: "calendar")
                Text(model.localizer.text("评分只在总睡眠和在床时间可计算时生成。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var disclaimerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Label(model.localizer.text("重要说明"), systemImage: "info.circle.fill")
                    .font(.headline)
                Text(model.localizer.text("该评分由 MoveFit 本地规则生成，不是 Apple 官方睡眠评分，也不能用于诊断睡眠障碍。持续不适请咨询专业人员。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func stageMetric(_ title: String, duration: TimeInterval, color: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 5, height: 32)
            VStack(alignment: .leading) {
                Text(model.localizer.text(title)).font(.caption).foregroundColor(.secondary)
                Text(duration > 0 ? model.localizer.duration(seconds: duration) : "—")
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .inBed: return AppColor.stand.opacity(0.55)
        case .asleep: return AppColor.sleep.opacity(0.75)
        case .awake: return AppColor.orange
        case .core: return AppColor.teal
        case .deep: return AppColor.challenge
        case .rem: return AppColor.stand
        }
    }

    private func percent(_ value: Double?) -> String {
        value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }
}
