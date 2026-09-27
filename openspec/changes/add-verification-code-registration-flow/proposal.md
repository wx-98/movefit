## Why

当前 iOS 注册页要求用户手工输入后端 `verification_proof`，普通用户无法完成真实的邮箱或手机号注册。后端 change `add-verified-registration-google-telemetry` 已定义验证码 challenge 契约，且手机号短信将由服务端接入腾讯云，因此客户端需要形成请求验证码、确认验证码、取得一次性 proof 并注册的完整流程。

## What Changes

- 将手工 `verification_proof` 输入替换为邮箱/手机号验证码注册流程：请求验证码、输入六位验证码、确认并自动提交注册。
- 邮箱继续通过后端配置的邮件通道投递，手机号通过后端配置的腾讯云短信通道投递；iOS 不感知供应商且不包含腾讯云凭据或 SDK。
- 增加验证码发送、冷却、过期、验证、失败和重试状态，并根据后端稳定错误码展示可操作提示。
- 使用持久化但不含 PII 的 installation/device identifier 参与后端限流；验证码、proof、密码和完整联系方式不得进入日志、分析或本地持久化。
- 补充协议级 fake、ViewModel、Repository 和 UI 测试，并更新后端接入文档与真机验收清单。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `account-health-profile`: 手机号和邮箱注册从手工 proof 输入改为真实验证码 challenge/confirm/registration 闭环，并明确错误、限流、重试和敏感数据边界。

## Impact

- 影响账户注册 View/ViewModel、认证 UseCase、Repository 协议、`BackendRepository` DTO/映射、错误码映射和依赖组装。
- 依赖主后端 `POST /api/v1/auth/verification-challenges`、`POST /api/v1/auth/verification-challenges/{challenge_id}/verify` 与现有 `POST /api/v1/auth/register` 契约。
- 关联服务端 OpenSpec change：`/Volumes/E/code/codex/movefit-backed/openspec/changes/add-verified-registration-google-telemetry`。
- 不新增第三方 iOS 依赖；腾讯云 `SecretId`、`SecretKey`、SDK App ID、签名和模板 ID 只配置在服务端/Coolify。
