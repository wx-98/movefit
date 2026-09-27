import Foundation

struct BundledTrainingCatalog: TrainingCatalogProviding {
    func plans() async throws -> [TrainingPlan] { Self.allPlans }

    private static let allPlans: [TrainingPlan] = [
        plan(
            id: "run-5k",
            type: .running,
            title: "五公里轻松跑",
            subtitle: "建立稳定配速与连续跑能力",
            difficulty: .beginner,
            duration: 38,
            goal: "以能完整说短句的强度完成 5 公里",
            suitableFor: "已有连续快走 30 分钟基础的人",
            steps: [("动态热身", "踝、膝、髋关节活动与慢走", 8), ("轻松跑", "保持均匀呼吸，不追求速度", 25), ("放松", "慢走并拉伸小腿与大腿", 5)],
            safety: ["首次训练可采用跑 4 分钟、走 1 分钟", "胸痛、眩晕或异常气促时立即停止"],
            tint: .blue
        ),
        plan(
            id: "run-fat-loss",
            type: .running,
            title: "低强度减脂跑",
            subtitle: "用可持续的二区强度积累有氧时间",
            difficulty: .beginner,
            duration: 45,
            goal: "持续 30 分钟舒适慢跑",
            suitableFor: "希望改善心肺耐力与运动习惯的人",
            steps: [("热身快走", "逐步提升心率", 10), ("舒适慢跑", "主观强度保持 4/10", 30), ("冷身", "慢走至呼吸平稳", 5)],
            safety: ["不要用出汗量判断减脂效果", "炎热天气降低强度并及时补水"],
            tint: .green
        ),
        plan(
            id: "run-sprint",
            type: .running,
            title: "间歇冲刺跑",
            subtitle: "短时高强度与充分恢复交替",
            difficulty: .advanced,
            duration: 30,
            goal: "完成 6 组可控的 30 秒快速跑",
            suitableFor: "已规律跑步至少 8 周且无伤病的人",
            steps: [("充分热身", "慢跑并完成动态跑姿练习", 12), ("间歇组", "快速跑 30 秒、慢走 90 秒，共 6 组", 12), ("冷身", "慢跑或步行", 6)],
            safety: ["不要在疲劳或湿滑路面冲刺", "动作变形时提前结束训练"],
            tint: .rose
        ),
        plan(
            id: "walk-energy",
            type: .walking,
            title: "活力快走",
            subtitle: "低冲击提升每日活动量",
            difficulty: .beginner,
            duration: 30,
            goal: "完成连续快走并保持自然摆臂",
            suitableFor: "久坐、恢复期或刚开始运动的人",
            steps: [("慢走热身", "放松肩颈与髋部", 5), ("节奏快走", "步幅自然，呼吸加深", 20), ("舒缓", "逐渐降低步频", 5)],
            safety: ["选择平整路线与合脚鞋袜"],
            tint: .orange
        ),
        plan(
            id: "cycle-base",
            type: .cycling,
            title: "骑行耐力基础",
            subtitle: "用稳定踏频建立有氧基础",
            difficulty: .intermediate,
            duration: 50,
            goal: "完成 40 分钟稳定骑行",
            suitableFor: "能熟练操控车辆与变速的人",
            steps: [("轻松踩踏", "检查车辆并逐渐提速", 8), ("耐力骑行", "保持稳定踏频和可控呼吸", 37), ("冷身", "降低阻力与速度", 5)],
            safety: ["户外骑行必须佩戴头盔并遵守交通规则"],
            tint: .blue
        ),
        plan(
            id: "strength-full-body",
            type: .strength,
            title: "全身力量入门",
            subtitle: "深蹲、推、拉与核心稳定",
            difficulty: .beginner,
            duration: 28,
            goal: "以稳定动作完成 3 轮循环",
            suitableFor: "希望建立基础力量与动作模式的人",
            steps: [("关节热身", "肩、髋与踝活动", 5), ("循环训练", "深蹲、俯卧撑、划船、死虫，每项 10 次", 18), ("拉伸", "舒缓主要肌群", 5)],
            safety: ["先保证动作质量再增加重量", "关节锐痛时立即停止"],
            tint: .purple
        ),
        plan(
            id: "yoga-recovery",
            type: .yoga,
            title: "舒缓恢复瑜伽",
            subtitle: "温和活动髋、背与肩颈",
            difficulty: .beginner,
            duration: 20,
            goal: "在无痛范围内完成舒展与呼吸",
            suitableFor: "久坐或训练后需要恢复的人",
            steps: [("呼吸", "仰卧腹式呼吸", 3), ("流动", "猫牛式、婴儿式与低弓步", 13), ("放松", "仰卧休息", 4)],
            safety: ["不强压关节角度，保持顺畅呼吸"],
            tint: .green
        ),
        plan(
            id: "hiit-quick",
            type: .hiit,
            title: "十五分钟 HIIT",
            subtitle: "无需器械的短时全身间歇",
            difficulty: .intermediate,
            duration: 15,
            goal: "完成 3 轮 40 秒练习、20 秒休息",
            suitableFor: "已有基础体能且能完成标准深蹲的人",
            steps: [("热身", "原地走与动态伸展", 3), ("主训练", "开合跳、深蹲、登山跑、平板支撑", 9), ("冷身", "降低心率并拉伸", 3)],
            safety: ["可以踏步替代跳跃以降低冲击", "心血管疾病风险人群训练前咨询专业人员"],
            tint: .rose
        )
    ]

    private static func plan(
        id: String,
        type: WorkoutType,
        title: String,
        subtitle: String,
        difficulty: TrainingDifficulty,
        duration: Int,
        goal: String,
        suitableFor: String,
        steps: [(String, String, Int)],
        safety: [String],
        tint: ChallengeTint
    ) -> TrainingPlan {
        TrainingPlan(
            id: id,
            type: type,
            title: title,
            subtitle: subtitle,
            difficulty: difficulty,
            durationMinutes: duration,
            goal: goal,
            suitableFor: suitableFor,
            steps: steps.enumerated().map {
                TrainingStep(id: "\(id)-\($0.offset)", title: $0.element.0, detail: $0.element.1, durationMinutes: $0.element.2)
            },
            safetyNotes: safety,
            tint: tint
        )
    }
}
