import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var model: AppModel
    let workout: WorkoutRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                GradientCard(colors: [sourceColor, sourceColor.opacity(0.62)]) {
                    VStack(spacing: AppSpacing.medium) {
                        Image(systemName: workout.type.symbol).font(.system(size: 48))
                        Text(model.localizer.text(workout.type.rawValue)).font(.largeTitle.bold())
                        Text(workout.startedAt.formatted(
                            .dateTime.year().month().day().hour().minute()
                                .locale(Locale(identifier: model.contentLocale))
                        ))
                            .font(.subheadline)
                            .opacity(0.86)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Text(model.localizer.text("运动指标")).font(.headline)
                        HStack {
                            MetricView(
                                title: model.localizer.text("时长"),
                                value: model.localizer.duration(seconds: workout.duration),
                                detail: model.localizer.text("总计")
                            )
                            MetricView(
                                title: model.localizer.text("距离"),
                                value: distanceText,
                                detail: model.localizer.text("可用时显示")
                            )
                        }
                        Divider()
                        HStack {
                            MetricView(
                                title: model.localizer.text("能量"),
                                value: energyText,
                                detail: model.localizer.text("活动能量")
                            )
                            MetricView(
                                title: model.localizer.text("来源"),
                                value: model.localizer.text(workout.source.rawValue),
                                detail: model.localizer.text("数据提供方")
                            )
                        }
                    }
                }

                if workout.route.count > 1 {
                    RouteSummaryView(workout: workout)
                } else {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Label(model.localizer.text("没有可用路线"), systemImage: "map")
                                .font(.headline)
                            Text(routeMessage).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(model.localizer.text("数据说明")).font(.headline)
                        Text(model.localizer.text("本记录使用来源 UUID 与来源类型作为稳定标识合并，不依赖标题、距离等展示字段去重。"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(model.localizer.formatted(
                            "history.workout.id.format", workout.id.uuidString
                        ))
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.localizer.text("运动详情"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourceColor: Color {
        workout.source == .appleHealth ? AppColor.exercise : AppColor.primary
    }

    private var energyText: String {
        guard let energy = workout.energy?.converted(to: .kilocalories).value else { return "—" }
        return model.localizer.formatted("history.kcal.format", Int(energy))
    }

    private var routeMessage: String {
        workout.source == .appleHealth
            ? model.localizer.text("Apple 健康训练样本未提供可读取路线，时长、距离和能量仍会正常展示。")
            : model.localizer.text("本次 MoveFit 训练未记录到有效定位点；可能是室内运动、权限未开启或定位质量不足。")
    }

    private var distanceText: String {
        guard let distance = workout.distance else { return "—" }
        let kilometers = distance.converted(to: .kilometers).value
        let value = kilometers.formatted(
            .number.precision(.fractionLength(1))
                .locale(Locale(identifier: model.contentLocale))
        )
        return model.localizer.formatted("history.distance.format", value)
    }
}
