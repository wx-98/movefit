## Context

MoveFit 已有 HealthKit 当日摘要、Core Location 前台运动和 Core Data 本地状态，但首页只显示单日数据，历史只读取应用自有运动，挑战和运动内容缺少详情，设置入口大多不可操作。工程最低支持 iOS 15，因此不能使用 Swift Charts；所有图表必须使用 SwiftUI `Shape`、`GeometryReader` 和标准布局完成。

外部候选数据集 `wrkout/exercises.json` 使用 Unlicense，单项 JSON 包含名称、发力方式、难度、动作机制、器械、主/次肌群、步骤和分类。许可允许使用，但原始英文内容缺少稳定版本、中文化、动作安全审核和服务等级保证，不适合由客户端直接请求 GitHub Raw。

## Goals / Non-Goals

**Goals:**

- 使用真实 HealthKit 历史数据驱动趋势、睡眠和完整运动历史。
- 建立具有参考稿色彩层级、详情下钻、空态和加载态的五个完整主界面。
- 为训练方案和动作库建立可替换的领域协议及本地可用内容。
- 将外观、语言等非敏感偏好持久化，并补齐帮助、隐私和账号绑定边界。
- 保持 iOS 15、无第三方运行时依赖、本地优先和初始化器注入。

**Non-Goals:**

- 不复制 Apple 健身或 Apple 健康的商标、专有插画和像素级界面。
- 不声称本地睡眠评分是 Apple 官方评分，也不提供医疗诊断。
- 不实现真实微信/Apple ID 绑定、远程排行榜、云同步和动作内容后端。
- 不在客户端直接下载或打包 `wrkout/exercises.json` 全量数据与图片。
- 不增加后台定位、Watch App 或 HealthKit 写入。

## Decisions

### 1. 使用领域快照隔离 HealthKit

新增 `HealthTrend`、`HealthTrendPoint`、`SleepSummary`、`SleepStageSegment` 和 HealthKit 运动快照。`HealthKitAdapter` 将系统类型映射为领域模型，View 和 AppModel 不接触 `HKSample`。趋势使用 `HKStatisticsCollectionQuery` 按本地日历日聚合；睡眠使用 `sleepAnalysis` 分类样本；运动使用 `HKSampleQuery` 查询 `HKWorkout`。

替代方案是让 View 按需执行 HealthKit 查询，但会破坏既有依赖方向、难以测试且容易重复授权和查询。

### 2. 睡眠评分采用透明的本地规则

评分为 0 到 100 的展示性指标：时长最多 60 分、效率最多 25 分、规律性最多 15 分；只要关键样本不足便不生成总分。详情页必须列出计算依据和“非 Apple 官方/非医疗指标”说明。

替代方案是只展示时长，不满足评分需求；使用不可解释的模型则难以验证并可能误导健康决策。

### 3. 本地与 HealthKit 运动只在读取时合并

Core Data 继续只拥有 MoveFit 自建记录。AppModel 查询本地 Repository 与 HealthKit 运动后，以“来源 + 稳定 ID”去重并按开始时间排序。HealthKit 样本不复制到 Core Data，避免所有权和删除语义混乱。

### 4. iOS 15 图表使用轻量自绘组件

活动圆环、柱状趋势和睡眠阶段图作为 Design System 组件实现，输入仅为归一化值和语义色令牌。详情页显示周期、日均、总量、最佳日和可用数据天数；空样本不绘制伪柱。

### 5. 训练内容分为本地方案与远程动作目录

内置少量中文训练方案，保证离线可浏览并可进入已有运动会话。新增 `ExerciseCatalogProviding`：

```text
exercise catalog endpoint
  -> versioned ExerciseDTO
  -> ExerciseRepository mapping/cache
  -> Exercise domain model
  -> SwiftUI list/detail
```

未来服务端负责从 `wrkout/exercises.json` 导入、固定上游版本、中文化、去重、安全审核和媒体授权。客户端接口支持分页、关键词、器械、肌群和难度过滤，并具有未配置状态；不把 GitHub Raw 作为生产 API。

### 6. 设置项只对真实能力给出成功状态

外观支持跟随系统、浅色和深色并即时应用；语言保存“跟随系统/简体中文”，当前发布包只声明简体中文。帮助、隐私、数据来源和关于信息完全本地可用。Apple ID 与微信绑定进入状态页，但服务未配置时只显示要求和接入说明，按钮不得产生已绑定状态。

## Risks / Trade-offs

- [HealthKit 读取权限无法区分拒绝与无样本] → 统一显示“暂无可用数据”，不推断授权选择。
- [睡眠样本可能重叠或来自多个来源] → 按时间区间合并重叠片段，并展示可用来源范围而非逐来源排名。
- [大量历史样本影响启动速度] → 首页优先加载 7/30 日摘要，长周期仅在详情选择后查询；查询状态独立于基础页面。
- [HealthKit 与本地运动可能表示同一次活动] → 先以稳定来源 ID 去重；跨来源不做基于时间的自动删除，只标记来源以避免误合并。
- [内置训练内容会过时] → 明确其为随应用发布的基础方案，动作目录协议允许未来后端替换。
- [上游公共领域不等于内容质量合格] → 服务端接入前必须完成版本固定、中文化、安全审核和媒体许可复核。

## Migration Plan

1. 以新增可选字段扩展领域模型和协议，现有 Core Data 记录保持可读取。
2. 增加 HealthKit 读取类型后，由用户再次主动触发系统授权；未授权不阻塞本地功能。
3. 新设置偏好使用现有键值 Core Data 实体保存，缺失值迁移为“跟随系统/跟随系统”。
4. 先上线本地训练方案与未配置动作目录状态，未来替换 Repository 实现无需修改 View。
5. 回滚时可恢复旧 View；新增偏好记录和只读 HealthKit 查询不会破坏旧数据库。

## Open Questions

- 真实动作目录后端确定后，需要补充 API 版本、分页上限、媒体 CDN、内容审核版本和离线缓存过期策略。
- 若未来需要英语界面，必须先完成全量字符串资源化，再开放英语选项。
