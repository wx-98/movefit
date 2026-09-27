## Context

MoveFit 当前使用自定义颜色与卡片，已具备首页、挑战、运动、历史、我的五个功能完整的 Tab，但不同页面的标题密度、表面层级和指标卡样式不一致。`example/home.html`、`example/challenges.html`、`example/wokouts.html` 提供了彩色内容密度与信息分区参考；本次以 iPhone 健康 App 的大标题、分组表面、健康语义色、图表与数据优先级为最终基线。

最低系统为 iOS 15，必须保持 SwiftUI、无第三方依赖、深色模式、动态字体和 VoiceOver 支持。数据源、导航目的地、HealthKit 权限和本地持久化均不能因视觉改版变化。

## Goals / Non-Goals

**Goals:**

- 建立以系统语义色为基础、由 MoveFit 健康色点缀的 Token 与可复用组件。
- 让每个页面在一屏内突出一个主要健康问题：今日状态、挑战行动、训练选择、历史回顾、个人账户。
- 使用原生 `NavigationView`、`TabView`、`List`/分组容器、SF Symbols 和可缩放排版，提供接近 Apple 健康 App 的阅读节奏。
- 保持既有按钮标识符、导航与数据/隐私文案可测试。

**Non-Goals:**

- 不复制 Apple 专有资产、字体、动效或界面截图。
- 不新增 Figma 云端文件、第三方 UI 库、后端 API 或 HealthKit 权限。
- 不变更领域模型、统计规则、挑战目录或已定义的五 Tab 信息架构。

## Decisions

### 使用语义表面而非固定浅色卡片

Design System 采用 `Color(.systemGroupedBackground)`、`Color(.secondarySystemGroupedBackground)`、`Color(.tertiarySystemFill)` 与主/次标签色，品牌健康色仅作为图标、数据与进度强调。这样会随系统浅深色切换，优于将参考稿的网页十六进制颜色直接移植到 SwiftUI。

### 采用“标题—重点卡—分区列表”的健康阅读结构

五个页面均保留大标题，再按重要性组织 1 个重点摘要卡、横向可滑动内容或指标网格、带标题的列表分区。首页仍以活动圆环为视觉中心；挑战和运动保留鲜艳的内容封面，但用统一的圆角、标签与进度条控制密度。

### 将重复视觉行为收敛到 Design System

新增分区标题、健康指标卡、胶囊标签、浅色强调表面和紧凑列表行等通用组件。Feature 只传入标题、图标、语义色和内容，避免页面自行复制圆角、阴影和间距常量。

### 以 SwiftUI 原生可访问性替代固定画布布局

图表使用现有 SwiftUI `Path`/`GeometryReader`，卡片避免固定文本高度；大号动态字体时指标由横排自动换为纵向或缩放最小值。SF Symbols 按名称使用，并保留/补充可访问标签。

## Risks / Trade-offs

- [参考网页使用 Web 字体和固定宽度] → 使用系统动态字体与可伸缩 SwiftUI 布局，只借鉴层级、配色和内容组织。
- [鲜艳封面影响健康数据可读性] → 只在挑战/训练等行动导向卡片使用渐变，数据页面使用系统表面与单一语义强调色。
- [共享组件改动影响多个页面] → 保持现有数据、按钮 ID 和导航目的地，先补组件单元/界面入口回归再逐页替换。
- [动态字体导致网格拥挤] → 指标组件提供自适应列数或纵向降级，文本使用 `minimumScaleFactor` 仅作为最后手段。

## Migration Plan

1. 先增加可共存的语义 Token 和组件，不移除现有数据接口。
2. 分别替换首页、挑战/运动、历史/我的的视觉容器和层级。
3. 在浅色、深色、辅助大字体和 VoiceOver 下验证五个 Tab。
4. 若出现视觉或可访问性回归，可保留数据与导航逻辑并回退对应 View 的展示层提交。

## Open Questions

- 无。用户已指定以 Apple 健康风格为主、`example/` 为内容色彩参考；本次不创建额外 Figma 云端设计文件。
