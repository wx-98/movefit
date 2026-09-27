## 1. 契约与数据边界

- [x] 1.1 对照运行时 OpenAPI/后端接口文档，补充 Apple/微信/Google 社交身份、挑战、内容、帮助和工单的 DTO、领域模型与错误映射测试。
- [x] 1.2 在 Domain 定义可注入的社交身份、远端挑战、内容和支持 Repository 协议，并保持 DTO 不越过数据边界。

## 2. 后端 Repository

- [x] 2.1 扩展 BackendRepository 接入 Apple/微信/Google 社交登录、身份列表、绑定和解绑，复用 Keychain 会话与 Problem Details；绑定/解绑在后端幂等契约可用后以稳定键验证重试。
- [x] 2.2 接入挑战目录、详情、参与、退出、我的参与和隐私化排行榜，并以稳定操作 ID 提交写入。
- [x] 2.3 接入文章、收藏、帮助文章与工单 CRUD 范围内的正式 API，并实现分页与认证边界。

## 3. 平台授权与应用状态

- [x] 3.1 增加 Apple 授权码/nonce Adapter 和可替换的微信授权码 Adapter；未配置微信 SDK 时不得伪造授权码。
- [x] 3.2 先写失败测试，再实现 Google `ASWebAuthenticationSession` Adapter、PKCE S256、handoff、回调 state 校验和可配置允许的 redirect URI；取消/失败不得覆盖 Keychain 会话。
- [x] 3.3 在 AppModel 装配远端数据加载、登录后的刷新、写入状态和离线/未登录/服务端失败的降级。

## 4. 界面接入

- [x] 4.1 更新账户与绑定页面，支持 Apple/Google 登录、微信授权状态、三种 Provider 的身份绑定列表和解绑确认。
- [x] 4.2 更新挑战页面与详情，展示远端目录、参与状态、排行榜及明确的本地/远端来源。
- [x] 4.3 更新养护文章、帮助与支持页面，接入远端文章/收藏、帮助文章和本人支持工单操作。

## 5. 验证与文档

- [x] 5.1 为 Google 回调取消/state/PKCE 错误、OAuth 错误、认证写入、分页、幂等键、离线降级和敏感字段最小化补充单元测试与 UI 测试。
- [x] 5.2 更新中文 README、环境配置和真机验收清单，说明 Google OAuth/回调 URI、微信 SDK/Universal Link、后端幂等 change 及 worker 前置条件。
- [x] 5.3 运行 OpenSpec 严格校验、构建、单元/UI 测试及本地后端 smoke 测试，并修复发现的问题。
