# DevelopmentKit · LocalNotification 模块实施计划

> 类型：功能实施计划（RFC / Spec）
> 状态：已设计，待实施（计划性归档，非紧急）
> 目标模块：`DevelopmentKit.LocalNotification`
> 适用平台：iOS 16+ / macOS 13+（与本库现有约束一致）

---

## 0. 给实施者的说明（包括 AI 助手）

本文件是 DevelopmentKit 的一个**新模块实施计划**，可独立阅读、不依赖任何外部上下文。开始实施前请先做两件事：

1. 阅读本仓库的 `README.md` / `README_cn.md`，以及现有模块 `Network`、`Log`、`NavigationRouter`，对齐本库的代码风格与约定。
2. 严格遵循下文「设计原则」与「与现有约定的衔接」两节——本模块的价值有一半在于它的**边界**，实现时不要越界。

本库的既有约定（实现时必须遵守）：

- 用空 `enum` 作命名空间（`public enum DevelopmentKit { ... }`，内部再套子命名空间），功能挂在 `extension` 上。
- 对外异步能力优先用 Combine `Publisher` 暴露；新代码可同时提供 `async/await` 版本。
- 零外部依赖，只允许使用系统框架。
- 公开 API 必须有完整 SwiftDoc（`/** */`，含 `- Important` `- Note` `- Parameter` `- Returns` `- Throws` 等标记），**注释内禁止 emoji**。
- 公开 API 标注 `@available`。
- 错误类型最终并入统一的 `DevelopmentKitError` 体系（若该类型尚未落地，先用本模块自有错误类型，并在代码中标注 TODO 待并入）。
- UI 相关的有状态类型用 `@MainActor`。
- 补充单元测试，更新 README 与 CHANGELOG。

---

## 1. 背景与动机（前因后果）

这个模块来自一次真实的 App 开发经验：在某个使用本库的 App 中，出现了一个很常见的需求——**发出本地通知，并在用户点击通知后深链跳转到某个特定页面**；同时，当同一类事件可能短时间内被多次触发时，**通知不能重复堆叠**。

在实现这个需求的过程中，沉淀出三块**与具体业务完全无关**的通用能力：

1. **本地通知的权限申请与调度**——标准的 `UserNotifications` 流程封装。
2. **通知去重**——同一逻辑事件即使被触发多次，也只对应一条通知，不在通知中心里堆叠。
3. **点击事件的载荷分发**——用户点击通知后，把通知携带的 `userInfo` 解析出来，交给上层决定"跳到哪里"。

这三块和本库现有的 `Network`、`SysInfo`、`Utilities` 是同一性质：通用、零业务、只依赖系统框架。因此把它做成本库的一个新模块 `DevelopmentKit.LocalNotification` 是合理的。

需要强调的是：原始场景里大量与业务强耦合的部分（具体的路由类型、导航容器结构、按某种业务生命周期做的应用层去重等）**不属于本模块**，它们应留在各自的 App 里。本模块只提供"机制"，不提供"策略"。

---

## 2. 为什么当初决定缓做（决策记录）

设计完成时刻意选择**不立即并入本库**，而是归档为计划，原因如下（供将来评估"现在是否到了实施时机"时参考）：

1. **本库当时处于 pre-1.0，公开接口尚未稳定。** 错误体系（计划统一为 `DevelopmentKitError`）和部分全局函数命名仍在调整。此时新增公开 API，等于增加一块还没定型的表面积，将来重构会牵连到它。
2. **应先还稳定性债。** 当时高优先级事项（并发安全、错误统一）尚未完成，不宜在还债前先加新功能。本模块在优先级上属于"增强"，不抢稳定性的先后顺序。
3. **抽象边界值得被多个用例验证（rule of three）。** 当时只有一个真实用例，过早做协议化/泛型化容易抽歪。等出现第二个用例，边界会更清晰。

**建议的实施触发条件：** 本库进入接口稳定期（里程碑 v0.5 之后、错误体系与命名已定），或出现第二个明确用例时，即可按本计划落地。

---

## 3. 设计原则（实现时的硬约束）

1. **机制与策略分离。** 本模块只做"通知收发 + 载荷传递 + 去重"。"载荷代表什么路由、点击后导航到哪"由调用方决定。模块**绝不 import 任何业务类型**。
2. **不依赖本库内其他有状态模块，尤其是 `NavigationRouter`。** 点击事件以原始 `userInfo` 抛出，谁需要导航谁去订阅。理由：库内部模块互相耦合比 App 层耦合更难拆——一旦本模块写死了对路由器的引用，二者就绑死，使用方想单独用通知都得把路由器一起拖走。
3. **稳定 identifier 做去重。** 相同 `identifier` 的通知由系统更新而非新增，从而避免堆叠。是否还需要更激进的"应用层去重"由调用方在自己业务层处理——本模块不假设任何业务生命周期（如某种连接周期、会话周期）。
4. **遵循本库既有约定**（见第 0 节）。

