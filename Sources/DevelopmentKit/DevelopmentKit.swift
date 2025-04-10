// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  DevelopmentKit.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2024/11/7.
//

import Foundation
import SafariServices
import CoreLocation
import MapKit
import Network
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import CoreWLAN
import IOKit
import IOKit.ps
import Darwin //NOTE: ifaddrs/if_data 等结构体来自 Darwin 系统库，无需 import，使用时只需 `import Darwin`
#endif

//public enum DevelopmentKit {
//    
//    public static let version: String = "0.0.5(2025038)"
//
//    /// 网络功能命名空间
//    public enum Network {}
//}

public class DevelopmentKit {
    
    /// DevelopmentKit 版本号
    public static let version: String = "0.0.5(2025038)"
    
    private var subscriptions = Set<AnyCancellable>()
    
    init () { }
    
    deinit {
        self.subscriptions.forEach { $0.cancel() }
    }
    
    /**
         网络相关功能集合

         - Important: 所有网络工具方法请挂载到此命名空间。
         - Usage:
         ```swift
         DevelopmentKit.Network.getLocalIPAddress()
         DevelopmentKit.Network.getNetworkTypePublisher()
         ```
         - Includes:
            * 网络类型检测
            * 信号强度获取
            * 上下行速率监测
            * 内网 IP 读取
            * 后续扩展（如 DNS、Ping）
         */
    public enum Network {}
}

//MARK: - 网络类接口

extension DevelopmentKit {
    
    /**
     获取当前网络连接类型（Combine 异步版）
     
     - Important: 使用 `NWPathMonitor` 检测网络状态，返回一次性 Publisher。
     - Warning: 本方法不会持续监听，仅返回当前网络状态。
     - Note: 超时时间默认为 0.5 秒，可调整。
     - Parameter timeout: 超时时间（秒），默认 0.5 秒。
     - Returns: `AnyPublisher<NetworkType, NetworkError>`
     */
    public static func getNetworkTypePublisher(timeout: TimeInterval = 0.5) -> AnyPublisher<NetworkType, NetworkError> {
        let subject = PassthroughSubject<NetworkType, NetworkError>()
        let monitor = NWPathMonitor()
        let queue = DispatchQueue.global(qos: .background)
        
        let state = State()
        
        func resolve(_ type: NetworkType) {
            state.resolveOnce {
                subject.send(type)
                subject.send(completion: .finished)
                monitor.cancel()
            }
        }
        
        func fail(_ error: NetworkError) {
            state.resolveOnce {
                subject.send(completion: .failure(error))
                monitor.cancel()
            }
        }
        
        monitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                resolve(.wifi)
            } else if path.usesInterfaceType(.cellular) {
                resolve(.cellular)
            } else if path.usesInterfaceType(.wiredEthernet) {
                resolve(.wired)
            } else if path.usesInterfaceType(.other) {
                resolve(.other)
            } else if path.status == .unsatisfied {
                resolve(.none)
            } else {
                fail(.unableToDetermineNetworkType)
            }
        }
        
        monitor.start(queue: queue)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            fail(.timeout)
        }
        
        return subject.eraseToAnyPublisher()
    }
    
