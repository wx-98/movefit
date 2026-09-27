import Foundation

struct ChallengeCatalog {
    func challenges() -> [Challenge] {
        runningChallenges + cyclingChallenges + strengthChallenges + hiitChallenges + stepChallenges + recoveryChallenges
    }

    private var runningChallenges: [Challenge] {
        makeChallenges(
            category: .running,
            unit: "公里",
            metric: .longestRunningDistance,
            dataSource: "MoveFit 与 Apple 健康跑步记录",
            plans: [
                plan("3K 重启", "用一场轻松跑重新建立节奏", 3, .beginner),
                plan("5K 入门", "完成你的第一场五公里", 5, .beginner),
                plan("减脂 5K", "以可持续节奏完成五公里", 5, .intermediate),
                plan("比赛 5K", "为五公里比赛建立信心", 5, .goal),
                plan("夜跑 5K", "在安全前提下完成夜间五公里", 5, .intermediate),
                plan("7K 挑战", "从五公里迈向七公里", 7, .intermediate),
                plan("10K 进阶", "完成一场十公里耐力跑", 10, .goal),
                plan("12K 耐力", "在稳定节奏下完成十二公里", 12, .goal),
                plan("15K 长跑", "为更长距离建立耐力基础", 15, .goal),
                plan("半马前置", "完成一次二十公里长距离跑", 20, .goal)
            ]
        )
    }

    private var cyclingChallenges: [Challenge] {
        makeChallenges(
            category: .cycling,
            unit: "公里",
            metric: .totalCyclingDistance,
            dataSource: "MoveFit 与 Apple 健康骑行记录",
            plans: [
                plan("通勤 10K", "累计完成十公里轻松骑行", 10, .beginner),
                plan("城市 20K", "探索二十公里城市骑行路线", 20, .beginner),
                plan("燃脂 30K", "用稳定骑行累积三十公里", 30, .intermediate),
                plan("周末 40K", "安排一段周末耐力骑行", 40, .intermediate),
                plan("湖畔 50K", "完成五十公里中距离骑行", 50, .goal),
                plan("爬坡 60K", "在体感合适时挑战更长距离", 60, .goal),
                plan("百公里预热", "累计完成七十公里骑行", 70, .goal),
                plan("耐力 80K", "累计完成八十公里骑行", 80, .goal),
                plan("周末 90K", "累计完成九十公里骑行", 90, .goal),
                plan("百公里骑行", "累计完成一百公里骑行", 100, .goal)
            ]
        )
    }

    private var strengthChallenges: [Challenge] {
        makeChallenges(
            category: .strength,
            unit: "天",
            metric: .strengthDays,
            dataSource: "MoveFit 与 Apple 健康力量训练日期",
            plans: [
                plan("力量起步", "完成 3 个力量训练日", 3, .beginner),
                plan("全身 5 日", "完成 5 个力量训练日", 5, .beginner),
                plan("核心 7 日", "完成 7 个力量训练日", 7, .intermediate),
                plan("上肢 8 日", "完成 8 个力量训练日", 8, .intermediate),
                plan("下肢 10 日", "完成 10 个力量训练日", 10, .intermediate),
                plan("推拉 12 日", "完成 12 个力量训练日", 12, .goal),
                plan("力量 14 日", "完成 14 个力量训练日", 14, .goal),
                plan("核心 16 日", "完成 16 个力量训练日", 16, .goal),
                plan("稳定 20 日", "完成 20 个力量训练日", 20, .goal),
                plan("力量习惯", "完成 24 个力量训练日", 24, .goal)
            ]
        )
    }

    private var hiitChallenges: [Challenge] {
        makeChallenges(
            category: .hiit,
            unit: "天",
            metric: .hiitDays,
            dataSource: "MoveFit 与 Apple 健康 HIIT 训练日期",
            plans: [
                plan("HIIT 初体验", "完成 2 个 HIIT 训练日", 2, .beginner),
                plan("燃动 3 日", "完成 3 个 HIIT 训练日", 3, .beginner),
                plan("冲刺 5 日", "完成 5 个 HIIT 训练日", 5, .intermediate),
                plan("间歇 6 日", "完成 6 个 HIIT 训练日", 6, .intermediate),
                plan("心肺 8 日", "完成 8 个 HIIT 训练日", 8, .intermediate),
                plan("爆发 10 日", "完成 10 个 HIIT 训练日", 10, .goal),
                plan("间歇 12 日", "完成 12 个 HIIT 训练日", 12, .goal),
                plan("挑战 14 日", "完成 14 个 HIIT 训练日", 14, .goal),
                plan("高效 16 日", "完成 16 个 HIIT 训练日", 16, .goal),
                plan("耐力 20 日", "完成 20 个 HIIT 训练日", 20, .goal)
            ]
        )
    }

