import SwiftUI

struct TrainingPlanDetailView: View {
    @EnvironmentObject private var model: AppModel
    let plan: TrainingPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                GradientCard(colors: [AppColor.tint(plan.tint), AppColor.tint(plan.tint).opacity(0.62)]) {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Image(systemName: plan.type.symbol).font(.system(size: 44))
                        Text(model.localizer.text(plan.title)).font(.largeTitle.bold())
                        Text(model.localizer.text(plan.subtitle)).opacity(0.86)
                        HStack {
                            Label(model.localizer.minutes(plan.durationMinutes), systemImage: "clock")
                            Spacer()
                            Label(
                                model.localizer.text(plan.difficulty.rawValue),
                                systemImage: "chart.bar.fill"
                            )
                        }
                        .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(model.localizer.text("训练目标")).font(.headline)
                        Text(model.localizer.text(plan.goal))
                        Divider()
                        Text(model.localizer.text("适合人群")).font(.headline)
                        Text(model.localizer.text(plan.suitableFor))
                    }
                }

                Text(model.localizer.text("训练流程")).font(.title3.bold())
                ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: AppSpacing.medium) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(AppColor.tint(plan.tint))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            HStack {
                                Text(model.localizer.text(step.title)).font(.headline)
                                Spacer()
                                Text(model.localizer.minutes(step.durationMinutes))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Text(model.localizer.text(step.detail))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Label(model.localizer.text("安全提示"), systemImage: "exclamationmark.shield.fill")
                            .font(.headline)
                            .foregroundColor(AppColor.orange)
                        ForEach(plan.safetyNotes, id: \.self) { note in
                            Label(model.localizer.text(note), systemImage: "checkmark.circle")
                                .font(.subheadline)
                        }
                        Text(model.localizer.text("内容用于一般运动指导，不能替代医疗诊断或个体化专业建议。"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: WorkoutSessionView(type: plan.type).environmentObject(model)) {
                    Text(model.localizer.text("开始这项训练"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.tint(plan.tint))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.localizer.text("方案详情"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
