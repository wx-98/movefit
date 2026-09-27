## ADDED Requirements

### Requirement: 主动健康记录最小化保存
系统 MUST 仅在本机保存用户主动录入的最小健康管理字段，并允许清理；不得保存 ECG 原始波形或将其写入日志。

#### Scenario: 清理健康管理记录
- **WHEN** 用户选择删除或清理记录
- **THEN** 系统删除目标本地记录且不影响 HealthKit 原始数据
