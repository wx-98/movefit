import SwiftUI

struct ExerciseCatalogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var difficulty: TrainingDifficulty?

    var body: some View {
        List {
            Section {
                catalogSourceText
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section(model.localizer.text("筛选")) {
                Picker(model.localizer.text("难度"), selection: $difficulty) {
                    Text(model.localizer.text("全部")).tag(TrainingDifficulty?.none)
                    ForEach(TrainingDifficulty.allCases) { value in
                        Text(model.localizer.text(value.rawValue)).tag(Optional(value))
                    }
                }
            }
            Section(model.localizer.text("动作")) {
                if model.exercises.isEmpty {
                    Text(model.localizer.text("没有匹配动作")).foregroundColor(.secondary)
                }
                ForEach(model.exercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            Text(model.localizer.text(exercise.name)).font(.headline)
                            Text(model.localizer.formatted(
                                "exercise.catalog.metadata.format",
                                model.localizer.text(exercise.equipment),
                                model.localizer.text(exercise.difficulty.rawValue),
                                exercise.primaryMuscles.map(model.localizer.text)
                                    .joined(separator: model.localizer.text("list.separator"))
                            ))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if model.canLoadMoreExercises {
                    Button {
                        Task { await model.loadMoreExercises() }
                    } label: {
                        if model.isLoadingMoreExercises {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(model.localizer.text("加载更多真实动作"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(model.isLoadingMoreExercises)
                }
            }
        }
        .searchable(text: $query, prompt: model.localizer.text("搜索动作名称"))
        .navigationTitle(model.localizer.text("动作库"))
        .onChange(of: query) { _ in reload() }
        .onChange(of: difficulty) { _ in reload() }
        .task { reload() }
    }

    private var catalogSourceText: Text {
        switch model.exerciseCatalogStatus {
        case let .available(version):
            return Text(model.localizer.formatted("exercise.catalog.connected.format", version))
        case .bundledOnly:
            return Text(model.localizer.formatted(
                "exercise.catalog.fallback.format",
                model.exerciseCatalogMessage.map(model.localizer.text) ?? ""
            ))
        case .failed:
            return Text(model.localizer.text("动作目录加载失败，请检查后端服务后重试。"))
        case .loading:
            return Text(model.localizer.text("正在连接动作目录服务……"))
        }
    }

    private func reload() {
        Task {
            await model.loadExercises(
                query: ExerciseCatalogQuery(text: query, equipment: nil, muscle: nil, difficulty: difficulty)
            )
        }
    }
}
