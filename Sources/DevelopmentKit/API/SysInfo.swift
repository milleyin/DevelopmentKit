//
//  SysInfo.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation
import CoreWLAN
import Combine
import AppKit
import IOKit
import IOKit.ps
import Darwin //NOTE: ifaddrs/if_data 等结构体来自 Darwin 系统库，无需 import，使用时只需 `import Darwin`

extension DevelopmentKit.SysInfo {
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
    
    /// 获取 macOS 电池信息（电量、最大容量、充电状态、温度）
    public static func getBatteryInfoPublisher() -> AnyPublisher<MacBatteryInfo, Swift.Error> {
        return Future { promise in
            var service: io_service_t = 0
            
            // 打开电池服务
            let openResult = openBatteryService(&service)
            if openResult != kIOReturnSuccess {
                promise(.failure(NSError(domain: "BatteryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法打开电池服务"])))
                return
            }
            
            // 获取电池信息
            let batteryInfo = getMacBatteryInfo()
            if batteryInfo.temperature == -1 {
                promise(.failure(NSError(domain: "BatteryError", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法获取电池温度"])))
            } else {
                promise(.success(batteryInfo))
            }
            
            // 关闭电池服务
            closeBatteryService(service)
        }
        .eraseToAnyPublisher()
    }
    
    // 打开电池服务
    private static func openBatteryService(_ service: inout io_service_t) -> kern_return_t {
        service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service == 0 {
            return kIOReturnNotFound
        }
        return kIOReturnSuccess
    }
    
    // 关闭电池服务连接
    private static func closeBatteryService(_ service: io_service_t) {
        IOObjectRelease(service)
    }
    
    // 获取电池信息（电量、最大容量、充电状态、温度）
    private static func getMacBatteryInfo() -> MacBatteryInfo {
        var batteryInfo = MacBatteryInfo()
        
        _ = IOPSCopyPowerSourcesInfo()
        
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return batteryInfo  // 如果获取电池信息失败，返回默认值
        }
        
        guard let sources: NSArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
            return batteryInfo  // 如果获取电池源失败，返回默认值
        }
        
        // 遍历每个电池源
        for ps in sources {
            guard let info: NSDictionary = IOPSGetPowerSourceDescription(snapshot, ps as CFTypeRef)?.takeUnretainedValue() else {
                continue  // 如果获取电池信息失败，则跳过
            }
            
            // 获取电池最大容量、电量、充电状态
            if let capacity = info[kIOPSMaxCapacityKey] as? Int,
               let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int {
                batteryInfo.maxCapacity = capacity
                batteryInfo.level = Int((Float(currentCapacity) / Float(capacity)) * 100)
            }
            
            // 获取充电状态
            if let powerState = info[kIOPSPowerSourceStateKey] as? String {
                batteryInfo.isCharging = (powerState == kIOPSACPowerValue)
            }
            
            // 获取电池温度
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if service != 0 {
                let temp = getBatteryTemperature(service)
                if temp != -1 {
                    batteryInfo.temperature = temp
                }
                let cycleCount = getBatteryCycleCount(service)
                if cycleCount != -1 {
                    batteryInfo.cycleCount = cycleCount
                }
                IOObjectRelease(service)  // 释放服务
            }
            
            break  // 获取到电池信息后直接跳出循环
        }
        
        return batteryInfo
    }
    
    // 获取电池温度（摄氏度）
    private static func getBatteryTemperature(_ service: io_service_t) -> Double {
        let prop = IORegistryEntryCreateCFProperty(service,
                                                   "Temperature" as CFString?,  // 使用字符串 "Temperature" 来代替 Key.Temperature
                                                   kCFAllocatorDefault, 0)
        
        guard let temperatureProp = prop?.takeUnretainedValue() as? Double else {
            return -1  // 如果没有温度数据，返回 -1
        }
        
        // 从开尔文转为摄氏度
        let temperatureInCelsius = temperatureProp / 100.0
        
        return temperatureInCelsius
    }
    /// 获取电池循环次数
    private static func getBatteryCycleCount(_ service: io_service_t) -> Int {
        let prop = IORegistryEntryCreateCFProperty(service,
                                                   "CycleCount" as CFString?,
                                                   kCFAllocatorDefault, 0)
        guard let count = prop?.takeUnretainedValue() as? Int else {
            return -1
        }
        return count
    }
#endif
    
    
}

extension DevelopmentKit.SysInfo {
    
    /// 获取 macOS 内存信息（单位：GB）
    public static func getMemoryInfoPublisher() -> AnyPublisher<MacMemoryInfo, Swift.Error> {
        let HOST_VM_INFO64_COUNT = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        return Future<MacMemoryInfo, Swift.Error> { promise in
            var stats = vm_statistics64()
            var count = mach_msg_type_number_t(HOST_VM_INFO64_COUNT)
            let result = withUnsafeMutablePointer(to: &stats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }

            if result != KERN_SUCCESS {
                promise(.failure(NSError(domain: "MemoryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取内存信息"])))
                return
            }

            // 获取总内存
            var totalMemory: UInt64 = 0
            var sizeOfMem = MemoryLayout<UInt64>.size
            sysctlbyname("hw.memsize", &totalMemory, &sizeOfMem, nil, 0)

            let pageSize = UInt64(vm_kernel_page_size)
            let free = Double(stats.free_count) * Double(pageSize)
            let inactive = Double(stats.inactive_count) * Double(pageSize)
            let total = Double(totalMemory)
            let used = total - free

            func toGB(_ bytes: Double) -> Double {
                return (bytes / 1_073_741_824).rounded(toPlaces: 2)
            }

            let info = MacMemoryInfo(
                total: toGB(total),
                free: toGB(free),
                used: toGB(used),
                inactive: toGB(inactive)
            )

            promise(.success(info))
        }
        .eraseToAnyPublisher()
    }
}
