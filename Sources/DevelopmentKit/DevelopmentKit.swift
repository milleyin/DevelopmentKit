// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  DevelopmentKit.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2024/11/7.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import SafariServices
import CoreLocation
import MapKit
import Network
import CryptoKit
import CommonCrypto
#endif

// MARK: - 运行环境检测
/**
 运行环境检测，判断是否在 SwiftUI 预览模式下

 - Returns: `true` 表示当前代码在 SwiftUI 预览模式运行
 */
public let isPreview: Bool = {
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}()

// MARK: - iOS 专属功能
#if os(iOS)

/// 打开系统邮箱 App
/**
 通过 `UIApplication.shared.open()` 方式打开系统邮件应用

 - Important: 该方法仅适用于 iOS 设备
 - Warning: 如果用户未安装邮件应用，该方法不会执行任何操作
 */
@MainActor
public func openMailApp() {
    guard let url = URL(string: "message://"), UIApplication.shared.canOpenURL(url) else {
        print("无法打开邮件应用")
        return
    }
    UIApplication.shared.open(url)
}

/// 打开 iOS 设置内的本 App 设置
/**
 直接跳转到 iOS 系统设置中的当前应用设置页面

 - Important: 该方法仅适用于 iOS 设备
 - Warning: 如果无法获取 `UIApplication.openSettingsURLString`，该方法不会执行任何操作
 */
@MainActor
public func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
        return
    }
    UIApplication.shared.open(url)
}

/// 打开网页链接
/**
 使用 `SFSafariViewController` 在应用内打开网页

 - Important: 该方法仅适用于 iOS 设备
 - Warning: 仅适用于 iOS 16.0 及以上版本，低版本将打印错误信息

 - parameter urlString: 要打开的网页 URL 字符串
 */
@MainActor
public func openWebLink(urlString: String) {
    guard let url = URL(string: urlString) else {
        print("无效的 URL")
        return
    }
    
    if #available(iOS 16.0, *) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("无法获取 Root View Controller")
            return
        }
        let safariVC = SFSafariViewController(url: url)
        rootVC.present(safariVC, animated: true)
    } else {
        print("iOS 版本过低，不支持打开 Safari")
    }
}

/// 获取当前网络类型（iOS 16+ 兼容）
/**
 通过 `NWPathMonitor` 检测当前设备的网络类型

 - Important: 该方法适用于 iOS 16 及以上版本
 - Warning: 由于使用 `DispatchSemaphore`，可能会阻塞 0.5 秒

 - Returns: 网络类型（如 `"Wi-Fi"`、`"蜂窝移动网络"`、`"有线网络"`、`"无网络连接"`）
 */
public func getNetworkType() -> String {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue.global(qos: .background)
    var networkType = "未知"

    let semaphore = DispatchSemaphore(value: 0)

    monitor.pathUpdateHandler = { path in
        DispatchQueue.main.async {
            if path.usesInterfaceType(.wifi) {
                networkType = "Wi-Fi"
            } else if path.usesInterfaceType(.cellular) {
                networkType = "蜂窝移动网络"
            } else if path.usesInterfaceType(.wiredEthernet) {
                networkType = "有线网络"
            } else if path.usesInterfaceType(.other) {
                networkType = "其他网络"
            } else {
                networkType = "无网络连接"
            }
        }
        
        monitor.cancel()
        semaphore.signal()
    }
    monitor.start(queue: queue)

    // 等待 0.5 秒确保获取到网络状态
    _ = semaphore.wait(timeout: .now() + 0.5)
    return networkType
}

/// 在 Apple Maps 中导航
/**
 使用 `MKMapItem.openMaps()` 跳转到 Apple 地图进行导航

 - Important: 仅支持 iOS 设备
 - Warning: 该方法不会检查 Apple Maps 是否已安装

 - parameter start: 出发地坐标（可选，默认为当前位置）
 - parameter destination: 目的地坐标
 - parameter destinationName: 目的地名称
 */
