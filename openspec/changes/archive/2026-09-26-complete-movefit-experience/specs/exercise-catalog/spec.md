## ADDED Requirements

### Requirement: 训练方案目录
系统 MUST 按跑步、步行、骑行、力量、瑜伽和 HIIT 展示可离线浏览的细分训练方案，每项包含目标、难度、时长、适用人群、步骤和安全提示。

#### Scenario: 查看跑步训练
- **WHEN** 用户点击跑步分类
- **THEN** 系统展示五公里、减脂跑、间歇冲刺等方案并允许进入详情

### Requirement: 动作目录后端边界
系统 MUST 通过 `ExerciseCatalogProviding` 获取版本化动作目录，并支持分页、搜索、器械、肌群和难度过滤；View 不得依赖上游 GitHub JSON 字段或 URL。

#### Scenario: 动作服务未配置
- **WHEN** 用户打开动作库且后端实现不可用
- **THEN** 系统展示本地基础动作与明确的服务端接入状态，不得伪造远程同步

#### Scenario: 后端返回动作
- **WHEN** Repository 成功映射版本化动作 DTO
- **THEN** 系统展示动作名称、器械、难度、肌群、分步指导和内容来源版本

### Requirement: 动作内容安全
系统 MUST 展示动作风险提示，并要求远程内容在发布前完成中文化、去重、安全审核和媒体许可确认。

#### Scenario: 查看动作详情
- **WHEN** 用户进入任一动作详情
- **THEN** 系统展示标准步骤、安全提示和“如有疼痛立即停止”的非医疗声明
