# MoveFit

MoveFit 是一款最低支持 iOS 15 的 SwiftUI 综合运动健康应用。设备健康数据直接来自系统；账号、资料、运动同步、挑战、文章、帮助与工单接入主业务后端，动作目录和 AI 洞察接入各自后端。离线内容与服务端内容分开标注，不使用模拟成功或演示排名。

## 当前能力

| 能力 | 数据来源 | 持久化/边界 |
| --- | --- | --- |
| 今日健康摘要与活动圆环 | HealthKit 真实样本 | 系统健康数据库；应用不复制原始样本 |
| 健康趋势与指标详情 | HealthKit 按日统计、最新样本、ECG 摘要与选中记录波形 | 7/30/180/365 天；原始 ECG 波形只短暂保留在内存 |
| 睡眠阶段与评分 | HealthKit 睡眠样本 | 本地透明规则计算，不是医疗诊断 |
| 户外路线与距离 | Core Location 前台定位 | 完成运动后保存到 Core Data |
| 运动历史与手动记录 | HealthKit、Core Data、主业务后端 | 本地优先；登录后同步受支持类型 |
| 训练方案与动作库 | 动作目录后端 + 随包降级内容 | 远程分页；失败时明确标识内置降级 |
| 个人身体指标 | 用户输入、主业务后端 | 登录后版本化同步 + Core Data 缓存 |
| 挑战进度与徽章 | 主业务后端挑战目录、参与与排行榜；60 条本地模板 | 服务端与本机进度分开展示，本机加入状态保存到 Core Data |
| 健康洞察 | 本地低风险趋势规则 + AI 健康洞察后端 | 仅传递聚合指标；登录且服务端权益可用时调用真实 AI |
| 养护建议 | 本地健康规则与主后端已发布文章 | 服务端收藏仅在认证且写入成功后更新；离线显示随包内容 |
| 隐私遮挡偏好 | 用户设置 | Core Data |
| 主动健康管理 | 用户手动输入的症状、用药、饮食与检查记录 | Core Data，仅本机保存，不上传 |
| 账号 | 主业务后端密码与 Apple/微信/Google 社交认证 | Access/Refresh Token 仅存 Keychain；微信授权需另行接入 SDK |
| 客户端配置 | 主业务后端 | 读取版本化配置修订，不猜测开关语义 |
| 排行榜 | 主业务后端挑战快照 | 只展示服务端隐私别名和当前用户标记，不生成模拟名次 |
| 身份绑定、帮助与工单 | 主业务后端正式 API | 绑定/解绑与工单写入使用稳定幂等键；未登录不可写 |

应用不会在无权限、无样本或模拟器环境中用演示健康数值填空；界面会显示“暂无数据”或明确的不可用状态。

## 已实现功能

### iOS 健康视觉体验

- 五个主界面采用 iPhone 健康 App 的阅读层级：大标题、重点摘要、分区标题、系统分组表面和可扫读的数据卡。
- 颜色、表面、圆角、间距和设置列表行收敛到 Design System；深色模式使用系统语义表面，避免固定浅色卡片。
- 首页突出今日概览、活动圆环、重点指标、趋势、睡眠、健康管理和快速开始；挑战、运动、历史与我的分别突出行动、训练、回顾和资料设置。
- `example/` 中的页面仅作为内容密度与色彩组织参考；实现使用 SwiftUI、SF Symbols 和系统动态字体，不复制网页布局或外部资产。

### 首页

