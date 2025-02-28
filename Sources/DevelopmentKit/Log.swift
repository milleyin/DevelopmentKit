//
//  Log.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/26.
//

import Foundation

extension DevelopmentKit {
    
    @MainActor
    public static func Log<T>(_ message: T,
                              file: String = #file,
                              line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timeStamp = Self.logDateFormatter.string(from: Date())
        let logMessage = "[\(timeStamp)]<\(fileName):\(line)>: \(message)"
        //`print` 输出到 console
        print(logMessage)
        
        Task {
            @MainActor in await LogLocalManager.shared.saveLog(message: "\(message)", file: fileName, line: line)
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

