//
//  Network.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation
import Combine
import Network
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import CoreWLAN
import IOKit
import IOKit.ps
import Darwin
#endif

//MARK: -网络连接类型
extension DevelopmentKit.Network {
    /**
     获取当前网络连接类型（Combine 异步版，一次性采样）。
     
     - Important: 本方法使用 `NWPathMonitor` 进行网络状态判断，仅返回一次性结果，不会持续监听变化。
     返回值为枚举 `NetworkType`，表示当前所连接的网络接口类型（如 Wi-Fi、有线、蜂窝、无网络等）。
     
     - Note:
     - 支持平台：iOS、macOS；
     - 该方法会在后台线程启动一个 `NWPathMonitor` 实例并在首个回调后立即取消，避免资源浪费；
     - 支持传入超时设定，默认 0.5 秒，若在此时间内未收到网络状态回调，将返回 `.timeout` 错误；
     - 使用场景适合 UI 层状态展示、网络初始化逻辑判断等；
     - 若需持续监听网络状态，应使用自定义封装的 `NWPathMonitor` 管理类，不建议使用本方法。
     
     - Parameter timeout: 等待网络状态结果的最长时间（单位：秒），默认为 `0.5` 秒。
     
     - Returns: 一个 `AnyPublisher<NetworkType, NetworkError>`，返回当前网络类型或失败状态。
     
     - Throws: 本方法不会直接抛出异常，但 Publisher 可能通过 `.failure` 触发以下错误：
     - `.timeout`：在设定时间内未能获取网络状态；
     - `.unableToDetermineNetworkType`：回传的状态不属于已定义类型（极少见）。
     
     使用示例：
     
     ```swift
     getNetworkTypePublisher(timeout: 1.0)
     .sink(receiveCompletion: { completion in
     if case .failure(let error) = completion {
     print("网络类型获取失败：\(error)")
     }
     }, receiveValue: { networkType in
     print("当前网络类型：\(networkType)")
     })
     .store(in: &cancellables)
     ```
     */
    public static func getNetworkTypePublisher(timeout: TimeInterval = 0.5) -> AnyPublisher<NetworkType, NetworkError> {
        Future<NetworkType, NetworkError> { promise in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue.global(qos: .background)
            
            monitor.pathUpdateHandler = { path in
                if path.usesInterfaceType(.wifi) {
                    promise(.success(.wifi))
                } else if path.usesInterfaceType(.cellular) {
                    promise(.success(.cellular))
                } else if path.usesInterfaceType(.wiredEthernet) {
                    promise(.success(.wired))
                } else if path.usesInterfaceType(.other) {
                    promise(.success(.other))
                } else if path.status == .unsatisfied {
                    promise(.success(.none))
                } else {
                    promise(.failure(.unableToDetermineNetworkType))
                }
                monitor.cancel()
            }
            
            monitor.start(queue: queue)
        }
        .timeout(.seconds(timeout), scheduler: DispatchQueue.global())
        .eraseToAnyPublisher()
    }
}

