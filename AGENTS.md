# MoveFit 编码规则

以下规则适用于仓库内全部 Swift/iOS 代码。除非 OpenSpec 设计明确覆盖，否则必须遵守。

## 技术基线

- 最低支持 iOS 15，UI 使用 SwiftUI，本地持久化使用 Core Data。
- 不得直接使用高于 iOS 15 的 API；确需使用时，必须提供 `#available` 判断和等价降级路径。
- 优先使用 Apple 原生框架。新增第三方依赖前，必须先在 OpenSpec 设计中说明必要性、替代方案和维护风险。

## 分层与依赖

- 依赖方向固定为：`View -> ViewModel -> UseCase -> Repository Protocol -> Repository Implementation`。
- `View` 只展示状态和发送用户事件；不得直接访问网络、Core Data、HealthKit、CoreLocation 或 Keychain。
- 业务规则放在 Domain/UseCase；平台 API 仅能出现在对应 Platform Adapter 中。
- Repository 协议定义在 Domain 层，具体实现放在 Data 或 Platform 层。
- 网络 DTO、`NSManagedObject`、HealthKit 类型不得越过数据边界进入 UI 或 Domain。
- 所有依赖通过初始化器注入；禁止新增业务单例、Service Locator 和隐式全局状态。

## 文件与命名

- 类型使用 `UpperCamelCase`，函数、变量和枚举成员使用 `lowerCamelCase`；代码标识符统一使用英文。
- 页面、状态和行为分别命名为 `XxxView`、`XxxViewState`、`XxxViewModel`。
- 用例使用动作命名，如 `LoadDailyActivityUseCase`；协议使用能力命名，如 `WorkoutRepository`。
- DTO、持久化模型和领域模型分别使用 `XxxDTO`、`XxxRecord`、`Xxx`，不得混用。
- 一个文件只定义一个主要类型，文件名与主要类型一致；扩展按职责拆为 `Type+Capability.swift`。
- 禁止创建无边界的 `Utils`、`Helpers` 或 `Manager`；名称必须表达具体职责。

## Swift 风格

- 使用 4 空格缩进，移除尾随空格；单行建议不超过 120 个字符。
- 默认使用最小访问级别；仅在跨模块确有需要时声明 `public`。
- 优先使用 `struct`、不可变值和纯函数；需要身份或共享生命周期时才使用 `class`。
- 禁止 `force unwrap`、`try!`、无说明的 `fatalError` 和空 `catch`。
- 使用 `guard` 处理前置条件和失败分支，减少深层嵌套。
- 注释只解释“为什么”和平台限制，不复述代码；临时方案必须包含可追踪的 OpenSpec 任务或问题编号。

## SwiftUI 状态管理

- View 自有状态使用 `@State`；View 创建并拥有的引用状态使用 `@StateObject`；外部注入使用 `@ObservedObject`。
- `View.body` 必须无副作用；加载、保存和权限请求由 ViewModel/UseCase 发起。
- ViewModel 标记 `@MainActor`，只暴露渲染所需状态和语义化事件方法。
- 单个 View 过大时按可复用视觉区域拆分；不得为了缩短文件而把业务逻辑移入子 View。
- 颜色、字体、间距、圆角和阴影必须使用 Design System Token，禁止在 Feature 中重复硬编码。
- 界面图标优先使用 SF Symbols；用户可见文本必须进入本地化资源，不得直接散落硬编码字符串。

## 并发与错误处理

- 异步流程优先使用 `async/await`；禁止为新代码引入回调嵌套。
- 每个长任务必须支持取消；View 消失或新请求替代旧请求时，应取消无效任务。
- 可变共享状态必须由 actor、主线程隔离或明确的串行执行器保护。
- Domain/Data 层使用可判别的错误类型；只有 UI 层负责把错误映射为用户文案。
- 不得静默忽略失败。允许降级时，必须记录非敏感诊断信息并返回明确状态。

## 数据、单位与时间

- 距离、质量、能量等数据使用 `Measurement` 或带明确单位的领域类型，禁止用裸 `Double` 隐含单位。
- 持久化和传输使用统一基础单位；单位转换只在边界或展示层进行。
- 时间持久化为绝对时间点；日期范围计算必须显式传入 `Calendar`、`TimeZone` 和当前时间。
- 服务端 ID、客户端临时 ID 和 HealthKit UUID 必须区分，禁止依赖展示字段去重。
- 离线写操作必须具有稳定操作 ID 和幂等语义。

## 健康数据与安全

- HealthKit 访问必须集中在 HealthKit Adapter；按功能逐项请求最小权限，不得一次申请无关数据。
- HealthKit 查询无结果不得直接解释为“用户拒绝权限”，统一表示为数据不可用或暂无数据。
- 访问令牌和敏感凭据只存 Keychain；禁止写入 `UserDefaults`、源码、日志或测试夹具。
- 日志不得包含姓名、手机号、邮箱、精确位置、健康指标、访问令牌或完整服务端响应。
- Core Data 中只保存功能必需的数据；复制 HealthKit 原始数据前必须有明确的数据所有权和清理策略。

## 修改原则

- 修改应保持最小范围，禁止顺带重构无关模块或批量格式化无关文件。
- 新能力必须沿既有分层扩展，不得从 UI 绕过 Repository 直接接入平台服务。
- 若需求与本规则冲突，先更新 OpenSpec 设计并说明取舍，再修改代码。
