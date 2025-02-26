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
#if os(iOS)
import CryptoKit
import CommonCrypto
#endif

// MARK: - 日期扩展
extension Date {
    public func toYMDFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

// MARK: - UIApplication 扩展
#if os(iOS)
extension UIApplication {
    public func hideKeyboard() {
        self.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - String 扩展
extension String {
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

    public func toDate(format: String = "yyyy-MM-dd") -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.date(from: self)
    }

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
