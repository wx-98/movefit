## ADDED Requirements

### Requirement: 五个主导航界面
系统 MUST 使用固定五 Tab 展示首页、挑战、运动、历史和我的，并在应用重启后回到可用的默认首页。

#### Scenario: 首次进入应用
- **WHEN** 用户完成启动流程进入主界面
- **THEN** 系统展示首页，并允许用户在五个 Tab 之间切换

#### Scenario: 主界面下钻
- **WHEN** 用户从任一 Tab 打开详情、设置或运动会话
- **THEN** 系统保留当前 Tab，并在返回时恢复原页面状态

### Requirement: 统一设计系统
系统 MUST 使用语义化颜色、字体、间距、圆角和阴影令牌构建界面，Feature 不得重复硬编码同类视觉常量。

#### Scenario: 系统外观切换
- **WHEN** 用户在浅色与深色系统外观之间切换
- **THEN** 所有主页面和通用组件使用对应语义颜色并保持文字可读

### Requirement: 品牌与无障碍
系统 MUST 使用 MoveFit 品牌 Logo、SF Symbols 和本地资源，并为关键控件提供中文无障碍标签及动态字体支持。

#### Scenario: 使用大号动态字体
- **WHEN** 用户启用大号辅助字体
- **THEN** 核心数据和操作保持可见，文本不得被固定高度截断

#### Scenario: 离线加载界面
- **WHEN** 设备无网络连接
- **THEN** 应用图标、Logo、Tab 图标和基础界面仍可完整展示
