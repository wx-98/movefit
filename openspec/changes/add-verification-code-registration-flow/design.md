## Context

`LocalAccountView` 目前让用户手工填写 `verification_proof`，`AuthenticationProviding` 和 `BackendRepository` 只支持最终注册请求。主后端 change `add-verified-registration-google-telemetry` 已定义三段式契约：请求 challenge、用六位验证码确认 challenge、使用一次性 proof 注册。生产手机号短信由服务端接入腾讯云，邮件由服务端邮件通道投递；iOS 不能持有任何供应商凭据，也不应直接依赖腾讯云 SDK。

本变更继续遵守 iOS 15、SwiftUI、构造函数注入和 `View -> ViewModel -> UseCase -> Repository Protocol -> Repository Implementation`。验证码、proof、密码和完整联系方式属于敏感数据，不进入日志、分析、Core Data、UserDefaults 或崩溃上下文。

## Goals / Non-Goals

**Goals:**

- 为邮箱与 E.164 手机号提供可完成的验证码注册状态机。
- 复用后端的 provider-neutral challenge 契约，使腾讯云只存在于服务端运维边界。
- 正确处理发送冷却、错误验证码、过期/锁定、限流、投递不可用、取消和重复点击。
- 使时间、installation ID、网络和错误响应可注入、可测试。
- 验证成功后只在内存中短暂持有 proof，并立即用于同一标识符的注册。

**Non-Goals:**

- 不在 App 中加入腾讯云 SDK、`SecretId`、`SecretKey`、SDK App ID、短信签名或模板 ID。
- 不实现短信模板管理、供应商回执、密码重置、验证码登录或自动读取短信。
- 不改变服务端 challenge、proof、注册或限流契约。
- 不在本 change 中实现 Google、Apple 或微信登录。

## Decisions

### 1. 客户端只依赖 MoveFit 验证契约

新增 `RegistrationVerificationProviding` repository protocol，提供 request/confirm 操作；`BackendRepository` 将其映射到：

- `POST /api/v1/auth/verification-challenges`
- `POST /api/v1/auth/verification-challenges/{challenge_id}/verify`
- 现有 `POST /api/v1/auth/register`

请求包含 `identifier`、`channel` 和不含 PII 的 `device_id`；确认包含六位 `code` 和同一个 `device_id`。不直接调用腾讯云可以避免供应商秘密进入二进制、避免客户端绕过服务端限流/埋点，并让邮件与短信共享一致流程。替代方案是在 iOS 集成腾讯云 SDK；它破坏信任边界，故不采用。

### 2. 使用显式注册状态机和专用 ViewModel

新增 `RegistrationViewModel`，由 `LocalAccountView` 创建并拥有，状态至少覆盖 idle、requesting、codeEntry、confirming、registering 和 completed。View 只渲染状态并发送语义化事件。`RequestRegistrationCodeUseCase` 与 `CompleteVerifiedRegistrationUseCase` 负责输入规范化、流程编排和 Repository 调用。

当账号类型或标识符变化时，旧 challenge、验证码和 proof 立即作废；新请求或 View 消失会取消旧 Task。用 generation token 丢弃迟到响应，避免旧 challenge 覆盖新输入。替代方案是继续把流程堆叠在 `AppModel`；这会扩大共享状态并使竞态难以测试，故不采用。

### 3. proof 只在一次调用链内存活

确认成功返回的 `verification_proof` 不写入属性持久层、Keychain、Core Data 或日志，而由完成注册 UseCase 立即提交给 register。注册失败后清除 proof；需要重试时重新确认或重新请求 challenge，具体取决于后端稳定错误码。密码同样只存在于当前表单内存。

### 4. installation ID 使用安全、非 PII 的稳定标识

新增可注入的 `InstallationIdentifying` port。默认适配器生成随机 UUID 并存入 Keychain，供 request/confirm 使用；不使用 IDFA、设备序列号、邮箱或手机号派生值。测试注入固定虚构 ID。卸载后重建 ID 是可接受取舍，服务端仍保留 source/identifier 限流。

### 5. 冷却和错误映射由稳定 code 驱动

API client 保留 Problem Details `code` 与 `Retry-After`，映射为可判别的领域错误。`auth_rate_limited` 使用服务端 Retry-After；缺失或非法时采用保守的本地默认冷却，但不把默认值解释为服务端保证。`verification_delivery_unavailable`、`verification_code_invalid`、`registration_verification_invalid` 和网络错误分别映射为用户可操作状态，客户端不得依赖服务端英文 detail。

倒计时由注入的 Clock 驱动，进入后台或恢复时按绝对截止时间重算，不通过累减计时漂移。登录和会话恢复不依赖验证码 provider 可用性。

### 6. 输入和可访问性边界

邮箱先去除首尾空白并按现有服务端规则提交；手机号 UI 明确要求含国家码的 E.164 格式。验证码仅接受六位 ASCII 数字，使用 one-time-code content type 和 number pad。切换登录/注册、账号类型或标识符会清理敏感输入和旧 challenge。所有用户文案进入本地化资源，按钮状态、错误和倒计时提供 VoiceOver 可读标签。

## Risks / Trade-offs

- [后端或腾讯云短信未配置] → 显示稳定的暂不可用说明，保留登录能力且不模拟发送成功。
- [短信延迟导致用户重复请求] → 发送成功后进入绝对时间冷却；仅在冷却结束后允许重发。
- [旧响应覆盖新账号输入] → 取消 Task、绑定 generation token，并在应用结果前核对账号类型和规范化标识符。
- [验证码/proof 被诊断系统采集] → 禁止包含在日志、错误文案、分析、持久化与请求描述中，并增加测试断言。
- [服务端契约尚未全部部署] → 先部署并验证后端 change，再启用客户端注册流程；生产登录不受影响。
- [Keychain installation ID 在重装后变化] → 接受新安装新 ID；服务端仍按其他维度限流。

## Migration Plan

1. 先完成并部署后端 `add-verified-registration-google-telemetry`，在 staging 配置邮件通道和腾讯云短信 gateway，并验证 challenge/confirm/register 契约。
2. 以协议级 fake 完成 iOS TDD，再用 staging 的虚构测试邮箱/手机号进行真机验收。
3. 将 Debug、staging 和 Release 指向对应 HTTPS MoveFit API；不得向客户端配置腾讯云凭据。
4. 发布后观察后端脱敏的 delivery、verification、rate-limit 和 registration telemetry。
5. 客户端回滚不需要数据迁移；旧版本仍可登录，但其手工 proof 注册路径不视为生产可用。服务端登录与既有会话继续运行。

## Open Questions

- 腾讯云短信签名和英文模板审核通过后，部署方需在服务端记录正式 `SdkAppId`、`SignName` 与 `TemplateId`；这些值不进入 iOS change。
- 是否在后续产品 change 中增加自动登录；当前保持注册成功后返回登录并预填标识符，避免改变现有 session 契约。