---

## 4. API 设计草案

以下为接口起点，实现时可在不违背第 3 节原则的前提下细化。

```swift
import Foundation
import Combine
import UserNotifications

extension DevelopmentKit {
    /// 本地通知命名空间
    public enum LocalNotification {}
}

/**
 本地通知错误类型。

 - Note: 后续应并入统一的 `DevelopmentKitError` 体系；在该类型落地前，本模块先使用此错误，并保留 TODO 标记。
 */
public enum LocalNotificationError: Swift.Error {
    /// 用户拒绝授权
    case authorizationDenied
    /// 授权状态未确定或无法获取
    case authorizationUndetermined
    /// 系统返回的其他错误
    case system(Swift.Error)
}

/**
 本地通知管理器，封装权限申请、调度、移除与点击事件分发。

 - Important: 仅负责通知的收发与载荷传递，不持有任何业务路由状态，也不依赖本库其他模块。
 - Requires: iOS 16+ / macOS 13+。
 - Note: 用户点击通知后，其 `userInfo` 通过 `didTap` 原样抛出，由上层自行解析为各自的路由类型。
 - Warning: 仅处理本地通知；远程推送（APNs）不在本模块范围。
 */
@available(iOS 16.0, macOS 13.0, *)
@MainActor
public final class LocalNotificationCenter: NSObject, ObservableObject {

    /// 单例，确保通知中心代理只注册一次
    public static let shared = LocalNotificationCenter()

    /// 用户点击通知时，抛出该通知的 userInfo，由上层解析路由
    public let didTap = PassthroughSubject<[AnyHashable: Any], Never>()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /**
     申请通知授权。

     - Returns: 是否获得授权。
     - Throws: `LocalNotificationError`。
     */
    public func requestAuthorization() async throws -> Bool {
        // 待实现：包装 requestAuthorization(options:)，失败映射为 LocalNotificationError
    }

    /**
     调度一条本地通知。

     - Parameter title: 通知标题。
     - Parameter body: 通知内容。
     - Parameter identifier: 通知标识；相同标识会更新已存在的通知而非新增（系统层去重），默认随机 UUID。
     - Parameter userInfo: 随通知携带的载荷，业务路由标识由调用方塞入。
     - Parameter interval: 触发延迟（秒），默认 0.1。
     */
    public func schedule(title: String,
                         body: String,
                         identifier: String = UUID().uuidString,
                         userInfo: [String: Any] = [:],
                         after interval: TimeInterval = 0.1) {
        // 待实现：构造 UNMutableNotificationContent + UNTimeIntervalNotificationTrigger + UNNotificationRequest(identifier:)
    }

    /**
     移除指定标识的待投递与已投递通知。

     - Parameter identifiers: 通知标识数组。
     */
    public func remove(identifiers: [String]) {
        // 待实现：removePendingNotificationRequests(withIdentifiers:) + removeDeliveredNotifications(withIdentifiers:)
    }
}

@available(iOS 16.0, macOS 13.0, *)
extension LocalNotificationCenter: UNUserNotificationCenterDelegate {

    /// 用户点击通知
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        // 注意：delegate 回调线程不保证为主线程，send 前需确保切到主线程（本类为 @MainActor，实现时确认隔离或显式派发）
        let userInfo = response.notification.request.content.userInfo
        didTap.send(userInfo)
        completionHandler()
    }

    /// 应用在前台运行时的通知展示行为
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
```

---

## 5. 关键设计决策与理由

记录"为什么这么设计"，便于将来实施者（或 AI 助手）理解，不要在实现时擅自改掉这些决策：

- **用 `didTap` 抛 `userInfo`，而不是模块内部持有"待处理路由"状态。** 保持模块无业务状态，与上层完全解耦；上层拿到 `userInfo` 后自己解析成各自的路由类型并导航。
- **用稳定 `identifier` 去重，而不是每次随机 UUID。** 随机 id 会让重复触发堆叠成多条；稳定 id 让系统更新同一条。更激进的去重（同一逻辑事件短时间内连一次都不再呈现）属于业务层，由调用方按自己的生命周期处理。
- **授权用 `async throws`，而非 completion 回调。** 跟进本库的 async 化方向，调用更顺。
- **类标注 `@MainActor`。** 点击通知后通常要驱动 UI / 导航，主线程隔离更安全；与 `NavigationRouter` 的隔离方式保持一致。
- **不依赖、不引用 `NavigationRouter`。** 见第 3 节原则 2。这是本模块最重要的边界。