- 从 HealthKit 读取当天的步数、步行与跑步距离、活动能量、锻炼分钟和站立小时。
- 读取最新心率和静息心率样本。
- 使用居中的三层活动圆环展示活动能量、锻炼分钟和站立小时，比例按明确目标计算。
- 使用 `HKStatisticsCollectionQuery` 读取 7 天、30 天、6 个月和 1 年的真实步数、距离、活动能量与锻炼分钟趋势。
- 趋势详情提供柱状图、有效日均、总量、最佳日和数据来源说明。
- 读取睡眠阶段，合并重叠区间并展示时长、在床时间、睡眠效率、阶段分布与时间轴。
- 睡眠评分由睡眠时长 60 分、效率 25 分、规律性 15 分构成；样本不足时不评分。
- 区分未加载、不可用、无样本、可用和读取失败状态。
- 支持主动连接 Apple 健康及下拉刷新。
- 健康指标缺失时单项显示占位，不伪造为零。
- 首页提供症状记录、用药提醒、饮食与营养、检查记录四个入口，并明确说明记录仅保存在本机、提示不构成医疗诊断。
- 四类管理页均支持添加、删除、历史时间线、近 7 天趋势和本地非诊断性提示；用药可逐项标记完成，营养可记录能量、蛋白质和碳水。
- 步数、距离、当前心率和静息心率卡片均可进入详情，展示近 30 天可交互趋势、平均值、累计值、有效天数及数据来源。
- 心率详情按系统最小权限读取 HealthKit ECG 的记录时间、来源与系统分类摘要；点按单条记录后只在内存中读取并绘制其历史电压波形，不保存、不上传或做异常诊断。
- 健康洞察先查询真实 AI 服务权益；登录且服务端返回可用时调用 `/api/v1/health-insights/analyze`，使用主业务 Token 和幂等键；不可用时明确保留本地规则洞察。

### 挑战

- 内置 60 条稳定 ID 挑战模板，覆盖跑步、骑行、力量、HIIT、步数和恢复六类；支持类别、难度和关键词筛选。
- 跑步挑战包含“五公里入门、减脂 5K、比赛 5K、夜跑 5K、10K 进阶”等层级目标，其余类别也各有 10 个由入门到目标的挑战。
- 步数进度读取近 7 日 HealthKit 步数；跑步、骑行和训练日进度读取 MoveFit 与 HealthKit 已合并记录。
- 挑战加入状态使用稳定 ID 保存，重新启动后可恢复。
- 每个挑战均可进入详情查看目标、进度、规则和数据来源，并支持加入与退出。
- 页面包含彩色精选卡、横向热门卡片和徽章解锁状态。
- 徽章根据本机运动历史实时计算。
- 服务端挑战支持目录、详情、参与、退出和隐私化排行榜；本机模板单独标注，不展示虚构排名。

### 运动

- 支持跑步、步行、骑行、瑜伽、力量、HIIT、徒步、游泳、椭圆机、划船、普拉提、舞蹈和其他类型的展示与记录。
- 提供离线训练目录：跑步包含五公里轻松跑、低强度减脂跑和间歇冲刺跑，并提供步行、骑行、力量、瑜伽和 HIIT 方案。
- 每个训练方案包含目标、难度、时长、适用人群、分步流程、安全提示和开始训练入口。
- 动作库支持中文/英文名搜索和难度过滤，展示器械、目标肌群、分步动作、安全提示与内容版本。
- 动作目录通过 `ExerciseCatalogProviding` 隔离，真实请求 `GET /v1/exercises`，支持按页继续加载、搜索、难度、器械和肌群过滤，并展示远程图片。
- 动作详情将动作服务 `images` 数组的前两张图片分别展示为“起始动作”和“结束动作”，可左右切换；缺图、下载失败时显示明确的本地占位状态。
- 动作服务失败时才使用已审核的随包基础动作，页面明确显示“内置降级”；App 不直接依赖 GitHub JSON 字段。
- 运动会话包含准备、开始、暂停、继续、结束、保存和失败状态。
- 跑步、步行和骑行会在使用期间定位授权后采集前台路线。
- 定位点按水平精度、时间顺序和相邻跳变过滤，并累加真实距离。
- 暂停时停止定位，继续时恢复；结束后将时长、路线和距离写入 Core Data。
- 定位被拒绝时仍可保存真实运动时长，但不会生成路线或距离。
- 支持手动录入运动类型、时长和可选距离。

### 历史

- 支持周、月、六个月和年四种统计周期。
- 查询并展示 Apple 健康中的全部 `HKWorkout`，未知运动类型映射为“其他”，不会因为缺少距离、能量或路线而隐藏。
- 登录后完整读取主业务后端的 cursor 分页，与 Core Data、HealthKit 按“来源 + 稳定 UUID”合并去重，并支持全部、Apple 健康、MoveFit 来源筛选。
- 完成或手动添加运动时先保存 Core Data，再使用稳定 UUID 和 `Idempotency-Key` 上传主后端；远程失败不丢失本地记录。
- 汇总选定周期内的真实运动次数、总时长、总距离和活动能量，并展示对应周期的真实步数趋势。
- 步数趋势在周、月、半年、年分别按日、周、月分桶，采用可点击柱状图、平均线与今日标记；点击柱体可查看对应日期或区间与步数，且会说明今天相对平均水平的中性比较。
- 单次运动详情展示来源、时间、时长、距离、能量、路线和缺失字段说明。
- 有路线点时使用 MapKit 展示路线摘要；无路线时不显示地图。
- 本地数据库为空时显示真实空状态，不注入示例运动。

