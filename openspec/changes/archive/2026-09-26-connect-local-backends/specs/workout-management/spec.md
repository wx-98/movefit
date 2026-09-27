## ADDED Requirements

### Requirement: 服务端运动记录同步
系统 MUST 在恢复有效会话后分页读取服务端运动记录，并与 Core Data 和 HealthKit 记录按稳定标识及来源合并，不得遗漏后续游标页面或重复展示同一条记录。

#### Scenario: 读取多页运动历史
- **WHEN** 服务端运动列表返回下一页游标
- **THEN** 系统继续请求直至游标为空，并一次性发布合并后的历史状态

#### Scenario: 历史服务不可达
- **WHEN** 服务端运动请求失败
- **THEN** 系统仍展示 Core Data 与 HealthKit 记录，并明确远程历史未加载

### Requirement: 本地优先上传运动记录
系统 MUST 先保存用户在 MoveFit 完成或手动添加的运动，再为主后端支持的运动类型创建服务端记录；远程失败不得回滚或丢失本地记录。

#### Scenario: 保存受支持运动
- **WHEN** 已登录用户完成 running、walking、cycling、yoga、strength 或 hiit 运动
- **THEN** 系统使用稳定运动 ID 和幂等键创建服务端记录，并在成功后标记已同步

#### Scenario: 保存后端未支持的运动类型
- **WHEN** 用户保存拉伸等当前后端枚举不支持的运动
- **THEN** 系统保留本地记录并显示“当前服务端不支持该类型”，不得发送伪造类型

#### Scenario: 设备健康记录存在
- **WHEN** HealthKit 返回设备运动样本
- **THEN** 系统展示真实设备数据，但未经明确上传策略不得自动批量写入服务端

