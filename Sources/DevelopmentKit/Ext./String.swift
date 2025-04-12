//
//  File.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation
import CryptoKit
import CommonCrypto

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
