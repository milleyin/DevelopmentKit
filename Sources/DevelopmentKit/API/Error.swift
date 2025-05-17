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

extension DevelopmentKit.SysInfo {
    /**
     系统信息相关错误定义
    
     - Important: `SysInfoError` 是 `DevelopmentKit.SysInfo` 模块中所有系统信息函数可能抛出的错误合集，适用于内存、CPU、电池、磁盘等信息接口。
    
     - Warning: 某些错误如 `.unknown` 包裹了原始错误对象，适合用于日志追踪与上报分析。
    
     - Note: 所有错误均符合 `Swift.Error` 协议，便于 `Combine` 异步链路的 `.catch`、`.mapError` 等操作使用。
    
     使用示例：
     ```swift
     .sink(receiveCompletion: { completion in
         if case .failure(let error as SysInfoError) = completion {
             switch error {
             case .memoryReadFailure: ...
             case .unknown(let underlying): ...
             }
         }
     })
     ```
     */
    public enum SysInfoError: Swift.Error {
        
        /// 无法获取磁盘剩余空间（路径无效、权限受限或系统错误）
        case diskSpaceUnavailable
        
        /// 无法读取系统内存信息（`host_statistics64` 调用失败）
        case memoryReadFailure
        
        /// 无法获取 CPU 快照（可能是 `host_processor_info` 失败）
        case cpuSnapshotFailed
        
        /// CPU 占用率计算失败（数据结构异常或除以零）
        case cpuCalculationFailed
        
        /// 电池服务不可用（如台式机、无电池设备）
        case batteryUnavailable
        
        /// 无法读取电池温度（`AppleSmartBattery` 数据缺失）
        case temperatureUnavailable
        
        /// 未知错误（将其他系统错误封装）
        case unknown(Error)
    }
}
