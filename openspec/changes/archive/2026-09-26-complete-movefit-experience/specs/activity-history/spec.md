## MODIFIED Requirements

### Requirement: 周期筛选与聚合
系统 MUST 支持周、月、六个月和年四种周期，并使用 HealthKit 日趋势与合并运动记录按当前日历和时区计算总量、日均、有效天数和同期变化。

#### Scenario: 切换到月视图
- **WHEN** 用户将历史周期从周切换为月
- **THEN** 系统查询对应 HealthKit 日期范围并更新真实步数、热量趋势和运动列表

### Requirement: 历史运动列表
系统 MUST 合并 Core Data 与 HealthKit 的运动，使用来源和稳定 ID 去重，按开始时间倒序展示类型、来源、时间、时长、距离和能量，并支持进入详情。

#### Scenario: 读取 Apple 设备运动
- **WHEN** HealthKit 返回 iPhone、Apple Watch 或其他已同步来源的运动样本
- **THEN** 历史列表展示所有可读取且支持映射的运动，并标记 Apple 健康来源

#### Scenario: 新记录出现在历史中
- **WHEN** 用户完成或手动添加一条运动记录
- **THEN** 历史列表在刷新后展示该记录且不产生相同来源 ID 的重复项

## ADDED Requirements

### Requirement: 运动详情
系统 SHALL 为历史记录展示来源、时间、时长、距离、能量和可用路线，并对缺失字段提供明确空态。

#### Scenario: 查看 HealthKit 运动详情
- **WHEN** 用户点击来自 Apple 健康的运动
- **THEN** 系统展示可读取摘要和来源说明，不虚构不可读取的路线或分段数据
