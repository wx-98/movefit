## MODIFIED Requirements

### Requirement: 账户入口与会话状态
系统 SHALL 提供手机号、邮箱、Apple ID、微信和 Google 登录入口，并允许未配置远程认证时以本地模式体验非账号依赖功能。Apple、微信或 Google 授权成功后，系统 MUST 将服务端返回的 token pair 安全保存到 Keychain；认证失败、用户取消、Provider 未配置或 iOS 尚不能获取授权码时，系统 MUST 展示明确状态，不得伪造真实登录成功。

#### Scenario: 使用 Apple ID 登录
- **WHEN** 用户完成 Apple 授权且认证服务可用
- **THEN** 系统使用授权码、nonce 与设备 ID 调用正式后端并在成功后建立安全会话

#### Scenario: 使用微信登录
- **WHEN** 微信授权码适配器提供有效授权码且认证服务可用
- **THEN** 系统调用正式微信登录 API 并在成功后建立安全会话

#### Scenario: 使用 Google 登录
- **WHEN** 用户通过系统浏览器完成 Google 授权且回调 state、PKCE 与服务端配置有效
- **THEN** 系统向正式后端完成 Google 登录并仅在收到有效 token pair 后建立 Keychain 会话

#### Scenario: 取消 Google 授权
- **WHEN** 用户取消系统浏览器中的 Google 授权
- **THEN** 系统丢弃本次临时授权上下文且不创建或覆盖已有会话

#### Scenario: 远程认证未配置
- **WHEN** 用户选择需要服务端或第三方配置的登录方式
- **THEN** 系统展示后端或授权码适配器返回的明确不可用说明，不得伪造真实登录成功

### Requirement: 社交身份绑定与解绑
已登录用户 MUST 能读取 Apple、微信与 Google 身份的绑定状态，并通过正式后端绑定或解绑身份；绑定/解绑 MUST 对同一次操作使用稳定的 `Idempotency-Key`。解绑最后一个可登录身份或身份冲突时，系统 MUST 显示后端稳定错误码对应的用户文案且保留当前会话。

#### Scenario: 绑定社交身份
- **WHEN** 已登录用户完成某 Provider 授权且服务端返回绑定成功
- **THEN** 系统刷新绑定列表并展示脱敏提示与绑定时间

#### Scenario: 解绑最后一个可登录身份
- **WHEN** 用户尝试解绑服务端判定的最后一个可登录身份
- **THEN** 系统不更新界面状态并说明该身份不能解绑

#### Scenario: 绑定 Google 身份
- **WHEN** 已登录用户完成后端 Google handoff 授权且绑定请求成功
- **THEN** 系统使用稳定操作 ID 提交绑定并刷新包含 Google 的脱敏身份列表，不替换当前会话