    private var stepChallenges: [Challenge] {
        makeChallenges(
            category: .steps,
            unit: "步",
            metric: .steps,
            dataSource: "Apple 健康步数",
            plans: [
                plan("午间 3 千步", "累计完成 3,000 步", 3_000, .beginner),
                plan("日行 5 千步", "累计完成 5,000 步", 5_000, .beginner),
                plan("活力 8 千步", "累计完成 8,000 步", 8_000, .intermediate),
                plan("每日 1 万步", "累计完成 10,000 步", 10_000, .intermediate),
                plan("周末 2 万步", "累计完成 20,000 步", 20_000, .goal),
                plan("本周 3 万步", "累计完成 30,000 步", 30_000, .goal),
                plan("本周 5 万步", "累计完成 50,000 步", 50_000, .goal),
                plan("本周 7 万步", "累计完成 70,000 步", 70_000, .goal),
                plan("本周 10 万步", "累计完成 100,000 步", 100_000, .goal),
                plan("城市漫游", "累计完成 120,000 步", 120_000, .goal)
            ]
        )
    }

    private var recoveryChallenges: [Challenge] {
        makeChallenges(
            category: .recovery,
            unit: "天",
            metric: .recoveryDays,
            dataSource: "MoveFit 与 Apple 健康低强度训练日期",
            plans: [
                plan("拉伸 3 日", "完成 3 个恢复训练日", 3, .beginner),
                plan("睡前放松 5 日", "完成 5 个恢复训练日", 5, .beginner),
                plan("轻瑜伽 7 日", "完成 7 个恢复训练日", 7, .intermediate),
                plan("步行恢复 8 日", "完成 8 个恢复训练日", 8, .intermediate),
                plan("柔韧 10 日", "完成 10 个恢复训练日", 10, .intermediate),
                plan("平衡 12 日", "完成 12 个恢复训练日", 12, .goal),
                plan("恢复 14 日", "完成 14 个恢复训练日", 14, .goal),
                plan("轻松 16 日", "完成 16 个恢复训练日", 16, .goal),
                plan("节奏 20 日", "完成 20 个恢复训练日", 20, .goal),
                plan("恢复习惯", "完成 24 个恢复训练日", 24, .goal)
            ]
        )
    }

    private func makeChallenges(
        category: ChallengeCategory,
        unit: String,
        metric: ChallengeMetric,
        dataSource: String,
        plans: [Plan]
    ) -> [Challenge] {
        plans.enumerated().map { index, plan in
            Challenge(
                id: stableID(category: category, index: index),
                title: plan.title,
                detail: plan.detail,
                goal: plan.goal,
                progress: nil,
                isJoined: false,
                symbol: category.symbol,
                tint: tint(for: category),
                unit: unit,
                dataSource: dataSource,
                rules: [
                    "仅计入本机已授权且可读取的数据。",
                    "按自然日去重，同一训练日最多计 1 天。",
                    "不适时请降低强度或停止训练。"
                ],
                category: category,
                difficulty: plan.difficulty,
                metric: metric,
                isFeatured: index == 1
            )
        }
    }

    private func plan(_ title: String, _ detail: String, _ goal: Double, _ difficulty: ChallengeDifficulty) -> Plan {
        Plan(title: title, detail: detail, goal: goal, difficulty: difficulty)
    }

    private func stableID(category: ChallengeCategory, index: Int) -> UUID {
        // 保留早期三个内置挑战的标识，避免升级后丢失用户已参加状态。
        if category == .steps && index == 8 { return legacyID(1) }
        if category == .running && index == 1 { return legacyID(2) }
        if category == .strength && index == 6 { return legacyID(3) }
        let categoryByte = UInt8(ChallengeCategory.allCases.firstIndex(of: category) ?? 0)
        let indexByte = UInt8(index + 1)
        return UUID(uuid: (0xA1, 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, categoryByte, indexByte))
    }

    private func legacyID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    private func tint(for category: ChallengeCategory) -> ChallengeTint {
        switch category {
        case .running: return .rose
        case .cycling: return .blue
        case .strength: return .purple
        case .hiit: return .orange
        case .steps: return .green
        case .recovery: return .blue
        }
    }
}

private struct Plan {
    let title: String
    let detail: String
    let goal: Double
    let difficulty: ChallengeDifficulty
}
