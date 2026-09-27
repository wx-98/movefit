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
            Section("筛选") {
                Picker("难度", selection: $difficulty) {
                    Text("全部").tag(TrainingDifficulty?.none)
                    ForEach(TrainingDifficulty.allCases) { value in
                        Text(value.rawValue).tag(Optional(value))
                    }
                }
            }
            Section("动作") {
                if model.exercises.isEmpty {
                    Text("没有匹配动作").foregroundColor(.secondary)
                }
                ForEach(model.exercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.equipment) · \(exercise.difficulty.rawValue) · \(exercise.primaryMuscles.joined(separator: "、"))")
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
                            Text("加载更多真实动作").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(model.isLoadingMoreExercises)
                }
            }
        }
        .searchable(text: $query, prompt: "搜索动作名称")
        .navigationTitle("动作库")
        .onChange(of: query) { _ in reload() }
        .onChange(of: difficulty) { _ in reload() }
        .task { reload() }
    }

    private var catalogSourceText: Text {
        switch model.exerciseCatalogStatus {
        case let .available(version):
            return Text("真实动作服务已连接，内容版本：\(version)。")
        case .bundledOnly:
            return Text("动作服务不可用，当前显示随应用发布的内置降级内容。\(model.exerciseCatalogMessage ?? "")")
        case .failed:
            return Text("动作目录加载失败，请检查后端服务后重试。")
        case .loading:
            return Text("正在连接动作目录服务……")
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
