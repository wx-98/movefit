import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var showingManual = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: AppSpacing.medium)]

    private var filteredTypes: [WorkoutType] {
        let supported = WorkoutType.allCases.filter { type in
            model.trainingPlans.contains { $0.type == type }
        }
        return query.isEmpty
            ? supported
            : supported.filter {
                model.localizer.text($0.rawValue).localizedCaseInsensitiveContains(query)
            }
    }

    private var filteredPlans: [TrainingPlan] {
        query.isEmpty
            ? model.trainingPlans
            : model.trainingPlans.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.subtitle.localizedCaseInsensitiveContains(query)
            }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    workoutIntro
                    searchField
                    trainingCatalogState
                    actionCards
                    NavigationLink(destination: ExerciseCatalogView()) {
                        AppCard {
                            HStack(spacing: AppSpacing.medium) {
                                Image(systemName: "list.bullet.rectangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(AppColor.challenge)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                    Text(model.localizer.text("动作库")).font(.headline)
                                    Text(model.localizer.text("查看标准步骤、目标肌群与安全提示"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("exerciseCatalogLink")
                    HealthSectionHeader(
                        title: model.localizer.text("运动分类"),
                        detail: model.localizer.text("按目标选择"),
                        symbol: "square.grid.2x2.fill"
                    )
                    LazyVGrid(columns: columns, spacing: AppSpacing.medium) {
                        ForEach(filteredTypes) { type in
                            NavigationLink(destination: WorkoutCategoryDetailView(type: type)) {
                                categoryCard(type)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("workoutCategory_\(type.id)")
                        }
                    }

                    HealthSectionHeader(
                        title: model.localizer.text("为你推荐"),
                        detail: trainingCatalogSourceTitle,
                        symbol: "sparkles"
                    )
                    if model.trainingCatalogStatus == .empty {
                        EmptyStateView(
                            title: model.localizer.text("暂无已发布训练方案"),
                            message: model.localizer.text("服务端尚未发布当前语言的方案，请稍后重试。"),
                            symbol: "list.bullet.rectangle"
                        )
                        .accessibilityIdentifier("trainingCatalogEmptyState")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.medium) {
                            ForEach(filteredPlans.prefix(6)) { plan in
                                NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                                    recommendationCard(plan)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HealthSectionHeader(
                        title: model.localizer.text("心肺专项"),
                        detail: model.localizer.text("循序渐进"),
                        symbol: "heart.circle.fill"
                    )
                    ForEach(model.trainingPlans.filter { [.running, .walking, .cycling].contains($0.type) }.prefix(3)) { plan in
                        NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                            AppCard {
                                HStack(spacing: AppSpacing.medium) {
                                    Image(systemName: plan.type.symbol)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 52, height: 52)
                                        .background(AppColor.tint(plan.tint))
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                        Text(model.localizer.text(plan.title)).font(.headline)
                                        Text(model.localizer.formatted(
                                            "workouts.plan.duration.difficulty.format",
                                            plan.durationMinutes,
                                            model.localizer.text(plan.difficulty.rawValue)
                                        ))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(AppColor.pageBackground.ignoresSafeArea())
            .navigationTitle(model.localizer.text("运动"))
            .sheet(isPresented: $showingManual) {
                ManualWorkoutView().environmentObject(model)
            }
        }
    }

    private var trainingCatalogSourceTitle: String {
        switch model.trainingCatalogStatus {
        case .available: return model.localizer.text("服务端已发布")
        case .bundledFallback: return model.localizer.text("本地离线方案")
        case .empty: return model.localizer.text("暂无已发布方案")
        case .loading: return model.localizer.text("正在加载训练目录")
        case .failed: return model.localizer.text("训练目录不可用")
        case .notLoaded: return model.localizer.text("等待加载训练目录")
        }
    }

    private var trainingCatalogState: some View {
        HStack(spacing: AppSpacing.small) {
            Text(trainingCatalogSourceTitle)
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("trainingCatalogSourceLabel")
            Spacer()
            if model.trainingCatalogStatus != .loading {
                Button(model.localizer.text("重试训练目录")) {
                    Task { await model.reloadTrainingPlans() }
                }
                .font(.footnote)
                .accessibilityIdentifier("trainingCatalogRetryButton")
            }
        }
    }

    private var workoutIntro: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Text(model.localizer.text("为今天动起来")).font(.largeTitle.bold())
                Text(model.localizer.text("选择一种适合此刻的运动方式"))
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.title)
                .foregroundColor(AppColor.exercise)
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(model.localizer.text("搜索运动或训练方案"), text: $query)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(13)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
    }

    private var actionCards: some View {
        HStack(spacing: AppSpacing.medium) {
            NavigationLink(destination: WorkoutSessionView(type: .running).environmentObject(model)) {
                actionCard(
                    title: model.localizer.text("快速开始"),
                    detail: model.localizer.text("户外跑步"),
                    symbol: "play.fill",
                    color: AppColor.move
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quickStartButton")
            Button {
                showingManual = true
            } label: {
                actionCard(
                    title: model.localizer.text("手动记录"),
                    detail: model.localizer.text("补充训练"),
                    symbol: "plus",
                    color: AppColor.stand
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.localizer.text("手动记录"))
        }
    }

    private func actionCard(title: String, detail: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: symbol).font(.title2)
            Spacer()
            Text(title).font(.headline)
            Text(detail).font(.caption).opacity(0.82)
        }
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func categoryCard(_ type: WorkoutType) -> some View {
        let color = categoryColor(type)
        return VStack(spacing: AppSpacing.small) {
            Image(systemName: type.symbol)
                .font(.system(size: 30))
                .foregroundColor(.white)
            Text(model.localizer.text(type.rawValue))
                .font(.subheadline.bold()).foregroundColor(.white)
            Text(model.localizer.formatted(
                "workouts.plan.count.format",
                model.trainingPlans.filter { $0.type == type }.count
            ))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(LinearGradient(colors: [color, color.opacity(0.64)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func recommendationCard(_ plan: TrainingPlan) -> some View {
        let color = AppColor.tint(plan.tint)
        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Image(systemName: plan.type.symbol).font(.largeTitle)
                Spacer()
                Text(model.localizer.text(plan.difficulty.rawValue))
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
            Spacer()
            Text(model.localizer.text(plan.title)).font(.title2.bold())
            Text(model.localizer.text(plan.subtitle)).font(.footnote).lineLimit(2).opacity(0.86)
            Label(model.localizer.minutes(plan.durationMinutes), systemImage: "clock.fill")
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(AppSpacing.large)
        .frame(width: 286, height: 225, alignment: .leading)
        .background(LinearGradient(colors: [color, color.opacity(0.62), .black.opacity(0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
    }

    private func categoryColor(_ type: WorkoutType) -> Color {
        switch type {
        case .running, .hiit: return AppColor.move
        case .walking, .yoga: return AppColor.exercise
        case .cycling: return AppColor.stand
        case .strength: return AppColor.challenge
        default: return AppColor.orange
        }
    }
}