### 我的与养护

- 展示并编辑昵称、身高、体重、体脂率和 BMI，输入经过范围校验。
- 首次使用未填写时显示空值，不使用默认身体指标。
- 未登录时身体指标保存在本机；登录后通过 `base_version` 更新主业务后端并缓存到 Core Data，版本冲突不会覆盖远端新数据。
- 支持遮挡身体指标，偏好在重新启动后恢复。
- 养护建议由 HealthKit 今日摘要经本地规则生成；数据不足时明确提示。
- 已发布健康文章优先从主后端读取并支持认证收藏；离线时显示随包基础文章，不伪装为远端收藏成功。
- 可清理离线操作缓存，同时保留运动记录、个人资料与偏好。
- 支持跟随系统、浅色、深色外观并持久化；当前语言支持跟随系统和简体中文。
- 提供真实社交身份绑定状态、帮助文章、本人支持工单、健康与设备、离线隐私政策和版本信息页面。
- 邮箱和手机号使用真实密码登录、验证码注册、令牌轮换与退出接口；访问令牌和刷新令牌仅存 Keychain。
- Apple ID 与 Google 使用系统授权流程；微信因尚未接入开放平台 SDK/Universal Link，会明确提示配置需求，不会生成伪授权码或会话。

### 服务端能力边界

- 已接入：邮箱/手机号验证码注册与密码登录、Apple/微信/Google 社交身份 API、令牌刷新与退出、资料与运动、挑战、文章、帮助、工单、客户端配置和动作目录。
- 注册固定为三步：请求验证码 → 确认六位验证码 → 立即提交同一规范化标识和一次性证明。一次性证明不展示给用户，也不写入日志或持久化；邮件/短信 Provider 未配置时会真实返回 503，客户端不会绕过验证。
- 社交 Provider 实际可用性仍取决于后端凭据、Apple/Google 回调配置和微信 SDK；账号注销仍未实现。
- HealthKit 数据不会被自动批量上传；只有用户在 MoveFit 完成或手动添加、且后端枚举支持的运动会同步。

## 技术架构

| 项目 | 实现 |
| --- | --- |
| 最低系统 | iOS 15.0 |
| UI | SwiftUI |
| 本地数据库 | Core Data（代码创建模型） |
| 健康 | HealthKit |
| 定位与地图 | Core Location、MapKit |
| 网络 | URLSession、DTO 映射、Problem Details、Bearer 自动刷新一次 |
| 安全存储 | Keychain 会话存储 |
| 并发 | async/await、Actor、`@MainActor` |
| 测试 | XCTest、XCUITest、内存 Core Data |
| 第三方依赖 | 无 |

依赖方向固定为：

```text
View → AppModel / ViewModel → UseCase → Repository Protocol → Data / Platform Adapter
```

- `View` 只展示状态并发送用户事件。
- `AppModel` 协调应用级状态、用例和页面事件，运行在主线程隔离域。
- `Domain` 定义模型、协议、状态机和纯业务规则。
- `Data` 实现 Core Data、HTTP Client、DTO 映射、远程 Repository 和幂等写入。
- `Platform` 封装 HealthKit、Core Location 与 Keychain。
- 依赖通过初始化器注入，测试可替换 Repository、健康、定位、时间和 UUID。

### 目录

```text
MoveFit/
├── App/                 # 应用入口、依赖组装、AppModel
├── Features/            # 五个主界面与详情页面
├── Domain/              # 领域模型、协议、状态机和业务规则
├── Data/                # Core Data、Networking 与 Repository 实现
├── Platform/            # HealthKit、定位与 Keychain 适配器
├── DesignSystem/        # 颜色、间距、卡片、图表和状态组件
└── Resources/           # AppIcon、Logo、颜色与本地化资源

MoveFitTests/            # 单元测试与本地集成测试
MoveFitUITests/          # 导航与关键流程 UI 测试
Configuration/           # Info.plist 与 entitlements
docs/                    # 需求稿与真机验收清单
openspec/                # 主规格和变更工件
```

