## ADDED Requirements

### Requirement: 双后端环境配置
系统 MUST 从构建配置读取主业务服务与动作目录服务的基础地址，业务实现不得硬编码环境地址；Debug SHALL 默认连接本机服务，Release MUST 可独立覆盖为 HTTPS 地址。

#### Scenario: 模拟器连接本机服务
- **WHEN** 使用默认 Debug 配置启动 App
- **THEN** 主业务请求发送到 `http://127.0.0.1:8000`，动作请求发送到 `http://127.0.0.1:8001`

#### Scenario: 切换上线环境
- **WHEN** 发布构建覆盖两个服务的 Release 地址
- **THEN** App 不修改 Swift 代码即可请求新的 HTTPS 服务地址

### Requirement: 统一请求与错误边界
系统 MUST 统一编码请求、解码 JSON 和 Problem Details 错误，并向 Domain 返回可判别错误；不得把令牌、健康指标或完整响应写入日志。

#### Scenario: 服务端返回校验错误
- **WHEN** 服务端返回包含机器错误码的 Problem Details
- **THEN** Repository 保留错误类别并由 UI 映射为中文可恢复提示

#### Scenario: 返回无法识别的数据
- **WHEN** 响应字段缺失或枚举值不受支持
- **THEN** 系统返回明确解码或映射失败状态，不得静默构造伪数据

### Requirement: 安全会话与令牌刷新
系统 MUST 将访问令牌和刷新令牌保存于 Keychain，并在受保护请求首次收到未授权响应时刷新令牌并最多重试一次。

#### Scenario: 访问令牌过期
- **WHEN** 受保护请求返回 401 且刷新令牌有效
- **THEN** 系统更新旋转后的令牌并重放原请求一次

#### Scenario: 刷新失败
- **WHEN** 刷新令牌无效或重试请求仍返回 401
- **THEN** 系统清除安全会话并要求用户重新登录，不得无限重试

### Requirement: 服务能力可观测
系统 SHALL 请求主服务健康或客户端配置接口，并分别展示已连接、不可达和后端未提供接口的状态。

#### Scenario: 客户端配置可用
- **WHEN** `/api/v1/client-config` 返回有效修订版
- **THEN** 系统记录修订号和配置值，但不得在语义不明确时关闭整个 App

