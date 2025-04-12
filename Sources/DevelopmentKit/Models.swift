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
    var level: Int
    /// 最大电池容量
    var maxCapacity: Int
    ///充电状态
    var isCharging: Bool
    /// 电池温度 (单位：摄氏度)
    var temperature: Double
    /// 循环次数
    public var cycleCount: Int
    
    public init(level: Int = 0, maxCapacity: Int = 0, isCharging: Bool = false, temperature: Double = -1, cycleCount: Int = 0) {
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
