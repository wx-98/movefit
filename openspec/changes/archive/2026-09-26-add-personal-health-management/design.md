## Context

所有新记录为用户主动输入的本地数据。ECG 波形来自 HealthKit，原始采样不写入 Core Data、不上传、不进入日志。

## Goals / Non-Goals

**Goals:** 丰富首页入口、提供可用统计与低风险本地建议、按需显示 ECG 波形。

**Non-Goals:** 不诊断疾病、不替代处方、不识别药品图片、不上传检查 PDF/图片、不调用未提供的 AI 后端。

## Decisions

- 使用领域模型和 Repository 协议，Core Data 仅保存主动录入记录；View 不直连平台 API。
- 用本地规则生成“趋势/待补货/宏量营养”提示；显式标记为建议。
- HealthKit Adapter 通过 `HKElectrocardiogramQuery` 按选中 ECG 样本读取电压，限制点数后交给 UI 图表；只在支持 iOS 15 的设备且用户授权时可用。

## Risks / Trade-offs

- [无 ECG 权限/样本] → 显示真实空状态，不解释为异常。
- [健康建议被误解] → 每页展示非诊断声明和就医引导。
- [敏感记录过多] → 支持用户逐条删除和清理本地健康管理记录。
