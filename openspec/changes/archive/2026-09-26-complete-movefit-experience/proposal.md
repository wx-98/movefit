## Why

当前五个主界面虽然具备基础数据链路，但视觉层级、详情下钻、HealthKit 历史数据覆盖和设置闭环不足，无法形成可持续使用的完整运动健康体验。需要在保留 iOS 15、本地优先和服务端边界的前提下，将参考稿中的信息密度、色彩系统与真实设备数据能力落到可交互、可测试的产品流程。

## What Changes

- 重构首页“今日活动”为居中的三层高对比活动圆环，统一指标比例、图例和无数据状态。
- 新增 HealthKit 7/30/180/365 日趋势查询、趋势摘要、柱状图详情和日均/同期比较。
- 新增 HealthKit 睡眠阶段读取、最近睡眠详情和透明的本地睡眠评分算法；不得声称该评分来自 Apple。
- 重构挑战页的精选、横向挑战卡片、徽章和服务端排行榜占位，并为每项挑战提供可操作详情页。
- 新增运动分类、细分训练方案、方案详情、准备说明和动作库浏览入口。
- 为 `wrkout/exercises.json` 预留服务端动作目录协议与 DTO 映射，不在客户端直接依赖 GitHub Raw。
- 合并 Core Data 与 HealthKit 中的运动记录，按来源 ID 去重，并提供完整历史统计、列表和详情。
- 完善个人中心的资料、成就、健康与设备、账号绑定边界、语言、外观、帮助支持、隐私政策和关于页面。
- 扩展自动化测试，覆盖真实数据映射、评分/趋势纯规则、合并去重、导航详情和设置持久化。

## Capabilities

### New Capabilities

- `health-trends-sleep`: 定义 HealthKit 历史趋势、图表摘要、睡眠阶段与本地睡眠评分。
- `exercise-catalog`: 定义训练方案、动作目录领域模型、后端接口边界、离线状态和详情展示。
- `app-preferences-support`: 定义语言、外观、帮助支持、隐私政策、关于与账号绑定状态页面。

### Modified Capabilities

- `health-dashboard`: 调整活动圆环视觉、趋势与睡眠入口以及详情下钻要求。
- `challenges-achievements`: 增加多彩挑战布局、挑战详情、加入/退出与进度说明。
- `workout-management`: 增加运动分类下钻、细分训练、方案详情与动作指导入口。
- `activity-history`: 将 HealthKit 运动纳入历史并增加来源去重、聚合和详情。
- `account-health-profile`: 完善个人中心入口、账号绑定边界、资料与成就展示。
- `app-shell-design-system`: 扩展语义色板、卡片层级、图表和外观覆盖能力。

## Impact

- 扩展 Domain 健康趋势、睡眠、训练方案、动作目录、偏好和来源模型。
- 扩展 `HealthDataProviding` 并更新 `HealthKitAdapter` 的授权和查询实现。
- 调整 `AppModel` 的加载、合并、缓存、导航数据和设置持久化。
- 新增多个 SwiftUI 详情页及 iOS 15 兼容的自绘柱状图和阶段图。
- Core Data 增加外观、语言等非敏感偏好键；不新增第三方运行时依赖。
- `exercises.json` 使用公共领域数据结构作为后端输入候选，客户端仅依赖自有版本化接口。
