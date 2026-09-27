import Foundation

struct ExerciseCatalogDTO: Codable {
    let id: String
    let name: String
    let originalName: String
    let difficulty: String
    let equipment: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let safetyNotes: [String]
    let catalogVersion: String
}

struct BundledExerciseCatalog: ExerciseCatalogProviding {
    func exercises(query: ExerciseCatalogQuery, page: Int, pageSize: Int) async throws -> ExerciseCatalogPage {
        let mapped = Self.items.compactMap(Self.map).filter { exercise in
            (query.text.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(query.text)
                || exercise.originalName.localizedCaseInsensitiveContains(query.text))
                && (query.equipment == nil || exercise.equipment == query.equipment)
                && (query.muscle == nil || exercise.primaryMuscles.contains(query.muscle ?? ""))
                && (query.difficulty == nil || exercise.difficulty == query.difficulty)
        }
        let start = max(0, page * pageSize)
        let end = min(mapped.count, start + pageSize)
        let values = start < end ? Array(mapped[start..<end]) : []
        return ExerciseCatalogPage(
            exercises: values,
            sourceVersion: Self.version,
            hasMore: end < mapped.count,
            source: .bundledFallback(message: "当前显示随应用发布的内置动作。")
        )
    }

    private static func map(_ dto: ExerciseCatalogDTO) -> Exercise? {
        guard let difficulty = TrainingDifficulty(rawValue: dto.difficulty) else { return nil }
        return Exercise(
            id: dto.id,
            name: dto.name,
            originalName: dto.originalName,
            difficulty: difficulty,
            equipment: dto.equipment,
            primaryMuscles: dto.primaryMuscles,
            secondaryMuscles: dto.secondaryMuscles,
            instructions: dto.instructions,
            safetyNotes: dto.safetyNotes,
            sourceVersion: dto.catalogVersion
        )
    }

    private static let version = "bundled-zh-CN-1"
    private static let items = [
        ExerciseCatalogDTO(id: "bodyweight-squat", name: "自重深蹲", originalName: "Bodyweight Squat", difficulty: "入门", equipment: "徒手", primaryMuscles: ["股四头肌", "臀肌"], secondaryMuscles: ["核心"], instructions: ["双脚约与肩同宽，脚尖自然向外", "屈髋屈膝下蹲，膝盖方向与脚尖一致", "脚掌均匀发力站起，保持躯干稳定"], safetyNotes: ["膝部不适时减小幅度", "不要塌腰或让膝盖突然内扣"], catalogVersion: version),
        ExerciseCatalogDTO(id: "push-up", name: "俯卧撑", originalName: "Push-Up", difficulty: "入门", equipment: "徒手", primaryMuscles: ["胸肌", "肱三头肌"], secondaryMuscles: ["肩", "核心"], instructions: ["双手略宽于肩，身体保持直线", "屈肘下降至胸部接近地面", "推地回到起始位置"], safetyNotes: ["可用跪姿或斜板版本降低难度", "手腕或肩部锐痛时停止"], catalogVersion: version),
        ExerciseCatalogDTO(id: "plank", name: "前臂平板支撑", originalName: "Plank", difficulty: "入门", equipment: "瑜伽垫", primaryMuscles: ["核心"], secondaryMuscles: ["肩", "臀肌"], instructions: ["肘部位于肩下，前臂贴地", "收紧腹部与臀部，头到脚保持直线", "正常呼吸并保持姿势"], safetyNotes: ["腰部下沉时立即休息", "避免憋气"], catalogVersion: version),
        ExerciseCatalogDTO(id: "kettlebell-swing", name: "壶铃摆动", originalName: "Kettlebell Swing", difficulty: "进阶", equipment: "壶铃", primaryMuscles: ["臀肌", "腘绳肌"], secondaryMuscles: ["核心", "背部"], instructions: ["壶铃置于身前，屈髋握住手柄", "髋部快速伸展带动壶铃向前", "控制壶铃回落并再次屈髋"], safetyNotes: ["动作动力来自髋部而不是手臂", "未掌握硬拉动作前不要使用大重量"], catalogVersion: version),
        ExerciseCatalogDTO(id: "dumbbell-row", name: "单臂哑铃划船", originalName: "One-Arm Dumbbell Row", difficulty: "进阶", equipment: "哑铃", primaryMuscles: ["背部"], secondaryMuscles: ["肱二头肌", "核心"], instructions: ["支撑身体并保持背部中立", "将哑铃拉向髋部", "缓慢下放至手臂伸直"], safetyNotes: ["避免耸肩和躯干扭转", "腰背不适时停止"], catalogVersion: version),
        ExerciseCatalogDTO(id: "dead-bug", name: "死虫式", originalName: "Dead Bug", difficulty: "入门", equipment: "瑜伽垫", primaryMuscles: ["核心"], secondaryMuscles: ["髋屈肌"], instructions: ["仰卧抬起四肢，腰背轻贴地面", "缓慢伸展对侧手臂和腿", "回到起点并交替进行"], safetyNotes: ["腰背离地时减小动作范围"], catalogVersion: version)
    ]
}
