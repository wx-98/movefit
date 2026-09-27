## ADDED Requirements

### Requirement: 邮箱与手机号验证码注册
系统 SHALL 通过主业务后端完成邮箱或手机号的验证码 challenge、确认和密码注册流程。客户端 MUST NOT 直接调用邮件或腾讯云短信供应商，MUST NOT 要求用户输入 `verification_proof`，并 MUST 仅将确认接口返回的一次性 proof 用于同一规范化标识符的紧接注册请求。

#### Scenario: 请求手机号注册验证码
- **WHEN** 用户输入合法 E.164 手机号并请求注册验证码
- **THEN** 客户端向 MoveFit 后端提交 `phone` channel、手机号和稳定的非 PII installation ID，收到 `202` 后进入六位验证码输入状态，且不直接调用腾讯云

#### Scenario: 请求邮箱注册验证码
- **WHEN** 用户输入合法邮箱并请求注册验证码
- **THEN** 客户端向同一 MoveFit challenge API 提交 `email` channel，并以与手机号相同的响应状态进入验证码输入流程

#### Scenario: 输入不合法
- **WHEN** 邮箱、E.164 手机号、密码或验证码不满足客户端可判定的格式约束
- **THEN** 客户端在本地显示字段错误且不发送对应网络请求

#### Scenario: 投递通道不可用
- **WHEN** 后端返回 `verification_delivery_unavailable`
- **THEN** 客户端显示验证码服务暂不可用和稍后重试建议，不展示发送成功，不生成本地 proof，且密码登录保持可用

### Requirement: 验证码确认与一次性注册
系统 MUST 使用 challenge ID、六位验证码和原请求的 installation ID 确认验证码。确认成功后，客户端 MUST 在内存中立即使用返回的 `verification_proof` 为同一账号类型、规范化标识符和当前密码提交注册，并在完成或失败后清除验证码、challenge 和 proof。

#### Scenario: 验证并注册成功
- **WHEN** 用户在 challenge 有效期内提交正确验证码且注册请求成功
- **THEN** 客户端只使用一次返回的 proof 完成注册，显示成功状态，返回登录流程并预填已注册标识符

#### Scenario: 验证码无效或已失效
- **WHEN** 后端返回 `verification_code_invalid`
- **THEN** 客户端显示统一的验证码无效提示，不推断错误、过期、锁定或重放的具体原因，不提交注册请求

#### Scenario: 注册 proof 被拒绝
- **WHEN** 后端返回 `registration_verification_invalid`
- **THEN** 客户端清除 proof 与旧 challenge，要求用户重新请求验证码，且不得自动重放 proof

#### Scenario: 标识符在流程中改变
- **WHEN** 用户在已请求 challenge 后切换账号类型或修改规范化标识符
- **THEN** 客户端取消进行中的旧请求、清除旧 challenge/验证码/proof，并要求为新标识符重新发送验证码

#### Scenario: 并发响应迟到
- **WHEN** 已取消或已被新请求替代的 challenge 响应随后到达
- **THEN** 客户端丢弃迟到响应，不得覆盖当前输入或触发注册

### Requirement: 验证码限流与重发
系统 MUST 根据后端稳定错误码和 `Retry-After` 控制验证码请求及确认重试，并 SHALL 使用绝对截止时间呈现冷却状态。客户端 MUST 防止重复点击产生并发发送或确认请求。

#### Scenario: 发送进入冷却
- **WHEN** challenge 请求成功并返回可接受响应
- **THEN** 客户端禁用重复发送直至本地冷却截止，同时允许用户输入和提交验证码

#### Scenario: 服务端限流
- **WHEN** challenge 请求或确认返回 `429 auth_rate_limited` 和合法 `Retry-After`
- **THEN** 客户端在截止前禁用相应操作、显示剩余等待时间，并在 App 恢复前台后按绝对时间重算

#### Scenario: Retry-After 缺失或非法
- **WHEN** 服务端返回限流但没有可解析的 `Retry-After`
- **THEN** 客户端采用保守的本地冷却并显示通用稍后重试提示，不持续高频重试

### Requirement: 注册敏感数据保护
客户端 MUST NOT 将验证码、verification proof、密码、完整邮箱、完整手机号或腾讯云凭据写入日志、分析事件、崩溃上下文、Core Data、UserDefaults 或源码。proof MUST 只在当前注册调用链内存活；installation ID MUST 为随机的非 PII 值并安全保存。

#### Scenario: 注册流程被诊断或中断
- **WHEN** 注册请求失败、任务取消、App 进入后台或诊断日志被检查
- **THEN** 日志和持久化中不存在验证码、proof、密码、完整联系方式或供应商秘密，当前敏感流程状态按生命周期规则清除

#### Scenario: App 需要 installation ID
- **WHEN** 客户端首次请求验证码且尚无 installation ID
- **THEN** 客户端生成随机 UUID、保存到 Keychain 并复用于 request/confirm，不从广告标识符、设备序列号或联系方式派生
