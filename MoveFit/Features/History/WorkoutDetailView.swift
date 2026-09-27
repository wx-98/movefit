import SwiftUI

struct WorkoutDetailView: View {
    let workout: WorkoutRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                GradientCard(colors: [sourceColor, sourceColor.opacity(0.62)]) {
                    VStack(spacing: AppSpacing.medium) {
                        Image(systemName: workout.type.symbol).font(.system(size: 48))
                        Text(workout.type.rawValue).font(.largeTitle.bold())
                        Text(workout.startedAt.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .opacity(0.86)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Text("运动指标").font(.headline)
                        HStack {
                            MetricView(title: "时长", value: AppFormat.duration(workout.duration), detail: "总计")
                            MetricView(title: "距离", value: AppFormat.distance(workout.distance), detail: "可用时显示")
                        }
                        Divider()
                        HStack {
                            MetricView(title: "能量", value: energyText, detail: "活动能量")
                            MetricView(title: "来源", value: workout.source.rawValue, detail: "数据提供方")
                        }
                    }
                }

                if workout.route.count > 1 {
                    RouteSummaryView(workout: workout)
                } else {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Label("没有可用路线", systemImage: "map")
                                .font(.headline)
                            Text(routeMessage).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text("数据说明").font(.headline)
                        Text("本记录使用来源 UUID 与来源类型作为稳定标识合并，不依赖标题、距离等展示字段去重。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("记录 ID：\(workout.id.uuidString)")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("运动详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourceColor: Color {
        workout.source == .appleHealth ? AppColor.exercise : AppColor.primary
    }

    private var energyText: String {
        guard let energy = workout.energy?.converted(to: .kilocalories).value else { return "—" }
        return "\(Int(energy)) 千卡"
    }

    private var routeMessage: String {
        workout.source == .appleHealth
            ? "Apple 健康训练样本未提供可读取路线，时长、距离和能量仍会正常展示。"
            : "本次 MoveFit 训练未记录到有效定位点；可能是室内运动、权限未开启或定位质量不足。"
    }
}