//MARK: - Wi-Fi信号等级接口
extension DevelopmentKit.Network {
#if os(macOS)
    /**
     获取当前 macOS 设备的 Wi-Fi 讯号强度等级，以 Publisher 方式定时推送。
     
     - Important:
     本方法仅适用于 macOS 系统，使用 `CoreWLAN` 框架读取当前 Wi-Fi 接口的 RSSI 值（Received Signal Strength Indicator）。
     RSSI 会根据当前连接的网络状况动态变化，结果将映射为应用层定义的 `WiFiSignalLevel` 枚举值。

     - Attention:
     自 macOS 13 起，若要正常读取 RSSI 值，需满足以下条件（否则将始终返回 `.disconnected`）：
     1. **关闭 App Sandbox**（在 `.entitlements` 中设置 `com.apple.security.app-sandbox = false`）；
     2. **启用 Wi-Fi 权限**（添加 `com.apple.developer.networking.wifi-info = true` 到 `.entitlements`）；
     3. **在 Info.plist 中声明定位用途**（添加 `NSLocationWhenInUseUsageDescription` 字段）；
     4. **主动触发定位授权流程**（调用 `CLLocationManager().requestWhenInUseAuthorization()` 并 `startUpdatingLocation()`）。

     若缺少上述任一项，RSSI 将始终返回 `nil`，即便 Wi-Fi 已连接。

     - Note:
     - 返回值为自定义的 `WiFiSignalLevel` 类型，包括 `.excellent`, `.good`, `.fair`, `.weak`, `.poor`, `.disconnected` 等等级。
     - RSSI 原始单位为 dBm，范围约在 `-30 ~ -90`（越小表示讯号越差），本方法会将其转换为易读等级。
     - 使用 `Timer.publish` 实现定时检测，默认每秒推送一次，可通过 `interval` 参数自定义。
     - 连续相同等级将不会重复推送（通过 `removeDuplicates()` 处理）。
     
     - Parameter interval: 检测讯号等级的时间间隔（单位：秒），默认值为 `1.0` 秒。
     
     - Returns: 一个 `AnyPublisher<WiFiSignalLevel, Never>`，每隔指定时间推送当前 Wi-Fi 讯号等级。
     
     使用示例：
     
     ```swift
     getWiFiSignalLevelPublisher(interval: 2.0)
         .sink { level in
             print("当前 Wi-Fi 强度：\(level)")
         }
         .store(in: &cancellables)
     ```
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
    
#endif
}

//MARK: - 当前网络流量接口
extension DevelopmentKit.Network {
#if os(macOS)
    /**
     获取当前设备的网络吞吐率（每秒上传与下载的字节数），以定时器方式持续推送。
     
     - Important:
     - 本方法通过 `getifaddrs()` 遍历所有网络接口，并统计活跃接口的字节总量（`ifi_ibytes` 和 `ifi_obytes`）。每隔指定时间间隔采样两次并计算差值，得到每秒的网络吞吐率。
     - 仅限macOS
     
     - Note:
     - 接口统计仅包含 Wi-Fi (`en*`)、蜂窝 (`pdp_ip*`)、Airdrop (`awdl*`) 等活跃网络，不包含 `lo0`（本地回环）。
     - 返回的结果为 Byte/s（字节/秒），若需换算为 Kbps、Mbps，可在上层视图层转换。
     - 该方法使用 Combine 的 `Timer.publish` 进行定时驱动，并不会抛出错误（返回类型为 `Never`）。
     - 第一次回调时将返回 `(0, 0)`，作为基准采样点。
     
     - Parameter interval: 吞吐率计算的时间间隔（单位：秒），默认为 `1.0`。
     
     - Returns: 一个 `AnyPublisher<SystemNetworkThroughput, Never>`，定时返回每秒接收与发送的网络字节数。
     
     使用示例：
     
     ```swift
     getSystemNetworkThroughputPublisher(interval: 1.0)
     .sink { throughput in
     print("下载：\(throughput.receivedBytesPerSec) B/s")
     print("上传：\(throughput.sentBytesPerSec) B/s")
     }
     .store(in: &cancellables)
     ```
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
}

//MARK: - 获取IP地址接口
extension DevelopmentKit.Network {
    /**
     获取当前设备的本地 IPv4 地址（如 Wi-Fi 或蜂窝网络）。
     
     - Important: 本方法仅返回首个有效的 IPv4 地址，优先检测 `en*`（Wi-Fi / 有线）和 `pdp_ip*`（蜂窝）网卡。
     该方法使用 `getifaddrs` 遍历所有网络接口，并通过 `getnameinfo` 获取 IP 地址文本格式。
     
     - Note:
     - 本方法仅支持返回 **IPv4 地址**，不会处理 IPv6（即跳过 `AF_INET6`）。
     - 若设备当前无网络连接，或接口信息不可访问，将返回 `nil`。
     - 适用于 macOS 与 iOS 系统，部分场景下（如飞行模式、权限受限）可能会获取失败。
     - 返回值如：`192.168.1.104`（Wi-Fi）、`10.0.0.2`（蜂窝）等。
     
     - Returns: 当前设备的本地 IPv4 地址字符串，若无可用地址则返回 `nil`。
     
     使用示例：
     
     ```swift
     if let ip = getLocalIPAddress() {
     print("本机 IP 地址：\(ip)")
     } else {
     print("未连接任何网络")
     }
     ```
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

//MARK: - 内部函数
extension DevelopmentKit.Network {
    // 封装状态控制，避免并发访问 resolved
    final private class State {
        var resolved = false
        func resolveOnce(_ block: () -> Void) {
            guard !resolved else { return }
            resolved = true
            block()
        }
    }
    
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
}
