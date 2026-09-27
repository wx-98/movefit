## 背景与动机

当前仓库只有中文需求稿、五个 HTML 界面参考和 Logo，尚无可运行的 iOS 工程。需要建立一个最低支持 iOS 15、结合 Apple 健康数据能力与运动内容体验的 MoveFit 应用，并让后续实现可依照 OpenSpec 和项目编码规则持续演进。

## 变更内容

- 从零建立 SwiftUI iOS 应用、五 Tab 导航、品牌资源和统一设计系统。
- 实现首页健康概览、HealthKit 授权与数据聚合，以及权限不可用时的降级状态。
- 实现运动目录、搜索、快速开始、运动会话状态管理、手动记录和运动结果保存。
- 实现历史筛选、趋势展示、运动列表和路线摘要。
- 实现挑战、徽章、排行榜和用户参与状态的基础体验。
- 实现个人资料、身体指标、健康设备入口、隐私设置和账号操作。
- 实现个性化养护建议、健康内容和收藏能力。
- 建立 Core Data 离线持久化、同步边界、Keychain 安全存储及敏感数据保护规则。
- 建立与需求场景对应的单元、集成、UI 和性能测试基础。

## 能力范围

### 新增能力

- `app-shell-design-system`：应用入口、五 Tab 导航、品牌资源、深浅色设计令牌和通用组件。
- `health-dashboard`：活动环、步数、距离、心率、HealthKit 授权及健康数据聚合。
- `workout-management`：运动分类与搜索、快速开始、运动会话、手动录入和记录保存。
- `activity-history`：周期筛选、统计趋势、历史运动列表和路线摘要。
- `challenges-achievements`：挑战参与、进度、徽章、成就和排行榜展示。
- `account-health-profile`：登录状态、个人资料、身体指标、设备、隐私和账号设置。
- `wellness-guidance`：基于健康与运动数据生成养护建议、展示科普内容并支持收藏。
- `offline-data-security`：Core Data 离线存储、同步边界、Keychain 凭据和敏感数据保护。

### 修改能力

无。当前项目不存在已发布的 OpenSpec 主规范。

## 影响范围

- 新增 iOS/Xcode 工程、Swift 源码、资源目录和测试 Target。
- 使用 SwiftUI、Core Data、HealthKit、CoreLocation、MapKit、AuthenticationServices、Security 等 Apple 原生框架。
- 保持 Git 分支名称为 `main`，不引入未经设计评审的第三方依赖。
- 所有规划与说明文档使用中文；代码标识符遵循 `AGENTS.md` 并使用英文。