#if os(macOS)
    
    /**
     根据 RSSI 值转换为信号等级
     
     - Parameter rssi: Wi-Fi RSSI（单位 dBm）
     - Returns: 对应的 `WiFiSignalLevel`
     */
    private static func signalLevel(from rssi: Int?) -> WiFiSignalLevel {
        guard let rssi = rssi else {
            return .disconnected
        }
        
        switch rssi {
        case (-50)...0:
            return .excellent
        case (-65)...(-51):
            return .good
        case (-75)...(-66):
            return .fair
        case (-85)...(-76):
            return .weak
        default:
            return .poor
        }
    }
    
    /**
     获取当前 Wi-Fi 信号等级（每秒更新一次）
     
     - Returns: `AnyPublisher<WiFiSignalLevel, Never>`
     */
    public static func getWiFiSignalLevelPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<WiFiSignalLevel, Never> {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in
                let rssi = CWWiFiClient.shared().interface()?.rssiValue()
                return signalLevel(from: rssi)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /**
     获取当前系统级网络吞吐量（上下行）
     
     - Parameter interval: 检查频率（秒），默认 1 秒
     - Returns: 实时网络吞吐 Publisher
     */
    public static func getSystemNetworkThroughputPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<SystemNetworkThroughput, Never> {
        
        /// 每次定时执行，返回当前吞吐数据
        func getThroughput() -> (rx: UInt64, tx: UInt64) {
            var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
                return (0, 0)
            }
            
            var rxBytes: UInt64 = 0
            var txBytes: UInt64 = 0
            
            var ptr = firstAddr
            while ptr.pointee.ifa_next != nil {
                let interface = ptr.pointee
                let name = String(cString: interface.ifa_name)
                
                // 排除 lo0 等非活跃接口
                if name.hasPrefix("en") || name.hasPrefix("awdl") || name.hasPrefix("pdp_ip") {
                    if let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                        rxBytes += UInt64(data.pointee.ifi_ibytes)
                        txBytes += UInt64(data.pointee.ifi_obytes)
                    }
                }
                
                ptr = interface.ifa_next!
            }
            
            freeifaddrs(ifaddrPtr)
            return (rxBytes, txBytes)
        }
        
        var previous: (rx: UInt64, tx: UInt64)? = nil
        
        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in
                let current = getThroughput()
                defer { previous = current }
                
                guard let previous = previous else {
                    return SystemNetworkThroughput(receivedBytesPerSec: 0, sentBytesPerSec: 0)
                }
                
                let deltaRx = current.rx - previous.rx
                let deltaTx = current.tx - previous.tx
                
                return SystemNetworkThroughput(
                    receivedBytesPerSec: deltaRx,
                    sentBytesPerSec: deltaTx
                )
            }
            .eraseToAnyPublisher()
    }
#endif
    
    /**
     获取当前设备的内网 IPv4 地址（en0 / en1）
     
     - Returns: 字符串形式的 IPv4 地址，例如 "192.168.1.100"，若无则返回 nil
     - Note: iOS / macOS 通用
     */
    public static func getLocalIPAddress() -> String? {
        var address: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        
        var ptr = firstAddr
        while ptr.pointee.ifa_next != nil {
            let interface = ptr.pointee
            
            // IPv4 only（AF_INET），跳过 IPv6（AF_INET6）
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
                    // en = Wi-Fi / 有线，pdp_ip = 蜂窝网络
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
            
            ptr = interface.ifa_next!
        }
        
        freeifaddrs(ifaddr)
        return address
    }
}

// MARK: - 通用接口

extension DevelopmentKit {
    /**
     复制文本到剪贴板。

     - Important: 该方法使用 `UIPasteboard.general` 将文本复制到剪贴板。
     - Attention: 仅适用于 iOS 设备，macOS 不适用。
     - Warning: 该方法仅在 `UIKit` 可用时生效，
       在 `SwiftUI` 或其他非 `UIKit` 设备上可能无法运行。
     - Requires: 需要 `UIKit` 框架支持。
     - Note: 复制后的文本可以在任何支持粘贴功能的应用中使用。

     示例：

     ```swift
     copyToClipboard(text: "Hello, world!")
     ```
     */
    public static func copyToClipboard(text: String) {
    #if canImport(UIKit)
        UIPasteboard.general.string = text
    #endif
    }

    
    /**
     获取 App 名称。

     - Important: 该方法从 `Bundle.main.infoDictionary` 中读取 `CFBundleDisplayName`
       或 `CFBundleName` 以获取应用名称。
     - Attention: 如果 `CFBundleDisplayName` 为空，则回退到 `CFBundleName`。
     - Warning: 该方法可能会返回 `未知应用`，如果 `info.plist` 中没有正确配置应用名称。
     - Requires: 需要访问 `Bundle.main.infoDictionary`。
     - Note: 适用于所有 iOS 设备，可用于日志记录或 UI 展示应用名称。

     示例：

     ```swift
     let appName = getAppName()
     print("当前 App 名称: \(appName)")
     ```
     */
    public static func getAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ??
        "未知应用"
    }
    
    /**
     获取软件版本号。

     - Important: 该方法从 `Bundle.main.infoDictionary` 中读取 `CFBundleShortVersionString`
       以获取应用的当前版本号。
     - Attention: 如果 `CFBundleShortVersionString` 为空，则返回 `Unknown`。
     - Requires: 需要访问 `Bundle.main.infoDictionary`。
     - Note: 适用于所有 iOS 设备，可用于显示应用版本信息。

     示例：

     ```swift
     let version = appVersion
     print("当前软件版本: \(version)")
     ```
     */
    public static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /**
     获取编译版本号。

     - Important: 该方法从 `Bundle.main.infoDictionary` 中读取 `CFBundleVersion`
       以获取应用的编译版本号。
     - Attention: 如果 `CFBundleVersion` 为空，则返回 `Unknown`。
     - Requires: 需要访问 `Bundle.main.infoDictionary`。
     - Note: 适用于所有 iOS 设备，可用于显示应用的编译版本信息。

     示例：

     ```swift
     let build = buildNumber
     print("当前编译版本号: \(build)")
     ```
     */
    public static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    ///运行环境检测
    public static let isPreview: Bool = {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }()
}