## 核心接口

以下协议隔离 UI、领域逻辑、REST DTO、本地数据和 Apple 平台框架。

| 协议 | 主要接口 | 职责 |
| --- | --- | --- |
| `WorkoutRepository` | `workouts()`、`save(_:operationID:)` | 查询和幂等保存运动 |
| `HealthDataProviding` | `dailySummary()`、`trend`、`metricDetail`、`electrocardiogramSummaries()`、`electrocardiogramWaveform(for:)`、`sleepSummary()`、`healthWorkouts()` | 授权并读取健康摘要、趋势、指标详情、ECG 最小摘要/内存波形、睡眠和运动 |
| `PersonalHealthRecordProviding` | `personalHealthRecords()`、`savePersonalHealthRecord(_:)`、`deletePersonalHealthRecord(id:)` | 隔离本机主动健康管理记录的读取、保存与删除 |
| `AIHealthInsightProviding` | `access(for:)`、`analyze(_:)` | 隔离未来 AI 远程能力、版本与权益；当前默认本地规则 |
| `TrainingCatalogProviding` | `plans()` | 提供离线训练方案 |
| `ExerciseCatalogProviding` | `exercises(query:page:pageSize:)` | 隔离版本化动作目录、搜索和筛选 |
| `LocationProviding` | `start()`、`pause()`、`resume()`、`snapshot()`、`stop()` | 管理前台定位会话 |
| `CredentialStoring` | `save`、`token`、`delete` | 安全读写真实账号令牌 |
| `AuthenticationProviding` | `restoreSession`、`signIn`、`register`、`signOut` | 真实密码认证与会话生命周期 |
| `RegistrationVerificationProviding` | `requestChallenge`、`confirmChallenge` | 与邮件、腾讯云短信无关的注册验证码挑战和确认边界 |
| `RemoteProfileProviding` | `currentProfile`、`updateProfile` | 服务端资料与乐观锁版本 |
| `RemoteWorkoutProviding` | `workouts`、`upload` | cursor 分页读取和幂等上传运动 |
| `ClientConfigurationProviding` | `configuration` | 读取版本化客户端配置 |
| `DateProviding` | `now` | 提供可测试时间 |
| `UUIDProviding` | `make()` | 提供记录 ID 与幂等操作 ID |

主要实现：

- `CoreDataWorkoutRepository`：生产环境运动数据源，不包含内置运动或路线。
- `PersistenceController`：管理运动、档案、挑战、文章收藏、偏好、主动健康管理记录和离线操作实体。
- `HealthKitAdapter`：分项请求最小读取权限，聚合当天样本、按日趋势、指标详情、ECG 分类摘要与按需内存波形、睡眠阶段和全部运动样本。
- `BundledTrainingCatalog`：随应用发布的训练方案，不依赖网络。
- `MoveFitAPIClient`：统一处理主后端请求、Problem Details、Bearer 与一次刷新重试。
- `BackendRepository`：实现认证、社交身份、资料、运动、挑战、内容、帮助、工单和客户端配置协议。
- `RegistrationViewModelFactory`、`RegistrationViewModel`：组装并驱动请求验证码、倒计时、确认与注册状态机。
- `KeychainInstallationIdentity`：生成并复用不含个人信息的随机安装 UUID，供验证码风控绑定设备。
- `RemoteExerciseCatalogRepository`：连接 8001 动作服务；按运行时 OpenAPI 使用 `page_size`。
- `FallbackExerciseCatalogRepository`：远程失败时切换 `BundledExerciseCatalog` 并保留来源状态。
- `LocalHealthInsightProvider`：仅用已聚合的指标值生成非诊断性本地趋势提示。
- `RemoteAIHealthInsightRepository`：远程 AI 的可版本化接口预留；未配置 URL 或权益时不发起请求且明确显示本地洞察。
- `LocationAdapter`：管理前台定位生命周期；`RouteAccumulator` 负责过滤和距离累计。
- `KeychainStore`、`BackendSessionStore`：安全保存真实令牌与会话摘要。
- `UnavailableAuthenticationAdapter`：仅供未装配网络依赖的测试/预览使用，始终失败且不模拟成功。
- `DemoWorkoutRepository`、`DemoHealthProvider`：仅供测试或预览替身，生产入口未注入。

