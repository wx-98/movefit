## ADDED Requirements

### Requirement: 远端社交与内容写入安全
系统 MUST 为 Apple、微信、Google 身份绑定/解绑、挑战参与/退出、文章收藏和工单写入使用稳定操作 ID，并将其作为 `Idempotency-Key`；同一次操作重试 MUST 保持原请求与原键。社交登录会返回 token pair，不得将其当作可持久化重放的写入结果。系统不得在日志、持久化缓存、测试夹具或 UI 文案中暴露授权码、PKCE verifier、state、token、第三方 subject、工单正文或完整服务端响应。

#### Scenario: 写入请求重试
- **WHEN** 同一写入因超时或网络中断重试
- **THEN** 系统使用相同操作 ID 重放请求，并根据后端结果保持单一业务状态

#### Scenario: 社交认证失败
- **WHEN** 后端返回社交认证或 Provider 配置错误
- **THEN** 系统仅显示脱敏的稳定错误说明，且不创建或覆盖 Keychain 会话

#### Scenario: Google 绑定响应丢失
- **WHEN** Google 绑定完成请求成功但客户端未收到响应并以原键与原请求重试
- **THEN** 系统接受后端原始安全响应，刷新身份列表，不再次启动浏览器授权或持久化授权码
