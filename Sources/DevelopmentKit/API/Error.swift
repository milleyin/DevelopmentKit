//
//  File.swift
//  DevelopmentKit
//
//  Created by mille on 2025/5/17.
//

import Foundation

extension DevelopmentKit.Network {
    /**
     Network 模块错误类型
     
     - Important: 用于描述 DevelopmentKit.Network 中所有与网络相关的错误场景。
     - Note: 除非另有说明，所有未显式枚举的底层 Error 都会归入 `.unknown`。
     
     - case timeout:                           获取网络类型超时
     - case unableToDetermineNetworkType:      无法确定网络类型
     - case wifiInterfaceUnavailable:          Wi-Fi 接口不可用
     - case unknown(Error):                    其他未知错误，附带底层 Error
     */
    public enum NetworkError: Swift.Error {
        /// 在指定超时时间内未能获取到网络状态（getNetworkTypePublisher）
        case timeout
        
        /// 无法根据 NWPathMonitor 判断出网络类型（getNetworkTypePublisher）
        case unableToDetermineNetworkType
        
#if os(macOS)
        /// 无法获取到 Wi-Fi 接口或 RSSI 值（getWiFiSignalLevelPublisher）
        case wifiInterfaceUnavailable
        /// 网络吞吐率采样失败（getSystemNetworkThroughputPublisher）
        case throughputUnavailable
#endif
        
        /// 其他未知错误，携带底层 Error（可用于包装 URLSession、JSON 解析等错误）
        case unknown(Error)
    }
}