## 启动

### 环境要求

- macOS 与 Xcode；
- iOS 15 或更高版本 Simulator Runtime；
- 真机运行需有效 Apple Developer Team；
- 无需安装 CocoaPods、Carthage 或 Swift Package；验证全部远程能力时，默认 Debug 还需启动主业务、动作目录和 AI 三个本地后端。

### 启动本地后端

主业务后端（完整环境变量与迁移步骤以其仓库 README 为准）：

```bash
cd /Volumes/E/code/codex/movefit-backed
docker compose up -d mysql
make test-db-prepare
UV_CACHE_DIR=.uv-cache uv run --frozen --no-sync alembic upgrade head
UV_CACHE_DIR=.uv-cache uv run --frozen --no-sync \
  uvicorn --factory movefit.bootstrap.entrypoint:create_runtime_app \
  --host 0.0.0.0 --port 8000 --reload
curl http://192.168.31.126:8000/health/ready
```

动作目录后端：

```bash
cd /Volumes/E/code/codex/movefit-work
docker compose up -d --build
curl http://192.168.31.126:8001/health
curl 'http://192.168.31.126:8001/v1/exercises?page=0&page_size=1'
```

若后端已经运行，确认 8000 readiness、8001 exercises 与 8002 readiness 均返回成功。

### 后端地址配置

- [Configuration/Info.plist](Configuration/Info.plist) 通过 `MoveFitBackendBaseURL`、`MoveFitExerciseBaseURL` 和 `MoveFitAIBaseURL` 读取构建变量。
- Target `MoveFit` 的 Build Settings 中，Debug 默认分别为 `http://127.0.0.1:8000`、`:8001`、`:8002`，适合本机模拟器；真机需在构建时覆盖为 staging HTTPS 或当前 Mac 的局域网地址。
- Release 默认分别为 `https://api.movefitgo.com`、`https://exercises.movefitgo.com`、`https://ai.movefitgo.com`，启动时会拒绝占位、明文或本机地址。staging 构建覆盖为对应的 `staging-*` 域名；详见 [接入文档](docs/后端接入与环境配置.md)。构建值不代表线上已经可达。
- 训练计划优先读取主后端发布目录；请求失败才显示明确标注的本地离线方案，服务端有效空目录不会自动填充内置示例。
- Google 登录使用系统浏览器和 PKCE S256，不依赖 Google SDK。`MOVEFIT_GOOGLE_CALLBACK_SCHEME` 默认 `com.movefit.mobile`，完整回调 URI 为 `com.movefit.mobile:/oauth2redirect`；它必须同时登记在 iOS URL scheme、Google OAuth 客户端和主后端 redirect allowlist，真机发布前需完成授权/取消/错误回调验收。
- 微信授权码 Adapter 目前明确返回“需配置”；接入微信开放平台 SDK、App ID、Universal Link 和合规审查后才能真机使用。Provider Secret 只能配置在后端，不能进入 App。
- 社交绑定/解绑可靠重试要求先部署主后端 `add-social-identity-write-idempotency` change；挑战进度依赖 Challenge worker。客户端用稳定操作 ID 提交受保护写入，只有服务端确认后才显示成功。
- 详细接口映射与切换步骤见 [docs/后端接入与环境配置.md](docs/后端接入与环境配置.md)。

### Xcode 启动

1. 打开 `MoveFit.xcodeproj`。
2. 选择 `MoveFit` Scheme。
3. 选择 iPhone 模拟器或已签名真机。
4. 按 `Command + R`。

模拟器可验证界面、本地录入和 Core Data，但通常没有可用 HealthKit 样本，也不代表真实户外定位效果。此时显示暂无数据是预期行为。

### 真机权限

1. 在 Target 的 Signing & Capabilities 中选择自己的 Team。
2. 确认 HealthKit Capability 可用，Bundle Identifier 唯一。
3. 首次点击“连接或刷新 Apple 健康”时按需授权活动、心率、ECG、睡眠和运动读取项目；ECG 仅在支持的设备和可读记录存在时显示摘要。
4. 首次开始户外运动时允许“使用 App 期间”定位。
5. 保持应用在前台完成一次户外运动，再到历史页检查距离和路线。

