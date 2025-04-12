// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  DevelopmentKit.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2024/11/7.
//

import Foundation

public enum DevelopmentKit {
    
    public static let version: String = "0.0.7(2025047)"

    /// 网络功能命名空间
    public enum Network {}
    /// 系统信息
    public enum SysInfo {}
    /// 实用工具
    public enum Utilities {}
}




// MARK: - 全局接口

/**
 记录日志信息。

 - Important: 该方法封装了 `DevelopmentKit.Log`，
   便于在 `console` 输出日志信息，并调用 `LogLocalManager` 进行本地存储。
 - Attention: 默认情况下，会记录调用该方法的文件名和行号，
   便于在日志中追踪具体的代码位置。
 - Bug: 如果 `LogLocalManager` 由于权限或存储限制无法写入文件，日志可能丢失。
 - Warning: 该方法仅在 `iOS/macOS` 设备上有效，
   并依赖 `FileManager` 存储日志。
 - Requires: 需要 `LogLocalManager` 进行本地存储，并确保日志目录存在。
 - Note:
   1. 日志存储路径：`Application Support/Logs/{BundleID}/{yyyy-MM-dd}.log`
   2. 日志格式：NDJSON，每条日志为独立 JSON 行。
   3. 触发写入条件：
      - **缓存日志 100 条** 或 **2 秒未写入** 时自动 flush。
      - **超过 10 条日志** 触发写入。

 示例：

 ```swift
 Log("应用启动成功")
 ```

 - Parameters:
   - message: 要记录的日志内容。
   - file: 调用该方法的文件路径，默认为 `#file`。
   - line: 调用该方法的代码行号，默认为 `#line`。
 */

public func Log<T>(_ message: T,
                   file: String = #file,
                   line: Int = #line) {
    DevelopmentKit.Log(message, file: file, line: line)
}

/**
 运行环境检测，判断当前代码是否在 SwiftUI 预览模式下执行。

 - Important: 该属性主要用于在 SwiftUI 预览 (`Xcode Previews`) 中执行特定逻辑，
   例如避免运行不兼容的代码或提供虚拟数据。
 - Attention: 仅适用于 `Xcode` 预览模式，在真实设备或模拟器上运行时，该值始终为 `false`。
 - Bug: 在某些情况下，环境变量可能无法正确传递，建议在 `DEBUG` 模式下手动检查是否正确。
 - Warning: 不要依赖该属性进行关键业务逻辑的判断，该值仅适用于调试和 UI 预览环境。
 - Requires: 需要 `ProcessInfo.processInfo.environment` 提供正确的 `XCODE_RUNNING_FOR_PREVIEWS` 变量。
 - Remark: 适用于 SwiftUI `PreviewProvider`，在普通 `Simulator` 或 `Device` 运行时，该值不会生效。
 - Note: 如果该值为 `true`，可用于返回模拟数据，避免真实网络请求或数据库操作。

 示例：

 ```swift
 if isPreview {
     print("当前处于 SwiftUI 预览模式")
 }
 ```

 - Returns:
   `true` 表示当前代码在 SwiftUI 预览模式 (`Xcode Previews`) 运行。
   `false` 则表示在正常运行环境。
 */
public func isPreview() -> Bool {
    DevelopmentKit.Utilities.isPreview
}



