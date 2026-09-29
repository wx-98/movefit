## MODIFIED Requirements

### Requirement: 双后端环境配置

系统 MUST 从构建配置读取主业务服务、动作目录服务和 AI 服务的基础地址，业务实现不得硬编码环境地址；Debug SHALL 默认连接本机服务，并能以构建参数覆盖为 staging HTTPS 地址；Release MUST 使用可独立覆盖的 production HTTPS 地址，并拒绝占位、环回、局域网和明文 HTTP 地址。

#### Scenario: 模拟器连接本机服务
- **WHEN** 使用默认 Debug 配置启动 App
- **THEN** 主业务请求发送到 `http://127.0.0.1:8000`，动作请求发送到 `http://127.0.0.1:8001`，AI 请求发送到 `http://127.0.0.1:8002`

#### Scenario: 真机连接 staging
- **WHEN** 使用明确指定的 staging 构建参数安装真机 App
- **THEN** 三个服务均连接相应 staging HTTPS 域名，且无需修改 Swift 业务代码

#### Scenario: 切换上线环境
- **WHEN** 使用 Release 配置构建 App
- **THEN** 三个服务使用可覆盖的 production HTTPS 地址，且无 `.invalid` 占位值或开发者局域网地址

#### Scenario: Release 地址不安全
- **WHEN** Release 配置中任一服务地址为明文 HTTP、环回、局域网或占位域名
- **THEN** 构建或启动配置校验明确失败，不静默回退到本机地址