MoveFit 当前不请求始终定位，也不声明后台路线采集；切到后台、锁屏或系统终止时不保证路线连续。

## 命令行构建与测试

构建：

```bash
xcodebuild \
  -project MoveFit.xcodeproj \
  -scheme MoveFit \
  -sdk iphonesimulator \
  build
```

查看模拟器：

```bash
xcrun simctl list devices available
```

运行全部测试（将设备名替换为本机可用模拟器）：

```bash
xcodebuild \
  -project MoveFit.xcodeproj \
  -scheme MoveFit \
  -destination 'platform=iOS Simulator,name=<模拟器名称>' \
  test
```

仅运行单元测试：

```bash
xcodebuild \
  -project MoveFit.xcodeproj \
  -scheme MoveFit \
  -destination 'platform=iOS Simulator,name=<模拟器名称>' \
  -only-testing:MoveFitTests \
  test
```

测试覆盖验证码注册状态机、E.164/六位码校验、重发倒计时、竞态取消、Problem Details/`Retry-After`、挑战目录稳定性、趋势分桶与比较、睡眠评分与区间合并、健康洞察安全边界、主动健康管理统计/趋势/本地持久化、ECG 波形降采样、跨来源运动去重、动作筛选、URL 请求路径、运行时 `page_size`、DTO/单位映射、令牌刷新、cursor 全分页、远程降级、外观与语言偏好、状态机、Core Data 持久化，以及五个 Tab 的关键 UI 流程。

## 隐私与数据边界

- HealthKit 仅请求当前功能需要的读取类型，不申请写入权限。
- 健康原始样本保留在 HealthKit，MoveFit 只在内存中展示摘要、趋势、睡眠和 HealthKit 运动。
- ECG 记录的分类、时间、来源摘要和用户点按后读取的原始电压波形均只在内存中短暂保留；不保存、上传或提供诊断/治疗建议。
- 本地健康洞察只使用当前值、平均值、周期和单位等聚合字段；未来远程 AI 必须经由 `AIHealthInsightProviding`、后端能力版本与权益校验，且不得上传 HealthKit 原始样本。
- Core Data 仅保存用户输入、运动结果、主动健康管理记录和应用偏好；不保存 HealthKit 原始样本或 ECG 波形。
- 定位只在前台运动会话开始至暂停/结束期间更新。
- 日志不得写入健康指标、精确路线、完整邮箱/手机号、密码、验证码、一次性证明、账号令牌或 Provider 原始错误。
- 真实账号令牌只保存到 Keychain，不写 UserDefaults、Core Data 或日志。
- 验证码和一次性证明仅在注册流程内存中短暂存在；改变注册标识、取消、离开页面或完成后立即清除。腾讯云 `SecretId`、`SecretKey`、短信应用 ID、签名和模板 ID 只配置在后端/Coolify，禁止进入 iOS 源码、Build Settings、Info.plist、持久化、分析事件或日志。
- 服务端资料和 MoveFit 运动只发送接口必需字段；不自动上传 HealthKit 原始样本或路线。

## 已知限制

- 微信授权码获取仍需开放平台 SDK 和 Universal Link；Google 真实授权需配置服务端允许的回调 URI；账号注销尚未实现。
- HealthKit 无法直接区分“用户拒绝某项读取”与“没有样本”，统一显示暂无数据。
- 不支持后台或锁屏持续定位，也不支持中断后恢复运动会话。
- 不向 Apple 健康写入完成的运动。
- Apple 健康路线当前不会额外查询 `HKWorkoutRoute`；有距离和能量的训练仍会完整展示，并说明路线缺失。
- 手动运动暂不编辑开始时间和热量。
- 动作服务当前数据的 `nameZhHans`/`instructionsZhHans` 仍可能包含英文，内容中文化与媒体许可由动作后端发布流程负责。
- 仅支持 iPhone 竖屏，尚未适配 iPad 和 Mac Catalyst。

真机检查见 [docs/真机验收清单.md](docs/真机验收清单.md)，产品需求见 [docs/movefit需求稿.md](docs/movefit需求稿.md)。

## OpenSpec

主规格位于 `openspec/specs/`，当前完整体验变更位于 `openspec/changes/complete-movefit-experience/`。

```bash
openspec validate --all
```
