import SwiftUI

struct ChallengeDetailView: View {
    @EnvironmentObject private var model: AppModel
    let challengeID: UUID

    private var challenge: Challenge? {
        model.challenges.first { $0.id == challengeID }
    }

    var body: some View {
        ScrollView {
            if let challenge {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    hero(challenge)
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            Text("挑战规则").font(.headline)
                            ForEach(Array(challenge.rules.enumerated()), id: \.offset) { index, rule in
                                HStack(alignment: .top, spacing: AppSpacing.small) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(AppColor.tint(challenge.tint))
                                        .clipShape(Circle())
                                    Text(rule).font(.subheadline)
                                }
                            }
                        }
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text("数据来源").font(.headline)
                            Label(challenge.dataSource, systemImage: "heart.text.square.fill")
                                .foregroundColor(.secondary)
                            Text("MoveFit 只使用本机已授权且可读取的数据计算进度；没有数据时不会推断为零，也不会补充演示值。")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    Button {
                        Task {
                            challenge.isJoined
                                ? await model.leave(challengeID: challenge.id)
                                : await model.join(challengeID: challenge.id)
                        }
                    } label: {
                        Text(challenge.isJoined ? "退出挑战" : "加入挑战")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(challenge.isJoined ? Color.secondary : AppColor.tint(challenge.tint))
                    .accessibilityIdentifier("challengeJoinButton")
                }
                .padding()
            } else {
                EmptyStateView(title: "挑战不存在", message: "该挑战可能已经下线。", symbol: "trophy")
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(challenge?.title ?? "挑战详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ challenge: Challenge) -> some View {
        let color = AppColor.tint(challenge.tint)
        let ratio = ChallengeProgressCalculator().ratio(progress: challenge.progress ?? 0, goal: challenge.goal)
        return GradientCard(colors: [color, color.opacity(0.65)]) {
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: challenge.symbol).font(.system(size: 44))
                Text(challenge.title).font(.title.bold())
                ZStack {
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 13)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack {
                        Text("\(Int(ratio * 100))%").font(.title.bold())
                        Text(challenge.progress == nil ? "暂无数据" : "已完成").font(.caption)
                    }
                }
                .frame(width: 138, height: 138)
                Text("\(AppFormat.decimal(challenge.progress)) / \(AppFormat.decimal(challenge.goal)) \(challenge.unit)")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
        }
    }
}
