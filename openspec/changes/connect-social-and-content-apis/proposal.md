## Why

主业务后端现已实现 Apple/微信身份、挑战、文章、帮助与工单等正式 API，而 iOS 端仍将其中多项标记为“未配置”或仅使用本地内容，导致已部署的能力无法被用户使用，也无法可靠反映服务端失败状态。

## What Changes

- 接入后端的 Apple/微信/Google 社交身份会话、身份列表、绑定与解绑 API；Google 使用系统浏览器授权与服务端 authorization handoff/PKCE，不引入 Google SDK。在 iOS 无法取得第三方授权码或服务端 Provider 未配置时，显示可操作但不伪造成功的状态。
- 将挑战目录、参与状态、参与/退出与排行榜从本地模板扩展为优先读取主后端，并在离线、未登录或远端无数据时保持明确的本地边界。
- 接入已发布文章、收藏、帮助文章与用户工单 API，保留网络不可用时的已缓存或随包基础内容。
- 将支持幂等的受保护写操作经由稳定操作 ID 和 `Idempotency-Key` 提交，并映射后端的 Problem Details 稳定错误码；社交登录返回 token pair，不参与响应重放。

## Capabilities

### New Capabilities

- `remote-support`: 通过已认证后端浏览帮助文章、创建/查看/回复/关闭本人支持工单。

### Modified Capabilities

- `account-health-profile`: 社交登录、账号绑定和解绑改为调用正式后端 API，并展示真实配置与认证状态。
- `challenges-achievements`: 挑战目录、参与状态和隐私化排行榜优先使用正式后端，保留离线本地体验边界。
- `wellness-guidance`: 已发布文章、文章详情和收藏优先使用正式后端，并处理离线降级与认证写入。
- `offline-data-security`: 为社交身份、挑战参与、收藏和工单写入扩展幂等重试与隐私保护边界。

## Impact

- 影响 `Domain` Repository 协议与 DTO/领域模型、`Data/Networking/BackendRepository`、Keychain 会话、Google 系统浏览器授权 Adapter、`AppModel` 和“挑战/我的/养护”页面。
- 依赖已运行的主业务后端 `/api/v1`；社交绑定/解绑的可靠重试还依赖后端 `add-social-identity-write-idempotency` change。Google 实际登录需要服务端 Provider 配置及经允许的回调 URI；不新增第三方 iOS SDK。微信授权码获取会以可替换适配器预留，待接入方提供微信开放平台 SDK/Universal Link 配置后启用。
