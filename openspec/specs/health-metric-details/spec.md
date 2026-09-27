# Health Metric Details

## Purpose
定义 MoveFit iOS 客户端的 health metric details 行为。

## Requirements

### Requirement: 健康指标详情

系统 MUST 为步数、距离、当前心率和静息心率提供详情页，展示所选周期的趋势、统计摘要、数据来源与最后更新时间；详情不得把缺少数据解释为用户拒绝授权。

#### Scenario: 查看步数详情
- **WHEN** 用户从首页打开步数详情
- **THEN** 系统展示日趋势、平均值、累计值和可用的同比较结论

### Requirement: 心电图记录摘要与安全边界

系统 MUST 仅在 HealthKit 可读取 ECG 记录时展示其时间、分类和可用摘要；系统不得声明诊断结果、疾病或治疗方案，并必须在无法读取时说明数据不可用原因。

#### Scenario: 存在可读取 ECG 记录
- **WHEN** 用户打开心率详情且 HealthKit 返回 ECG 分类记录
- **THEN** 系统显示记录摘要、数据来源和非诊断安全声明

#### Scenario: ECG 不可用
- **WHEN** 设备、权限或数据不支持 ECG 读取
- **THEN** 系统展示不可用状态和可执行的授权或设备说明

### Requirement: ECG 历史波形

系统 SHALL 在用户授权且 HealthKit 提供 ECG 样本时展示选中历史记录的电压波形；原始采样仅在内存中使用，且系统 MUST 明确其不构成诊断。

#### Scenario: 读取 ECG 波形
- **WHEN** 用户选择一条可读取的 ECG 历史摘要
- **THEN** 系统通过 HealthKit 查询展示对应波形或显示真实不可用状态
