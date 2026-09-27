import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    @State private var query = ""
    @State private var selectedCategory: ChallengeCategory?
    @State private var selectedDifficulty: ChallengeDifficulty?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    challengeSummary
                    remoteChallenges
                    if let featured = featuredChallenge {
                        NavigationLink(destination: ChallengeDetailView(challengeID: featured.id)) {
                            featuredCard(featured)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("featuredChallengeCard")
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        HealthSectionHeader(title: "本机挑战目录", detail: "\(filteredChallenges.count)/\(model.challenges.count) 项", symbol: "square.grid.2x2.fill")
                        Picker("运动类别", selection: $selectedCategory) {
                            Text("全部类别").tag(ChallengeCategory?.none)
                            ForEach(ChallengeCategory.allCases) { category in
                                Label(category.rawValue, systemImage: category.symbol).tag(Optional(category))
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("挑战等级", selection: $selectedDifficulty) {
                            Text("全部等级").tag(ChallengeDifficulty?.none)
                            ForEach(ChallengeDifficulty.allCases) { difficulty in
                                Text(difficulty.rawValue).tag(Optional(difficulty))
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppSpacing.medium
                    ) {
                        ForEach(filteredChallenges) { challenge in
                            NavigationLink(destination: ChallengeDetailView(challengeID: challenge.id)) {
                                challengeCard(challenge)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HealthSectionHeader(
                        title: "我的徽章",
                        detail: "\(model.badges.filter(\.isUnlocked).count)/\(model.badges.count) 已解锁",
                        symbol: "medal.fill"
                    )
                    AppCard {
                        HStack(spacing: AppSpacing.small) {
                            ForEach(model.badges) { badge in
                                VStack(spacing: AppSpacing.small) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                badge.isUnlocked
                                                    ? AppColor.challenge.opacity(0.16)
                                                    : Color.secondary.opacity(0.1)
                                            )
                                            .frame(width: 58, height: 58)
                                        Image(systemName: badge.symbol)
                                            .font(.title2)
                                            .foregroundColor(badge.isUnlocked ? AppColor.challenge : .secondary)
                                    }
                                    Text(badge.title)
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    Text("本机挑战与服务端挑战互不混用；服务端进度由后台计算，排行榜请进入服务端挑战查看。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .background(AppColor.pageBackground.ignoresSafeArea())
            .navigationTitle("挑战")
            .searchable(text: $query, prompt: "搜索五公里、减脂、骑行或恢复")
            .task {
                if remote.challengeStatus == .notLoaded {
                    await remote.refreshChallenges(locale: model.contentLocale)
                }
            }
        }
    }

    private var remoteChallenges: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HealthSectionHeader(title: "服务端挑战", detail: "已发布目录", symbol: "cloud.fill")
            switch remote.challengeStatus {
            case .loading:
                ProgressView("正在读取服务端挑战…")
            case .remote, .cached:
                if remote.challengeStatus == .cached {
                    Text("当前离线，以下为本次打开应用时读取的服务端数据。")
                        .font(.footnote).foregroundColor(.secondary)
                }
                ForEach(remote.challenges) { challenge in
                    NavigationLink(destination: RemoteChallengeDetailView(challengeID: challenge.id)) {
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                Text(challenge.title).font(.headline)
                                Text(challenge.summary).font(.footnote).foregroundColor(.secondary)
                                Text("目标 \(AppFormat.decimal(challenge.goalValue)) \(challenge.goalUnit)")
                                    .font(.caption)
                                Text("截止 \(challenge.endsAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if remote.canLoadMoreChallenges {
                    Button("加载更多服务端挑战") {
                        Task { await remote.loadMoreChallenges(locale: model.contentLocale) }
                    }
                    .disabled(remote.isLoadingMoreChallenges)
                }
            case .notLoaded:
                Text("等待服务端挑战目录。")
                    .font(.footnote).foregroundColor(.secondary)
            case .localFallback, .unavailable, .signInRequired:
                Text("服务端暂无已发布挑战或当前不可用；下方仅为本机挑战，不代表服务器参与状态。")
                    .font(.footnote).foregroundColor(.secondary)
                Button("重试读取服务端挑战") {
                    Task { await remote.refreshChallenges(locale: model.contentLocale) }
                }
            }
        }
        .accessibilityIdentifier("remoteChallengeSection")
    }

    private var challengeSummary: some View {
        AppCard {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(AppColor.orange)
                    .frame(width: 48, height: 48)
                    .background(AppColor.orange.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    Text("坚持让每一步都有意义").font(.headline)
                    Text("已加入 \(model.challenges.filter(\.isJoined).count) 个挑战 · 已解锁 \(model.badges.filter(\.isUnlocked).count) 枚徽章")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private var featuredChallenge: Challenge? {
        filteredChallenges.first(where: \.isFeatured) ?? filteredChallenges.first
    }

    private var filteredChallenges: [Challenge] {
        model.challenges.filter { challenge in
            let matchesQuery = query.isEmpty
                || challenge.title.localizedCaseInsensitiveContains(query)
                || challenge.detail.localizedCaseInsensitiveContains(query)
                || challenge.category.rawValue.localizedCaseInsensitiveContains(query)
            let matchesCategory = selectedCategory == nil || challenge.category == selectedCategory
            let matchesDifficulty = selectedDifficulty == nil || challenge.difficulty == selectedDifficulty
            return matchesQuery && matchesCategory && matchesDifficulty
        }
    }

    private func featuredCard(_ challenge: Challenge) -> some View {
        let color = AppColor.tint(challenge.tint)
        return GradientCard(colors: [color, color.opacity(0.72), AppColor.challenge]) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Label("精选挑战", systemImage: "sparkles")
                        .font(.caption.bold())
                    Spacer()
                    Text(challenge.isJoined ? "进行中" : "可加入")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                Spacer(minLength: 22)
                Image(systemName: challenge.symbol).font(.system(size: 40))
                Text(challenge.title).font(.largeTitle.bold())
                Text(challenge.detail).font(.subheadline).opacity(0.88)
                Text("\(challenge.category.rawValue) · \(challenge.difficulty.rawValue)")
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                ProgressView(value: challenge.progress ?? 0, total: challenge.goal)
                    .tint(.white)
                HStack {
                    Text(progressText(challenge))
                    Spacer()
                    Text("目标 \(goalText(challenge))")
                }
                .font(.caption.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .leading)
        }
    }

    private func challengeCard(_ challenge: Challenge) -> some View {
        let color = AppColor.tint(challenge.tint)
        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Image(systemName: challenge.symbol)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(color)
                    .clipShape(Circle())
                Spacer()
                HealthStatusPill(title: challenge.isJoined ? "已加入" : "可加入", tint: color)
            }
            Text(challenge.category.rawValue).font(.caption.bold()).foregroundColor(color)
            Text(challenge.title).font(.headline).lineLimit(2)
            Text(challenge.detail)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
            ProgressView(value: challenge.progress ?? 0, total: challenge.goal).tint(color)
            HStack {
                Text(challenge.difficulty.rawValue).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(progressText(challenge)).font(.caption.bold()).foregroundColor(color)
            }
        }
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        }

    private func progressText(_ challenge: Challenge) -> String {
        guard let progress = challenge.progress else { return "暂无可用数据" }
        return "\(AppFormat.decimal(progress)) \(challenge.unit)"
    }

    private func goalText(_ challenge: Challenge) -> String {
        "\(AppFormat.decimal(challenge.goal)) \(challenge.unit)"
    }
}