---

## 6. 与现有约定的衔接

- **日志：** 内部需要日志时使用本库的 `Log` / `DevelopmentKit.Log`，不要新引入日志方式。
- **错误：** 最终并入 `DevelopmentKitError`；在该统一类型落地前，使用 `LocalNotificationError` 并标注 TODO。
- **命名空间：** 模块挂在 `DevelopmentKit.LocalNotification` 下；`LocalNotificationCenter` 作为有状态单例可置于该命名空间相关文件中，命名风格与 `NavigationRouter` 对齐。
- **文件位置建议：** `Sources/DevelopmentKit/LocalNotification/`（如 `LocalNotificationCenter.swift`、`LocalNotificationError.swift`）。
- **平台：** `@available(iOS 16.0, macOS 13.0, *)`，与 `Package.swift` 声明一致。

---

## 7. 任务清单

- [ ] 新建命名空间 `DevelopmentKit.LocalNotification` 与目录 `Sources/DevelopmentKit/LocalNotification/`
- [ ] 实现 `LocalNotificationCenter`：授权（async）、调度（稳定 identifier + userInfo）、移除、delegate 接线、`didTap` 分发
- [ ] 定义 `LocalNotificationError`，并标注待并入 `DevelopmentKitError`
- [ ] 处理 delegate 回调的线程隔离（确保 `didTap.send` 在主线程）
- [ ] 为全部公开 API 补 `@available(iOS 16.0, macOS 13.0, *)`
- [ ] 为全部公开 API 写完整 SwiftDoc（`/** */`，无 emoji）
- [ ] 单元测试：
  - [ ] 调度后存在对应的 pending 请求
  - [ ] 相同 identifier 多次调度，pending 请求不堆叠（数量不增长）
  - [ ] `remove(identifiers:)` 后对应请求消失
  - [ ] 模拟点击后 `didTap` 发出对应 `userInfo`（授权用可注入的 mock，避免真实弹窗）
- [ ] 更新 `README.md` / `README_cn.md`，新增本模块章节与示例
- [ ] 更新 CHANGELOG 与版本号
- [ ] 提供一个**脱敏的**使用示例（见第 8 节）

---

## 8. 验收标准

- 零外部依赖，仅使用系统框架（`UserNotifications` / `Foundation` / `Combine`）。
- 所有公开 API 具备 SwiftDoc 与 `@available`。
- 不引用任何业务类型，不依赖 `NavigationRouter` 或本库其他有状态模块。
- 核心路径有单元测试覆盖。
- demo 能跑通完整链路：**调度通知 → 点击 → 上层从 `didTap` 拿到 `userInfo` → 自行导航**。

---

## 9. 使用示例（脱敏，放进 README）

展示"机制 / 策略分离"：库只负责把载荷带进通知、点击后抛出来；App 自己定义路由类型并解析。

```swift
import DevelopmentKit
import Combine

// 1. App 侧定义自己的路由类型（库不知道它的存在）
enum AppRoute: String {
    case detail
    case settings
}

// 2. 调度时，把路由标识塞进 userInfo，并用稳定 identifier 去重
LocalNotificationCenter.shared.schedule(
    title: "示例标题",
    body: "示例内容",
    identifier: "route.\(AppRoute.detail.rawValue)",
    userInfo: ["route": AppRoute.detail.rawValue]
)

// 3. App 侧订阅点击事件，自行解析并导航
var bag = Set<AnyCancellable>()
LocalNotificationCenter.shared.didTap
    .compactMap { ($0["route"] as? String).flatMap(AppRoute.init(rawValue:)) }
    .sink { route in
        // 由 App 决定如何导航（如驱动自己的 NavigationRouter / NavigationStack）
        switch route {
        case .detail:   /* 导航到详情 */ break
        case .settings: /* 导航到设置 */ break
        }
    }
    .store(in: &bag)
```

---

## 10. 未来可选扩展（非首版范围）

- 通知分类与动作按钮（`UNNotificationCategory` / `UNNotificationAction`）。
- 远程推送（APNs）载荷的统一解析入口，与本地通知共用 `didTap` 风格。
- 可选的"应用层去重 helper"：基于调用方提供的某个 reset 信号清空"已通知集合"，把原始场景里那套业务去重抽象成可选工具（需谨慎，避免把业务生命周期带进库）。
- 调度结果回执的 async/await 版本（当前 `schedule` 为 fire-and-forget）。

---

*本计划为归档文档。实施时如与本库当时的最新约定（错误体系、命名、平台版本）有出入，以仓库现状为准，并据此调整本文件。*
