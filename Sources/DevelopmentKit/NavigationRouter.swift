//
//  NavigationRouter.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/3/1.
//

import SwiftUI

/**
 `NavigationRouter` 是一个全局的导航管理器，基于 `NavigationPath` 进行路径管理。
 该类采用单例模式，确保整个应用中使用相同的导航状态。

 - Important: 仅适用于 **iOS 16+** 和 **macOS 13+**，依赖 `NavigationPath`。
 - Requires: `@MainActor` 作用域，确保 UI 线程安全。
 - Warning: 该类不支持 `UIKit` 导航（如 `UINavigationController`），仅适用于 `SwiftUI NavigationStack`。

 ## 主要功能：
 1. **管理 `NavigationPath`**，用于 `NavigationStack` 的路径控制。
 2. **单例模式**，提供 `shared` 实例，确保全局导航路径统一。
 3. **提供 `reset()` 方法**，清空当前导航路径，恢复初始状态。

 ## 用法示例：
 ```swift
 NavigationRouter.shared.path.append(MyDestinationView())
 NavigationRouter.shared.reset() // 清空导航路径
 ```

 - Author: 用户
 - Version: 1.0.0
 */
@MainActor
public final class NavigationRouter: ObservableObject {
    
    /// `NavigationRouter` 单例，确保全局导航路径一致
    public static let shared = NavigationRouter()
    
    /// 存储 `NavigationPath`，用于 SwiftUI `NavigationStack` 管理导航层级
    @Published public var path: NavigationPath = .init()
    
    /**
     `NavigationRouter` 私有初始化，防止外部实例化。
     
     - Important: 该类应通过 `NavigationRouter.shared` 访问，而非自行创建实例。
     */
    private init() {}

    /**
     重置导航路径，将 `path` 设为空 `NavigationPath`，恢复初始状态。

     - Note: 适用于需要返回根视图的场景，例如登出、流程重置等。
     - Example:
     ```swift
     NavigationRouter.shared.reset()
     ```
     */
    public func reset() {
        self.path = NavigationPath()
    }
}
