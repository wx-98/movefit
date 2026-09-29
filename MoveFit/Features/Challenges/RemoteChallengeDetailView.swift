import SwiftUI

struct RemoteChallengeDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    let challengeID: UUID

    @State private var detail: RemoteChallenge?
    @State private var leaderboard: RemoteLeaderboard?
    @State private var leaderboardEntries: [RemoteLeaderboardEntry] = []
    @State private var leaderboardMessage: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var message: String?
    @State private var operationID = UUID()
    @State private var pendingIsJoining: Bool?

    private var participation: RemoteChallengeParticipation? {
        remote.participations.first { $0.challengeID == challengeID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if let detail {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            Text(detail.title).font(.title.bold())
                            Text(detail.summary).font(.body)
                            Text(model.localizer.formatted("challenges.remote.goal.format", AppFormat.decimal(detail.goalValue), detail.goalUnit))
                            Text(model.localizer.formatted("challenges.remote.ends.format", detail.endsAt.formatted(date: .abbreviated, time: .shortened)))
                                .font(.footnote).foregroundColor(.secondary)
                            Text(model.localizer.text("服务端挑战 · 进度由后台计算，不使用本机估算"))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    participationSection
                    leaderboardSection
                } else if isLoading {
                    ProgressView(model.localizer.text("正在读取挑战详情…"))
                } else {
                    EmptyStateView(
                        title: model.localizer.text("挑战暂不可用"),
                        message: model.localizer.text("请检查网络后重试。"),
                        symbol: "trophy"
                    )
                    Button(model.localizer.text("重试")) { Task { await load() } }
                }
            }
            .padding()
        }
        .background(AppColor.pageBackground.ignoresSafeArea())
        .navigationTitle(detail?.title ?? model.localizer.text("服务端挑战"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("操作结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var participationSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(model.localizer.text("我的服务端参与")).font(.headline)
                if let participation {
                    Text(model.localizer.formatted("challenges.participation.status.format", participation.status))
                    ProgressView(value: participation.progressValue, total: max(participation.goalValue, 1))
                    Text("\(AppFormat.decimal(participation.progressValue)) / \(AppFormat.decimal(participation.goalValue)) \(participation.goalUnit)")
                    Text(model.localizer.formatted("challenges.participation.calculated.format", participation.calculatedAt.formatted(date: .abbreviated, time: .shortened)))
                        .font(.caption).foregroundColor(.secondary)
                } else if model.accountSession == nil {
                    Text(model.localizer.text("登录后可以参与服务端挑战；不会创建本机伪参与。"))
                        .font(.footnote).foregroundColor(.secondary)
                } else if remote.participationStatus != .remote {
                    Text(model.localizer.text("尚无法确认服务端参与状态，请稍后刷新。"))
                        .font(.footnote).foregroundColor(.secondary)
                } else {
                    Text(model.localizer.text("尚未参与")).font(.footnote).foregroundColor(.secondary)
                }
                Button(model.localizer.text(
                    pendingIsJoining != nil ? "重试原挑战操作" :
                    (participation == nil ? "加入服务端挑战" : "退出服务端挑战")
                )) {
                    Task { await updateParticipation(isJoining: participation == nil) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.accountSession == nil || remote.isWriting
                          || (remote.participationStatus != .remote && pendingIsJoining == nil))
                .accessibilityIdentifier("remoteChallengeParticipationButton")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var leaderboardSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(model.localizer.text("隐私化排行榜")).font(.headline)
                if let leaderboard {
                    Text(model.localizer.formatted("challenges.leaderboard.snapshot.format", leaderboard.snapshotGeneratedAt.formatted(date: .abbreviated, time: .shortened)))
                        .font(.caption).foregroundColor(.secondary)
                    if leaderboardEntries.isEmpty {
                        Text(model.localizer.text("暂无排行记录")).foregroundColor(.secondary)
                    }
                    ForEach(leaderboardEntries.indices, id: \.self) { index in
                        let entry = leaderboardEntries[index]
                        HStack {
                            Text("#\(entry.rank)")
                            Text(entry.displayAlias)
                            if entry.isCurrentUser { Text(model.localizer.text("我")).font(.caption) }
                            Spacer()
                            Text("\(AppFormat.decimal(entry.progressValue)) \(entry.goalUnit)")
                        }
                    }
                    if leaderboard.hasMore && leaderboard.nextCursor != nil {
                        Button(model.localizer.text("加载更多排名")) { Task { await loadMoreLeaderboard() } }
                            .disabled(isLoadingMore)
                    }
                } else {
                    Text(leaderboardMessage ?? model.localizer.text("排行榜暂不可用；不会展示演示用户。"))
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await remote.challenge(id: challengeID, locale: model.contentLocale)
            do {
                leaderboard = try await remote.leaderboard(challengeID: challengeID, cursor: nil)
                leaderboardEntries = leaderboard?.entries ?? []
                leaderboardMessage = nil
            } catch {
                leaderboard = nil
                leaderboardEntries = []
                leaderboardMessage = model.localizer.text("服务端排行榜当前不可用；不会展示演示用户。")
            }
            if model.accountSession != nil { await remote.refreshParticipations() }
        } catch {
            message = model.localizer.text("无法读取服务端挑战，请检查网络后重试。")
        }
    }

    private func loadMoreLeaderboard() async {
        guard !isLoadingMore, let cursor = leaderboard?.nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = try await remote.leaderboard(challengeID: challengeID, cursor: cursor)
            leaderboardEntries.append(contentsOf: next.entries)
            leaderboard = next
        } catch {
            message = model.localizer.text("加载更多排名失败，请重试。")
        }
    }

    private func updateParticipation(isJoining: Bool) async {
        guard model.accountSession != nil else {
            message = model.localizer.text("请先登录后端账号。")
            return
        }
        let targetIsJoining = pendingIsJoining ?? isJoining
        let succeeded = targetIsJoining
            ? await remote.join(challengeID: challengeID, locale: model.contentLocale, operationID: operationID)
            : await remote.leave(challengeID: challengeID, operationID: operationID)
        if succeeded {
            pendingIsJoining = nil
            operationID = UUID()
            await remote.refreshParticipations()
        } else {
            pendingIsJoining = targetIsJoining
            message = model.localizer.text("服务端未确认操作，请检查网络后用原操作重试。")
        }
    }
}
