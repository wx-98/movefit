# Personal Health Management

## Purpose
定义 MoveFit iOS 客户端的 personal health management 行为。

## Requirements

### Requirement: 个人健康管理入口

系统 MUST 在首页提供症状记录、用药提醒、饮食与营养管理、检查记录入口；各入口 SHALL 展示用户主动录入的统计、趋势与明确非诊断性建议。

#### Scenario: 打开健康管理入口
- **WHEN** 用户点击首页任一健康管理入口
- **THEN** 系统进入对应详情页并展示数据来源、统计和空状态

### Requirement: 用药与症状安全提示

系统 MUST 允许用户记录症状和用药计划，但不得给出处方、疾病诊断或擅自修改剂量的建议。

#### Scenario: 记录不适症状
- **WHEN** 用户保存症状严重度和标签
- **THEN** 系统保存记录并以中性语言提示必要时咨询合格医疗专业人员
