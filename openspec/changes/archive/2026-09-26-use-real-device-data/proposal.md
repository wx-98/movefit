## Why

当前默认运行链路仍使用模拟健康摘要、示例路线和进程内挑战/收藏状态，用户即使在真机授权后也无法看到设备真实数据。现在需要在不依赖 MoveFit 服务端的前提下，将可由 Apple 平台或本地存储提供的数据切换为真实来源，并对无权限、无样本和模拟器环境提供明确降级。

## What Changes

- 默认健康数据源切换为 HealthKit，真实聚合步数、距离、活动能量、锻炼分钟、站立小时、心率和静息心率。
- 首页区分未请求、未授权、无样本、不可用和读取失败，不再用演示数值替代真实健康数据。
- 户外运动会话接入 CoreLocation，实时记录路线和距离；室内或未授权时继续记录真实时长。
- 运动记录、挑战参与、文章收藏和隐私偏好使用 Core Data 持久化，并从本地真实运动/健康摘要计算可支持的挑战进度和养护建议。
- 账号、排行榜和远程内容继续保留“需要服务端”或“演示数据”标识，不伪造真实服务能力。
- 增加 HealthKit 查询、定位会话、本地状态持久化和降级路径测试，并更新中文 README 与真机验收说明。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `health-dashboard`: 默认使用 HealthKit 真实数据，并明确权限、无样本和不可用状态。
- `workout-management`: 户外运动使用真实定位点和距离，未授权时保留时长记录能力。
- `challenges-achievements`: 挑战参与状态持久化，并优先使用真实本地健康或运动数据计算进度。
- `wellness-guidance`: 收藏状态持久化，养护建议基于真实可用摘要生成。
- `offline-data-security`: 扩展本地状态持久化范围并保持幂等、可清理和隐私边界。

## Impact

- 影响 `AppModel`、依赖组装、HealthKit/CoreLocation Adapter、Core Data 模型、运动会话、首页、挑战、养护和设置页面。
- 不新增第三方依赖，不新增 HTTP、REST 或 GraphQL API。
- 真机需要 HealthKit 与使用期间定位权限；模拟器或无数据设备显示真实空态，不回退为伪造健康数值。
- 账号认证、排行榜和远程内容仍不在本变更范围内。
