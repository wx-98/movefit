import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject private var model: AppModel
    let exercise: Exercise
    @State private var selectedFrame = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                exerciseMedia
                GradientCard(colors: [AppColor.challenge, AppColor.stand]) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 42))
                        Text(model.localizer.text(exercise.name)).font(.largeTitle.bold())
                        Text(model.localizer.text(exercise.originalName)).opacity(0.8)
                        Text(model.localizer.formatted(
                            "exercise.detail.metadata.format",
                            model.localizer.text(exercise.difficulty.rawValue),
                            model.localizer.text(exercise.equipment)
                        ))
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                }
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(model.localizer.text("主要肌群")).font(.headline)
                        Text(exercise.primaryMuscles.map { model.localizer.text($0) }
                            .joined(separator: model.localizer.text("list.separator")))
                        if !exercise.secondaryMuscles.isEmpty {
                            Text(model.localizer.text("辅助肌群")).font(.headline)
                            Text(exercise.secondaryMuscles.map { model.localizer.text($0) }
                                .joined(separator: model.localizer.text("list.separator")))
                        }
                    }
                }
                Text(model.localizer.text("动作步骤")).font(.title3.bold())
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: AppSpacing.medium) {
                        Text("\(index + 1)").font(.headline).foregroundColor(AppColor.primary)
                        Text(model.localizer.text(instruction))
                    }
                }
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Label(model.localizer.text("安全提示"), systemImage: "cross.case.fill")
                            .font(.headline)
                            .foregroundColor(AppColor.move)
                        ForEach(exercise.safetyNotes, id: \.self) { note in
                            Text("• \(model.localizer.text(note))")
                        }
                        Text(model.localizer.text("如出现疼痛、眩晕或异常不适，请立即停止并寻求专业帮助。"))
                            .font(.subheadline.bold())
                        Text(model.localizer.formatted(
                            "exercise.detail.content.version.format", exercise.sourceVersion
                        ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.localizer.text("动作详情"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var exerciseMedia: some View {
        let frames = Array(exercise.imageURLs.prefix(2))
        if frames.isEmpty {
            AppCard {
                Label(
                    model.localizer.text("该动作暂未提供演示图片，仍可按下方步骤完成训练。"),
                    systemImage: "photo.on.rectangle.angled"
                )
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Label(model.localizer.text("动作演示"), systemImage: "play.rectangle.fill")
                        .font(.headline)
                    Spacer()
                    Text(frameTitle(for: selectedFrame))
                        .font(.caption.bold())
                        .foregroundColor(AppColor.primary)
                }
                TabView(selection: $selectedFrame) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { index, imageURL in
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            case .failure:
                                mediaFallback(title: model.localizer.text("图片暂不可用"))
                            case .empty:
                                ProgressView(model.localizer.formatted(
                                    "exercise.detail.image.loading.format", frameTitle(for: index)
                                ))
                            @unknown default:
                                mediaFallback(title: model.localizer.text("图片暂不可用"))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 230, maxHeight: 280)
                        .background(AppColor.raisedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .tag(index)
                        .accessibilityLabel(model.localizer.formatted(
                            "exercise.detail.image.accessibility.format", frameTitle(for: index)
                        ))
                    }
                }
                .frame(height: 300)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: frames.count > 1 ? .automatic : .never))
                Text(model.localizer.text(
                    frames.count > 1
                        ? "左右滑动查看起始与结束动作。"
                        : "服务端当前仅提供起始动作图片。"
                ))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func mediaFallback(title: String) -> some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
            Text(title).font(.footnote.bold())
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func frameTitle(for index: Int) -> String {
        model.localizer.text(index == 0 ? "起始动作" : "结束动作")
    }
}
