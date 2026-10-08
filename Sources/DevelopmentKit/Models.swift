//
//  File.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/10.
//

import Foundation
/**
 网络连接类型枚举

 - Important: 用于替代字符串描述，提升类型安全与可读性
 */
public enum NetworkType: String {
    case wifi = "Wi-Fi"
    case wired = "有线网络"
    case cellular = "蜂窝网络"
    case other = "其他网络"
    case none = "无网络连接"
    case unknown = "未知"
}

/**
 网络相关错误定义

 - Important: 所有网络状态判断失败时抛出的错误
 */
public enum NetworkError: Swift.Error {
    /// 初始化失败
    case monitorInitializationFailed

    /// 路径判断失败
    case unableToDetermineNetworkType

    /// 超时未返回
    case timeout
}


/// Wi-Fi 信号等级
public enum WiFiSignalLevel: String {
   case excellent = "极佳"
   case good = "良好"
   case fair = "一般"
   case weak = "较差"
   case poor = "极差"
   case disconnected = "未连接"
}

/// 网络吞吐结构（单位：Bytes per second）
public struct SystemNetworkThroughput {
    public let receivedBytesPerSec: UInt64
    public let sentBytesPerSec: UInt64
}

/// 电池信息结构体
public struct MacBatteryInfo {
    /// 电池电量百分比
    public var level: Int
    /// IOPS 的 Max Capacity。Apple 电源按 IOPSKeys.h 约定以百分比发布（通常为 100），不是 mAh 容量
    public var maxCapacity: Int
    /// 充电状态
    /// 是否接着外部电源：取自 IOPS `kIOPSPowerSourceStateKey` 是否为 `kIOPSACPowerValue`
    /// - Important: 不等于"电池正在充电"。接着电源但没有充电时此值仍为 `true`，常见于：
    ///     - 优化电池充电把电量停在 80%（此时 `pmset -g batt` 显示 "AC attached; not charging"）；
    ///     - 已达到设定的充电上限（macOS 26.4 起的 Apple 芯片机型）；
    ///     - 电池已充满。
    /// 沿用"接着电源"的语义是有意的决定，改读 `kIOPSIsChargingKey` 会改变现有行为。需要"是否正在充电"时，公开来源是 IOPS 的 `kIOPSIsChargingKey`，本结构体目前未提供该字段。
        
    public var isCharging: Bool
    /// 电池温度（摄氏度）。系统未通过公开接口提供时为 nil（例如 macOS 27）
    public var temperature: Double?
    /// 循环次数。系统未通过公开接口提供时为 nil
    public var cycleCount: Int?
    
    public init(level: Int = 0, maxCapacity: Int = 0, isCharging: Bool = false, temperature: Double? = nil, cycleCount: Int? = nil) {
        self.level = level
        self.maxCapacity = maxCapacity
        self.isCharging = isCharging
        self.temperature = temperature
        self.cycleCount = cycleCount
    }
}
///内存结构
public struct MacMemoryInfo: CustomStringConvertible {
    public let total: Double
    public let free: Double
    public let used: Double
    public let inactive: Double

    public init(total: Double, free: Double, used: Double, inactive: Double) {
        self.total = total
        self.free = free
        self.used = used
        self.inactive = inactive
    }

    /// 打印友好的文字描述
    public var description: String {
        """
        💾 内存状态：
        - 总内存：\(total) GB
        - 空闲内存：\(free) GB
        - 已使用内存：\(used) GB
        - 可回收内存（Inactive）：\(inactive) GB
        """
    }
}
///cpu数据结构
public struct MacCPUInfo {
    /// 型号 / 名称
    public let model: String
    /// 物理核心数
    public let physicalCores: Int
    /// 逻辑核心数（包含超线程）
    public let logicalCores: Int
    /// 总体占用率（单位：%）
    public let totalUsage: Double
    /// 总体空闲率（单位：%）
    public let totalIdle: Double
    /// 每个核心使用率 [%]，顺序与 core index 一致
    public let coreUsages: [Double]
    
    public var description: String {
        let coreList = coreUsages.enumerated()
            .map { "  - Core \($0.offset): \($0.element.rounded(toPlaces: 2))%" }
            .joined(separator: "\n")
        return """
            🧠 CPU 型号：\(model)
            🔩 物理核心数：\(physicalCores)
            🔢 逻辑核心数：\(logicalCores)
            ⚙️ 总体占用：\(totalUsage.rounded(toPlaces: 2))%
            💤 总体空闲：\(totalIdle.rounded(toPlaces: 2))%
            💡 每核心占用：
            \(coreList)
            """
    }
}
