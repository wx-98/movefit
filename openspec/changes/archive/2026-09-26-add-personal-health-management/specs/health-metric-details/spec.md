## ADDED Requirements

### Requirement: ECG 历史波形
系统 SHALL 在用户授权且 HealthKit 提供 ECG 样本时展示选中历史记录的电压波形；原始采样仅在内存中使用，且系统 MUST 明确其不构成诊断。

#### Scenario: 读取 ECG 波形
- **WHEN** 用户选择一条可读取的 ECG 历史摘要
- **THEN** 系统通过 HealthKit 查询展示对应波形或显示真实不可用状态