//MARK: - 打开目的地接口

extension DevelopmentKit {
    
#if os(iOS)
    /**
     打开 iOS 设置内的当前 App 设置。
     
     - Important: 该方法会尝试打开 `UIApplication.openSettingsURLString`，
     以便用户直接跳转到本 App 在 iOS 设置中的界面。
     - Attention: 仅适用于 iOS 设备，在 macOS 上不可用。
     - Bug: 在某些情况下，系统可能不会正确响应 URL，建议用户手动检查。
     - Warning: 该方法依赖 `UIApplication.shared.open`，
     需要在主线程调用，建议在 `@MainActor` 环境中执行。
     - Requires: 需要 `UIApplication.shared.canOpenURL(url)` 返回 `true` 才能成功打开。
     - Note: 该方法适用于引导用户更改权限、通知或其他 App 相关设置。
     
     示例：
     
     ```swift
     openAppSettings()
     ```
     */
    @MainActor
    public static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
#elseif os(macOS)
    /**
     打开 macOS 系统设置。
     
     - Important: 该方法会尝试打开 `x-apple.systempreferences:`，
     以便用户访问 macOS 系统的偏好设置。
     - Attention: 仅适用于 macOS 设备，在 iOS 上不可用。
     - Bug: 在某些情况下，URL 可能无法正确解析，建议用户手动检查。
     - Warning: 该方法使用 `NSWorkspace.shared.open(url)`，
     需要确保 `NSWorkspace` 具有适当的权限来访问系统设置。
     - Requires: 需要 `NSWorkspace.shared.open(url)` 成功执行，才能正确打开设置。
     - Note: 该方法适用于引导用户修改系统级别的设置，如网络、权限或显示选项。
     
     示例：
     
     ```swift
     openAppSettings()
     ```
     */
    public static func openAppSettings() {
        guard let url = URL(string: "x-apple.systempreferences:") else {
            print("无法打开系统设置")
            return
        }
        NSWorkspace.shared.open(url)
    }
#endif
    
#if os(iOS)
    /**
     打开网页链接。
     
     - Important: 该方法会尝试打开指定的 URL。
     在 iOS 16.0 及以上版本，会使用 `SFSafariViewController` 进行网页展示。
     - Attention: 仅适用于 iOS 设备，macOS 不适用。
     - Bug: 如果 `urlString` 无效或无法解析，则方法不会执行任何操作。
     - Warning: 低于 iOS 16.0 的设备不支持 `SFSafariViewController`，
     可能需要额外处理。
     - Requires: 需要传入有效的 `urlString`，否则不会执行任何操作。
     - Note: 该方法适用于在 App 内部打开网页，而不是跳转到外部 Safari 浏览器。
     
     示例：
     
     ```swift
     openWebLink(urlString: "https://www.apple.com")
     ```
     */
    @MainActor
    public static func openWebLink(urlString: String) {
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
#elseif os(macOS)
    public static func openWebLink(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("无效的 URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
#endif
    
#if os(iOS)
    /**
     在 iOS 设备上打开邮件应用。
     
     - Important: 该方法使用 `message://` URL 以尝试打开邮件应用。
     - Attention: 仅适用于 iOS 设备，macOS 不支持此方法。
     - Bug: 在部分设备或系统版本上，可能无法正确响应 `message://` URL。
     - Warning: 该方法依赖 `UIApplication.shared.open(url)`，必须在主线程调用，建议在 `@MainActor` 环境中执行。
     - Requires: 设备必须安装邮件应用，并支持 `UIApplication.shared.canOpenURL(url)`。
     - Returns: 无返回值。
     - Throws: 无异常抛出。
     - Note: 如果设备上未安装邮件应用，该方法不会有任何作用。
     
     ### 示例：
     ```swift
     openMailApp()
     ```
     */
    @MainActor
    public static func openMailApp() {
        guard let url = URL(string: "message://"), UIApplication.shared.canOpenURL(url) else {
            print("无法打开邮件应用")
            return
        }
        UIApplication.shared.open(url)
    }
#endif
    
#if os(macOS)
    /**
     在 macOS 设备上打开默认邮件客户端。
     
     - Important: 该方法使用 `mailto:` URL 以尝试打开默认邮件客户端。
     - Attention: 仅适用于 macOS 设备，iOS 不支持此方法。
     - Bug: 在部分 macOS 版本上，可能无法正确解析 `mailto:` URL。
     - Warning: 该方法依赖 `NSWorkspace.shared.open(url)`，不会检查邮件客户端的可用性。
     - Requires: 设备必须安装邮件客户端，并支持 `NSWorkspace.shared.open(url)`。
     - Returns: 无返回值。
     - Throws: 无异常抛出。
     - Note: 如果设备上未安装邮件客户端，该方法不会有任何作用。
     
     ### 示例：
     ```swift
     openMailApp()
     ```
     */
    public static func openMailApp() {
        guard let url = URL(string: "mailto:") else {
            print("无法打开邮件应用")
            return
        }
        NSWorkspace.shared.open(url)
    }
#endif
}

//MARK: - 系统信息类

extension DevelopmentKit {
#if os(iOS)
/// 持续监听 iOS 电池电量变化
public static func getBatteryLevelPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<Int, Never> {
    // 确保设备支持电池监测
    UIDevice.current.isBatteryMonitoringEnabled = true
    
    // 每隔 interval 秒获取一次电池电量
    return Timer.publish(every: interval, on: .main, in: .common)
        .autoconnect()  // 启动计时器
        .map { _ in
            Int(UIDevice.current.batteryLevel * 100)  // 返回百分比
        }
        .eraseToAnyPublisher()
}
#elseif os(macOS)
    /// 获取 macOS 电池电量（百分比，0 到 100）
        public static func getBatteryLevelPublisher() -> AnyPublisher<Int, Never> {
            return Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .map { _ in
                    return getMacBatteryLevel()
                }
                .eraseToAnyPublisher()
        }

        /// 获取 macOS 电池电量（百分比，0 到 100）
        private static func getMacBatteryLevel() -> Int {
            var level = 0
            _ = IOPSCopyPowerSourcesInfo()

            // 获取电池信息快照
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
                return level  // 无法获取电池信息快照，返回 0
            }

            // 获取电池源列表
            guard let sources: NSArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
                return level  // 无法获取电池源，返回 0
            }

            // 遍历每个电池源
            for ps in sources {
                // 获取每个电池源的信息
                guard let info: NSDictionary = IOPSGetPowerSourceDescription(snapshot, ps as CFTypeRef)?.takeUnretainedValue() else {
                    continue  // 如果获取电池信息失败，则跳过
                }

                // 从电池信息字典中提取容量和电量
                if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                   let maxCapacity = info[kIOPSMaxCapacityKey] as? Int {
                    level = Int((Float(capacity) / Float(maxCapacity)) * 100)
                    break  // 获取到电池信息后直接跳出循环
                }
            }
            
            return level
        }
#endif
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
    DevelopmentKit.isPreview
}


//MARK: - 内部扩展

extension DevelopmentKit {
    // 封装状态控制，避免并发访问 resolved
    final private class State {
        var resolved = false
        func resolveOnce(_ block: () -> Void) {
            guard !resolved else { return }
            resolved = true
            block()
        }
    }
}
