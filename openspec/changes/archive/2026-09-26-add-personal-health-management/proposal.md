## Why

MoveFit 当前只覆盖运动与少量健康摘要，缺少日常健康管理入口；同时 ECG 仅显示分类摘要，未展示 HealthKit 中可读取的历史波形。

## What Changes

- 首页新增症状、用药、饮食营养、检查记录入口及统计、非诊断性本地洞察。
- 建立本地可恢复的症状、用药、膳食和检查摘要管理能力。
- 读取并仅在内存展示 HealthKit ECG 历史电压波形，补充安全提示。

## Capabilities

### New Capabilities

- `personal-health-management`: 症状、用药、营养和检查记录的本地健康管理体验。

### Modified Capabilities

- `health-metric-details`: ECG 详情支持历史波形的最小读取与安全展示。
- `health-dashboard`: 首页提供个人健康管理入口。
- `offline-data-security`: 新增健康管理数据的最小化本地保存与清理边界。

## Impact

- 影响 Home、Domain、Core Data、HealthKit Adapter、DesignSystem 和测试；不依赖未定义的服务端 API，也不作医疗诊断。
