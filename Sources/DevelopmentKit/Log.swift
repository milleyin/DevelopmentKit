//
//  Log.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/26.
//

import Foundation

extension DevelopmentKit {
    
    /**
     记录日志信息，自动添加时间戳、文件名和行号

     - Important: 该方法用于调试和日志记录，支持泛型参数
     - Attention: `file` 默认使用 `#file` 获取当前文件名
     - Bug: 目前无已知 Bug
     - Warning: `logDateFormatter` 仅限 `Log.swift` 内部使用，避免外部修改
     - Requires: `Foundation` 框架支持
     - Remark: `logDateFormatter` 统一格式化时间，避免 `DateFormatter` 频繁创建
     - Note: `print` 输出格式为 `[yyyy-MM-dd HH:mm:ss]<文件名:行号>: 日志内容`
     - Precondition: `message` 必须能够转换为 `String`
     - Postcondition: 日志信息已打印到 Xcode 控制台
     
     示例：
     ```swift
     DevelopmentKit.Log("测试日志输出")
     ```
     输出：
     ```
     [2025-02-26 18:00:30]<MainView.swift:42>: 测试日志输出
     ```

     - parameter message: 需要记录的日志内容
     - parameter file: 调用该方法的文件路径，默认使用 `#file`
     - parameter line: 调用该方法的代码行号，默认使用 `#line`
     - Returns: 无返回值
     - Throws: 无异常抛出
     */
    public static func Log<T>(_ message: T,
                              file: String = #file,
                              line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timeStamp = Self.logDateFormatter.string(from: Date())
        let logMessage = "[\(timeStamp)]<\(fileName):\(line)>: \(message)"
        //`print` 输出到 console
        print(logMessage)
        
        //写入 CloudKit（如果可用）
        Task {
            await CloudKitManager.saveLogToCloud(logMessage, file: file, line: line)
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
    fileprivate static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

