//
//  Extension.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import CryptoKit
import CommonCrypto
//#endif

// MARK: - 日期扩展

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

// MARK: - UIApplication 扩展

#if os(iOS)
extension UIApplication {
    /**
     隐藏键盘。
     
     - Important: 该方法使用 `UIResponder.resignFirstResponder`，
       通过 `sendAction` 方式使当前第一响应者失去焦点，从而关闭键盘。
     - Attention: 仅适用于 iOS 设备，macOS 和其他平台不支持。
     - Note: 适用于需要手动关闭键盘的场景，
       例如点击空白区域时。
     
     示例：
     
     ```swift
     UIApplication.shared.hideKeyboard()
     ```
     */
    public func hideKeyboard() {
        self.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif


// MARK: - String 扩展

extension String {
    /**
     使用正则表达式验证字符串。
     
     - Important: 该方法使用 `NSRegularExpression` 进行正则匹配，
       可用于格式验证，如邮箱、手机号等。
     - Attention: 如果正则表达式无效，则会捕获异常并返回 `false`。
     - Parameters:
       - pattern: 用于匹配的正则表达式。
     - Returns: 如果匹配成功，则返回 `true`，否则返回 `false`。
     
     示例：
     
     ```swift
     let isValid = "test@example.com".regexValidation(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
     print(isValid) // true
     ```
     */
    public func regexValidation(pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: self.utf16.count)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return false
        }
    }

    /**
     将字符串转换为 `Date` 类型。
     
     - Important: 该方法使用 `DateFormatter` 进行日期转换。
     - Parameters:
       - format: 日期格式，默认为 `yyyy-MM-dd`。
     - Returns: 转换后的 `Date` 对象，如果格式错误则返回 `nil`。
     
     示例：
     
     ```swift
     let date = "2025-02-28".toDate()
     print(date)
     ```
     */
    public func toDate(format: String = "yyyy-MM-dd") -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.date(from: self)
    }

    /**
     计算字符串的 SHA-256 哈希值。
     
     - Important: 该方法使用 `CC_SHA256` 进行哈希计算，
       适用于密码存储、数据完整性校验等场景。
     - Returns: 计算得到的 SHA-256 哈希字符串。
     
     示例：
     
     ```swift
     let hash = "hello".sha256
     print(hash)
     ```
     */
    public var sha256: String {
        let inputData = Data(self.utf8)
        let hashed = inputData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(inputData.count), &hash)
            return hash
        }
        return hashed.map { String(format: "%02hhx", $0) }.joined()
    }
}
