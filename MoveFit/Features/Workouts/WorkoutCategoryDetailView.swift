import SwiftUI

struct WorkoutCategoryDetailView: View {
    @EnvironmentObject private var model: AppModel
    let type: WorkoutType

    private var plans: [TrainingPlan] { model.trainingPlans.filter { $0.type == type } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                GradientCard(colors: [AppColor.primary, AppColor.stand]) {
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(model.localizer.text(type.rawValue)).font(.largeTitle.bold())
                            Text(model.localizer.text("选择适合当前能力与目标的方案，也可以直接开始自由训练。"))
                                .font(.subheadline)
                                .opacity(0.86)
                        }
                        Spacer()
                        Image(systemName: type.symbol).font(.system(size: 52))
                    }
                    .foregroundColor(.white)
                }

                NavigationLink(destination: WorkoutSessionView(type: type).environmentObject(model)) {
                    Label(model.localizer.formatted(
                        "workouts.free.start.format", model.localizer.text(type.rawValue)
                    ), systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primary)

                Text(model.localizer.text("训练方案")).font(.title3.bold())
                if plans.isEmpty {
                    EmptyStateView(
                        title: model.localizer.text("方案准备中"),
                        message: model.localizer.text("仍可使用上方入口开始自由训练。"),
                        symbol: type.symbol
                    )
                } else {
                    ForEach(plans) { plan in
                        NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                            AppCard {
                                HStack(spacing: AppSpacing.medium) {
                                    Image(systemName: plan.type.symbol)
                                        .font(.title2)
                                        .foregroundColor(AppColor.tint(plan.tint))
                                        .frame(width: 50, height: 50)
                                        .background(AppColor.tint(plan.tint).opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                        Text(model.localizer.text(plan.title)).font(.headline)
                                        Text(model.localizer.text(plan.subtitle))
                                            .font(.footnote).foregroundColor(.secondary).lineLimit(2)
                                        Text(model.localizer.formatted(
                                            "workouts.plan.duration.difficulty.format",
                                            plan.durationMinutes,
                                            model.localizer.text(plan.difficulty.rawValue)
                                        ))
                                            .font(.caption.bold())
                                            .foregroundColor(AppColor.tint(plan.tint))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.localizer.text(type.rawValue))
        .navigationBarTitleDisplayMode(.inline)
    }
}
