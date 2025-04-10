//
//  Log.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/26.
//

import Foundation

extension DevelopmentKit {
    
    // MARK: - 全局方法

    /**
     记录日志信息并存储到本地。

     - Important: 该方法会在 `console` 中输出日志，并使用 `LogLocalManager`
       以 NDJSON 格式存储日志。
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
    
    public static func Log<T>(_ message: T,
                              file: String = #file,
                              line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timeStamp = Self.logDateFormatter.string(from: Date())
        let logMessage = "[\(timeStamp)]<\(fileName):\(line)>: \(message)"
        print(logMessage)

        // 在外部先转成字符串，避免在 Task 中直接使用泛型 T
        let messageString = String(describing: message)

        Task { @MainActor in
            await LogLocalManager.shared.saveLog(message: messageString,
                                                 file: fileName,
                                                 line: line)
        }
    }


    /**
     统一的日期格式化工具，避免 `DateFormatter` 频繁创建

     - Important: 该 `DateFormatter` 仅在 `Log.swift` 内部使用
     - Attention: 请勿在外部直接访问 `logDateFormatter`
     - Warning: 仅允许 `fileprivate` 级别访问
     - Requires: `Foundation` 框架支持
     - Returns: 格式化的 `DateFormatter` 实例
     */
    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

