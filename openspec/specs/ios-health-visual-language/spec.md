# Ios Health Visual Language

## Purpose
定义 MoveFit iOS 客户端的 ios health visual language 行为。

## Requirements

### Requirement: iOS 健康视觉语言

系统 MUST 使用系统语义表面、动态类型、SF Symbols、统一的分区标题和健康语义强调色构建所有主界面；Feature 不得在本地复制同类圆角、阴影或浅深色常量。

#### Scenario: 系统切换深色外观
- **WHEN** 用户切换至深色系统外观或选择深色外观偏好
- **THEN** 主界面表面、分隔线、主次文字和强调元素保持可读，并且不出现固定浅色背景

### Requirement: 健康数据阅读层级

系统 SHALL 在每个主 Tab 先展示一个与该页面目的相符的重点摘要，再按分区标题展示指标、行动或记录列表。

#### Scenario: 用户打开任一主 Tab
- **WHEN** 用户进入首页、挑战、运动、历史或我的
- **THEN** 用户可在首屏识别当前页面主题、最重要状态和下一步可操作入口
