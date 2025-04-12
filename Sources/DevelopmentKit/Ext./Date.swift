//
//  File.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation

extension Date {
    /**
     将 `Date` 转换为 `yyyy-MM-dd` 格式的字符串。

     - Important: 该方法使用 `DateFormatter` 进行格式化，
       确保日期始终按照 `yyyy-MM-dd` 格式返回。
     - Attention: `DateFormatter` 的创建会影响性能，
       如果需要频繁调用，建议使用 **静态实例** 避免重复创建。
     - Returns: 以 `yyyy-MM-dd` 格式返回的日期字符串。

     示例：

     ```swift
     let dateString = Date().toYMDFormat()
     print("当前日期: \(dateString)")
     ```
     */
    public func toYMDFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