@MainActor
public func openInAppleMaps(start: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D, destinationName: String) {
    let startItem = start.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? MKMapItem.forCurrentLocation()
    let destinationItem = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    destinationItem.name = destinationName
    MKMapItem.openMaps(with: [startItem, destinationItem], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
}
#endif

// MARK: - 通用功能
/// 复制文本到剪贴板
/**
 将指定的文本复制到系统剪贴板

 - Important: 仅适用于 iOS 设备
 - Warning: 需要 `UIPasteboard` 访问权限

 - parameter text: 需要复制的文本
 */
public func copyToClipboard(text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #endif
}

/// 获取 App 名称
/**
 获取当前 App 的名称

 - Returns: App 名称，如果无法获取，则返回 `"未知应用"`
 */
public func getAppName() -> String {
    return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
           Bundle.main.infoDictionary?["CFBundleName"] as? String ??
           "未知应用"
}

/// 获取软件版本号
/**
 获取当前 App 的版本号

 - Returns: 版本号（如 `"1.0.0"`），如果无法获取，则返回 `"Unknown"`
 */
public var appVersion: String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
}

/// 获取编译版本号
/**
 获取当前 App 的编译版本号

 - Returns: 编译版本号（如 `"100"`），如果无法获取，则返回 `"Unknown"`
 */
public var buildNumber: String {
    return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
}

// MARK: - 日期扩展
extension Date {
    /**
     将日期转换为 `yyyy-MM-dd` 格式字符串

     - Returns: 形如 `"2024-02-25"` 的日期字符串
     */
    public func toYMDFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

// MARK: - Image 扩展
#if canImport(SwiftUI)
import SwiftUI
extension Image {
    /**
     使 `Image` 重复显示多次

     - parameter times: 重复次数
     - parameter spacing: 间距（默认为 `4`）
     - Returns: 一个包含 `HStack` 视图的 `some View`
     */
    public func repeating(_ times: Int, spacing: CGFloat = 4) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<times, id: \.self) { _ in
                self
            }
        }
    }
}
#endif

// MARK: - UIApplication 扩展
#if os(iOS)
extension UIApplication {
    /**
     隐藏键盘
     */
    public func hideKeyboard() {
        self.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - String 扩展
extension String {
    /**
     使用正则表达式验证字符串是否匹配指定模式

     - parameter pattern: 正则表达式模式
     - Returns: 如果字符串符合模式，返回 `true`；否则，返回 `false`
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
     将字符串转换为 `Date`

     - parameter format: 日期格式（默认 `"yyyy-MM-dd"`）
     - Returns: `Date` 对象，转换失败返回 `nil`
     */
    public func toDate(format: String = "yyyy-MM-dd") -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.date(from: self)
    }
    
    /**
     对字符串进行 `SHA-256` 加密

     - Returns: `SHA-256` 哈希后的字符串
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

// MARK: - Color & UIColor 扩展
#if canImport(SwiftUI)
extension Color {
    /**
     使用十六进制字符串初始化 `Color`
     
     - parameter hex: 颜色的十六进制值（如 `"#FF5733"`）
     */
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
#endif

#if canImport(UIKit)
extension UIColor {
    /**
     使用十六进制字符串初始化 `UIColor`
     
     - parameter hex: 颜色的十六进制值（如 `"#FF5733"`）
     - parameter alpha: 透明度（默认 `1.0`）
     */
    public convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hexFormatted = hexFormatted.replacingOccurrences(of: "#", with: "")

        var hexValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&hexValue)

        let red = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hexValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif

// MARK: - Double & Int 扩展
extension Double {
    /**
     将 Double 转换为百分比字符串

     - parameter decimals: 保留的小数位数（默认 `0`）
     - Returns: 格式化后的百分比字符串（如 `"23.5%"`）
     */
    public func toPercentage(decimals: Int = 0) -> String {
        let percentage = self * 100
        return String(format: "%.\(decimals)f%%", percentage)
    }
}

extension Int {
    /**
     将秒数转换为 `小时:分钟:秒` 格式字符串

     - parameter hoursOnly: 是否仅显示小时（默认为 `false`）
     - Returns: 转换后的时间字符串
     */
    public func intToTimeFormat(hoursOnly: Bool = false) -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hoursOnly {
            return String(format: "%02d", hours)
        } else {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
