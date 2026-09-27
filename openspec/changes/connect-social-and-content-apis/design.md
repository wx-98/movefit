## Context

主业务后端已在 `/api/v1` 提供 Apple/微信/Google 社交身份、挑战、文章、帮助和工单接口，iOS 现有 `BackendRepository` 只接入密码认证、资料、运动与客户端配置；挑战、文章和帮助仍以本地数据为主。Google 后端暴露 authorization handoff、登录完成与绑定完成 API。项目最低支持 iOS 15、SwiftUI、Core Data，且不得把 DTO 或平台 SDK 类型传入界面或领域层。

## Goals / Non-Goals

**Goals:**

- 以 Repository 协议隔离正式后端的 Apple/微信/Google 社交身份、挑战、内容和支持 API，并复用既有 Bearer、刷新与 Problem Details 处理。
- 让界面真实呈现远端数据、身份绑定状态和稳定错误码；无网、未登录、后端未发布数据时有明确降级。
- 对后端支持的每个可重试写请求传入稳定 `Idempotency-Key`；社交登录完成不做 token pair 响应重放。不记录授权码、token、工单正文或健康数据。

**Non-Goals:**

- 不新增微信 iOS SDK、Universal Link 或第三方依赖；微信授权码来源通过协议预留。
- 不实现后端未暴露的运营、发布、客服回复、附件、账号注销或真实 Provider sandbox 自动化。
- 不把 HealthKit 原始数据、路线、授权码或第三方 token 上传到上述接口。

## Decisions

### 通过领域协议并扩展 BackendRepository 接入

新增 `SocialIdentityProviding`、`ChallengeRemoteProviding`、`ContentProviding` 和 `SupportProviding`，由 `BackendRepository` 实现。领域层使用英文模型和单位明确的值；DTO 只保留在 Networking。这样沿用现有会话刷新、分页和错误映射，优于在 SwiftUI 直接请求 URLSession。

### 社交授权码采用可替换 Adapter

Apple 使用系统 `AuthenticationServices` 产生授权码与 nonce；微信定义 `SocialAuthorizationCodeProviding`，当前没有接入 SDK 时返回可识别的不可用状态。Google 使用 `ASWebAuthenticationSession` 打开后端 handoff 返回的 `authorization_url`：客户端产生加密随机 `code_verifier` 和 S256 `code_challenge`，以经允许的 `redirect_uri`、稳定设备 ID 和 challenge 请求 handoff；回调仅提取并核对 `code`、`state`，再向后端提交 `authorization_code`、`state`、`code_verifier`、`redirect_uri` 和设备 ID。回调 URI 的 iOS 注册和服务端允许列表属于部署前置条件。用户取消或 Provider 失败不覆盖已有 Keychain 会话。替代方案是将授权码文本框暴露给用户或引入 Google/微信 SDK；前者不安全且体验差，后者增加产品配置与依赖审查，因此不采用。

### 绑定/解绑的稳定操作 ID 与后端顺序

Apple、微信、Google 绑定及解绑使用一次用户操作一个稳定 UUID；传输失败重试复用原 `Idempotency-Key` 和原始请求，新的用户操作使用新键。Google 绑定完成必须由后端在重用 state 前命中幂等记录。该能力依赖后端 `add-social-identity-write-idempotency` change 完成并部署；客户端在此之前不得宣称 Google/社交绑定具备可靠重试。社交登录返回 token pair，不能持久化作为幂等响应。

### 远端优先，离线本地边界明确

公开读取（挑战/文章/帮助）远端成功后展示远端版本；网络失败时仅显示已审核随包内容或已缓存状态，并明确数据来源。挑战参与、收藏、工单、绑定/解绑均需登录；远端成功后再更新本地状态，失败不得显示成功。

### 客户端不重算服务器挑战与排行榜

用户参与状态和排行榜以服务端 Challenge worker 的结果为准；本地挑战模板继续作为无远端目录时的离线体验，不伪装为服务器进度。排行榜仅展示服务端 `Mover-` 别名和 `is_current_user`，不引入用户 ID。

## Risks / Trade-offs

- [微信无法取得授权码] → 以明确不可用状态和可替换协议发布；接入微信开放平台 SDK、App ID、Universal Link 后只替换 Platform Adapter。
- [后端 Provider 未配置或临时失败] → 映射 `social_provider_unavailable`、`social_provider_temporary_failure`，不创建本地会话。
- [Google 回调 URI 未被 iOS 或服务端允许] → 配置校验与真机验收；失败时展示明确不可用状态，不使用测试回调替代。
- [Google 授权被取消或 state/PKCE 不匹配] → 丢弃本次临时授权上下文，不调用成功路径，不改变既有 Keychain 会话。
- [挑战 worker 未部署] → 显示服务端返回的最后进度，不在客户端猜测已完成。
- [远端内容为空或离线] → 保留本地基础文章/帮助与来源说明；收藏/工单写入不做假成功。
- [重复写入] → 所有后端支持的写接口使用稳定 UUID 操作 ID 映射为 `Idempotency-Key`；社交写入在后端幂等 change 部署后才视为完成可靠重试。

## Migration Plan

1. 保留现有密码登录和本地挑战/内容，不破坏离线数据。
2. 先部署后端社交写入幂等 change，再发布远端读取与社交身份/写入；Debug 使用已有可配置后端地址。
3. 若远端异常，关闭运行时入口或回退到本地公开内容；Keychain 会话和 Core Data 本地记录不删除。

## Open Questions

- 部署方何时提供微信开放平台 App ID、SDK 合规审查与 Universal Link？在此之前微信 UI 只能报告授权码提供方不可用。
- Google OAuth 客户端、回调 URI 的服务端允许列表与 iOS URL scheme/Universal Link 何时完成配置？在此之前 Google UI 只能显示配置未就绪，不得伪造登录。
- 后端是否会在客户端配置中发布内容/挑战开关与 AI 权益；若会，后续应将开关加入版本化配置 DTO。
