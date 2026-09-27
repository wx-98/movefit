## ADDED Requirements

### Requirement: 离线可用与持久化
系统 MUST 在无网络时允许查看已缓存数据、完成运动和手动录入，并在应用重启后保留未同步操作。

#### Scenario: 离线完成运动
- **WHEN** 用户在无网络环境结束运动
- **THEN** 系统本地保存记录并创建具有稳定 ID 的待同步操作

### Requirement: 幂等同步边界
系统 MUST 使用稳定操作 ID 提交离线变更，并能安全重试而不创建重复运动或收藏。

#### Scenario: 同步请求重复执行
- **WHEN** 同一离线操作因超时被再次提交
- **THEN** Repository 将其视为同一操作并保持单一业务结果

### Requirement: 凭据与敏感数据保护
系统 MUST 将访问令牌存入 Keychain，禁止在日志、UserDefaults、源码和测试夹具中保存真实凭据或健康隐私数据。

#### Scenario: 记录诊断日志
- **WHEN** 网络、HealthKit 或持久化操作失败
- **THEN** 系统只记录脱敏错误类别和追踪标识，不记录身份、位置、健康值或令牌

### Requirement: 最小化健康数据副本
系统 MUST 只持久化功能必需的健康摘要或 App 自有记录，并为缓存提供明确清理策略。

#### Scenario: 用户清理健康缓存
- **WHEN** 用户触发隐私设置中的本地健康缓存清理
- **THEN** 系统删除可重建缓存，但不删除 HealthKit 中由其他来源拥有的数据
