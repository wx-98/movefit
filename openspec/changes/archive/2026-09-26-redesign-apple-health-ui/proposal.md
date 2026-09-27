## Why

当前界面虽然具备完整功能，但视觉层级、留白、数据卡片和图表语言与 `example/` 参考稿及 iPhone 健康 App 的原生体验不一致，健康数据的优先级也不够清晰。现在需要在不改变真实数据、权限和本地优先边界的前提下，建立一致且更易扫读的 iOS 健康视觉体验。

## What Changes

- 重建全局设计令牌，采用 iOS 语义色、动态表面、分组列表、圆角、阴影和排版层级。
- 重新组织首页：以今日概览、活动圆环、重点指标、趋势和健康管理为清晰的数据阅读路径。
- 重绘挑战、运动、历史、我的五个主界面及其核心卡片，使每个 Tab 有独立但一致的健康视觉重点。
- 统一图表、指标卡、分区标题、列表行、状态卡和空状态，支持浅色/深色与动态字体。
- 保持现有导航、数据来源、HealthKit 权限、后端接口、Core Data 和无障碍语义不变。

## Capabilities

### New Capabilities

- `ios-health-visual-language`: 定义符合 iOS 健康信息阅读习惯的跨页面视觉令牌、卡片、图表与无障碍规则。

### Modified Capabilities

- `app-shell-design-system`: 调整五个主界面及共享组件的视觉和布局要求。
- `health-dashboard`: 调整首页健康摘要、活动圆环和指标入口的视觉层级。
- `challenges-achievements`: 调整挑战浏览、筛选和进度展示的视觉组织。
- `workout-management`: 调整运动目录、训练卡片和快速开始的视觉组织。
- `activity-history`: 调整历史汇总、图表和记录列表的视觉组织。
- `account-health-profile`: 调整个人资料、设置和支持入口的视觉组织。

## Impact

- 影响 `MoveFit/DesignSystem/`、五个主 Tab 的 SwiftUI View 与关键详情页。
- 不新增第三方依赖，不调整网络 API、领域模型或存储结构。
- 需要补充深色模式、动态字体、VoiceOver 及关键导航的视觉回归测试。
