## MODIFIED Requirements

### Requirement: 健康权限按需申请
系统 MUST 在设备支持 HealthKit 时按功能申请步数、步行跑步距离、活动能量、锻炼分钟、站立小时、心率和静息心率的最小读取权限，并允许用户在未连接时继续使用非健康功能。

#### Scenario: 用户授权健康数据
- **WHEN** 用户主动连接 Apple 健康并完成系统授权
- **THEN** 系统查询真实 HealthKit 样本、刷新首页摘要并标明数据来自 Apple 健康

#### Scenario: 健康数据不可用
- **WHEN** HealthKit 不可用、没有样本或读取范围受限
- **THEN** 系统展示中性的不可用或暂无数据状态，不得用演示数值替代，也不得断言用户拒绝了读取权限

### Requirement: 每日健康概览
系统 SHALL 使用当前 Calendar、TimeZone 和当前时间聚合 HealthKit 当日真实样本，并展示活动环、活动能量、运动分钟、站立时长、步数、距离、当前心率和静息心率的可用子集。

#### Scenario: 加载当日摘要
- **WHEN** 用户打开首页、完成授权或主动刷新
- **THEN** 系统按本地日历的当日边界查询并聚合真实样本，使用本地化单位展示且不持久化原始 HealthKit 样本

#### Scenario: 部分指标缺失
- **WHEN** 当日只有部分 HealthKit 指标存在
- **THEN** 系统展示存在的真实指标，并将缺失指标显示为不可用而不是数值零
