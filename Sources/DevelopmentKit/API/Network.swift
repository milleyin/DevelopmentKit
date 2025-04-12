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

extension DevelopmentKit.Network {
    /**
     获取当前网络连接类型（Combine 异步版）
     
     - Important: 使用 `NWPathMonitor` 检测网络状态，返回一次性 Publisher。
     - Warning: 本方法不会持续监听，仅返回当前网络状态。
     - Note: 超时时间默认为 0.5 秒，可调整。
     - Parameter timeout: 超时时间（秒），默认 0.5 秒。
     - Returns: `AnyPublisher<NetworkType, NetworkError>`
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
