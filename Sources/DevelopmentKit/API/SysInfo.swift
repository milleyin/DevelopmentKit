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

//MARK: - 电池信息接口
extension DevelopmentKit.SysInfo {
#if os(iOS)
    /**
     获取当前 iOS 设备的电池电量百分比（0~100），以 Publisher 方式定时推送。
     
     - Important: 本方法使用 `UIDevice.current.batteryLevel` 获取电量值。
     该接口必须启用电池监控（`UIDevice.current.isBatteryMonitoringEnabled = true`）才能生效。
     电量值以定时器方式定期更新，适合用于 UI 显示、电量监控图表等用途。
     
     - Note:
       - 电量值为浮点值（0.0 ~ 1.0），此处已转换为整数百分比（0 ~ 100）。
       - 初始值可能为 -1，表示尚未加载电量信息，可等待下一轮推送。
       - 该接口使用 Combine 的 `Timer.publish` 实现定时回调，不会产生任何错误或中断。
       - 使用频率可通过 `interval` 参数灵活控制，避免不必要的性能消耗。
     
     - Parameter interval: 推送电量信息的时间间隔（秒），默认为 `1.0`。
     
     - Returns: 一个 `AnyPublisher<Int, Never>`，每隔指定时间返回当前电池电量（0~100）。
     
     使用示例：

     ```swift
     getBatteryLevelPublisher(interval: 2.0)
         .sink { level in
             print("当前电量：\(level)%")
         }
         .store(in: &cancellables)
     ```
     */
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
    
    /**
     获取当前 macOS 设备的电池信息，包括电量、电池最大容量、充电状态、电池温度与循环次数。
     
     - Important: 本方法使用 `IOKit` 框架访问底层电池服务，仅适用于 macOS。
     需要运行在具有电池硬件的设备（如 MacBook），部分台式机（如 Mac mini / Mac Studio）可能返回空值或失败。

     - Note:
       - 电池温度单位为 **摄氏度**，通过 `AppleSmartBattery` 服务获取的原始值已转换为可读单位。
       - 当温度无法获取时（返回值为 -1），Publisher 将输出 `.failure`。
       - 所有电池信息均为当前状态的一次性采样，非持续监听。
       - 循环次数可用于评估电池健康状况，通常 Apple 建议 Mac 电池循环不超过 1000 次。

     - Returns: 一个 `AnyPublisher<MacBatteryInfo, Swift.Error>`，成功时返回封装的 `MacBatteryInfo`，失败时返回错误信息。

     - Throws: 本方法不会直接抛出异常，但可能通过 Publisher 输出以下错误：
        - 电池服务无法打开：`NSError(domain: "BatteryError", code: 1)`
        - 无法获取温度：`NSError(domain: "BatteryError", code: 2)`

     使用示例：

     ```swift
     getBatteryInfoPublisher()
         .sink(receiveCompletion: { ... }, receiveValue: { battery in
             print("电量：\(battery.level)%")
             print("循环次数：\(battery.cycleCount)")
         })
         .store(in: &cancellables)
     ```
     */
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

//MARK: - 内存信息接口
extension DevelopmentKit.SysInfo {
    
    /**
     获取当前 macOS 系统的内存使用信息，包括总内存、空闲内存、已使用内存与可回收内存（Inactive Memory）。
     
     - Important:
     - interval == 0 时，一次性返回当前内存信息，非持续监测。
     - interval > 0 时，定时通过 Timer.publish 推送内存状态；
     - 数据单位为 **GB（四舍五入至小数点后两位）**，方便用于 UI 显示或存储记录。
     
     - Note:
     - 本方法通过 `host_statistics64()` 获取内存页数据，并结合 `sysctl` 获取总内存大小。
     - 可回收内存（`inactive`）指的是暂时未使用但可被系统回收的内存块，属于 macOS 的内存优化策略之一。
     - 所有值已统一换算为 GB，并进行保留两位小数处理。
     
     - Returns: 一个 `AnyPublisher<MacMemoryInfo, Swift.Error>`，成功时返回封装的 `MacMemoryInfo`，失败时包含系统错误信息。
     
     - Throws: 不会直接抛出异常，但返回的 Publisher 在以下情况可能通过 `.failure` 报错：
     - `host_statistics64()` 调用失败，返回 `NSError(domain: "MemoryError", code: 1, ...)`。
     
     使用示例：
     
     ```swift
     getMemoryInfoPublisher()
     .sink(receiveCompletion: { ... }, receiveValue: { memory in
     print("总内存：\(memory.total) GB")
     print("空闲内存：\(memory.free) GB")
     })
     .store(in: &cancellables)
     ```
     */
    public static func getMemoryInfoPublisher(interval: TimeInterval = 1) -> AnyPublisher<MacMemoryInfo, Swift.Error> {
        func readMemoryInfo() -> MacMemoryInfo? {
            let HOST_VM_INFO64_COUNT = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
            var stats = vm_statistics64()
            var count = mach_msg_type_number_t(HOST_VM_INFO64_COUNT)
            let result = withUnsafeMutablePointer(to: &stats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }
            
            guard result == KERN_SUCCESS else { return nil }
            
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
            
            return MacMemoryInfo(
                total: toGB(total),
                free: toGB(free),
                used: toGB(used),
                inactive: toGB(inactive)
            )
        }
        
        if interval <= 0 {
            return Future<MacMemoryInfo, Swift.Error> { promise in
                if let info = readMemoryInfo() {
                    promise(.success(info))
                } else {
                    promise(.failure(NSError(domain: "MemoryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取内存信息"])))
                }
            }
            .eraseToAnyPublisher()
        } else {
            return Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .compactMap { _ in
                    readMemoryInfo()
                }
                .setFailureType(to: Swift.Error.self)
                .eraseToAnyPublisher()
        }
    }
}

//MARK: - CPU信息接口
extension DevelopmentKit.SysInfo {
    /**
     获取当前 macOS 系统的 CPU 信息，包括型号、核心数、总体使用率及每个核心使用率。
     
     - Important: 本方法支持一次性采样与定时采样两种模式，调用方可通过 `interval` 参数控制行为：
     - 若 `interval == 0`，将仅采样一次（结果为历史累计快照，非实时占用率）；
     - 若 `interval > 0`，则每隔指定时间推送一次“当前 CPU 活动占用率”（基于差值计算）。
     
     - Note: 使用率的计算基于 `host_processor_info()` 返回的数据，结果单位为百分比（%）。
     每个核心的使用率包含用户态、系统态及 nice 态之和，不区分线程类型。
     支持 Apple Silicon 与 Intel 架构的 macOS 设备。
     
     - Returns: 一个 `AnyPublisher<MacCPUInfo, Error>`，成功时返回 `MacCPUInfo`，失败时返回错误信息。
     
     - Throws: 不会直接抛出异常，但返回的 Publisher 可能通过 `.failure` 输出以下错误：
     - 无法获取 CPU 使用率时返回 `NSError(domain: "CPUInfo", code: 1, ...)`。
     
     使用示例：
     
     ```swift
     getCPUInfoPublisher()
     .sink(receiveCompletion: { ... }, receiveValue: { info in
     print(info.model)
     print(info.totalUsage)
     })
     .store(in: &cancellables)
     ```
     */
    public static func getCPUInfoPublisher(interval: TimeInterval = 1) -> AnyPublisher<MacCPUInfo, Error> {
        struct Snapshot {
            let coreCount: Int
            let values: [Double]
        }

        func readCPUTicks() -> Snapshot? {
            var cpuCount: natural_t = 0
            var cpuInfo: processor_info_array_t?
            var numCPUInfo: mach_msg_type_number_t = 0

            let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &numCPUInfo)
            guard result == KERN_SUCCESS, let info = cpuInfo else { return nil }

            var values: [Double] = []
            for i in 0..<Int(cpuCount) {
                let base = Int(CPU_STATE_MAX) * i
                for j in 0..<Int(CPU_STATE_MAX) {
                    values.append(Double(info[base + j]))
                }
            }

            return Snapshot(coreCount: Int(cpuCount), values: values)
        }

        func calculateUsage(prev: Snapshot, current: Snapshot) -> (total: Double, perCore: [Double]) {
            var totalUsed: Double = 0
            var totalAll: Double = 0
            var coreUsages: [Double] = []

            for i in 0..<prev.coreCount {
                let base = i * Int(CPU_STATE_MAX)
                let userDiff = current.values[base + Int(CPU_STATE_USER)] - prev.values[base + Int(CPU_STATE_USER)]
                let systemDiff = current.values[base + Int(CPU_STATE_SYSTEM)] - prev.values[base + Int(CPU_STATE_SYSTEM)]
                let idleDiff = current.values[base + Int(CPU_STATE_IDLE)] - prev.values[base + Int(CPU_STATE_IDLE)]
                let niceDiff = current.values[base + Int(CPU_STATE_NICE)] - prev.values[base + Int(CPU_STATE_NICE)]

                let used = userDiff + systemDiff + niceDiff
                let total = used + idleDiff

                coreUsages.append((used / total) * 100)
                totalUsed += used
                totalAll += total
            }

            return ((totalUsed / totalAll) * 100, coreUsages)
        }

        func readStaticInfo() -> (model: String, physical: Int, logical: Int) {
            var modelBuffer = [CChar](repeating: 0, count: 256)
            var size = modelBuffer.count
            sysctlbyname("machdep.cpu.brand_string", &modelBuffer, &size, nil, 0)
            let model = String(cString: modelBuffer)

            var physicalCores: Int32 = 0
            var logicalCores: Int32 = 0
            size = MemoryLayout.size(ofValue: physicalCores)
            sysctlbyname("hw.physicalcpu", &physicalCores, &size, nil, 0)
            sysctlbyname("hw.logicalcpu", &logicalCores, &size, nil, 0)

            return (model, Int(physicalCores), Int(logicalCores))
        }

        if interval <= 0 {
            return Future<MacCPUInfo, Error> { promise in
                let (model, physical, logical) = readStaticInfo()
                guard let snapshot = readCPUTicks() else {
                    promise(.failure(NSError(domain: "CPUInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取 CPU 状态"])))
                    return
                }

                var coreUsages: [Double] = []
                for i in 0..<snapshot.coreCount {
                    let base = i * Int(CPU_STATE_MAX)
                    let user = snapshot.values[base + Int(CPU_STATE_USER)]
                    let system = snapshot.values[base + Int(CPU_STATE_SYSTEM)]
                    let idle = snapshot.values[base + Int(CPU_STATE_IDLE)]
                    let nice = snapshot.values[base + Int(CPU_STATE_NICE)]

                    let used = user + system + nice
                    let total = used + idle
                    let percent = (used / total) * 100
                    coreUsages.append(percent)
                }

                let totalUsage = coreUsages.reduce(0, +) / Double(snapshot.coreCount)
                let totalIdle = 100.0 - totalUsage

                promise(.success(MacCPUInfo(
                    model: model,
                    physicalCores: physical,
                    logicalCores: logical,
                    totalUsage: totalUsage,
                    totalIdle: totalIdle,
                    coreUsages: coreUsages
                )))
            }
            .eraseToAnyPublisher()
        } else {
            let (model, physical, logical) = readStaticInfo()
            var previous: Snapshot? = nil

            return Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .compactMap { _ in
                    guard let current = readCPUTicks() else { return nil }
                    defer { previous = current }
                    guard let prev = previous else { return nil }
                    let (total, perCore) = calculateUsage(prev: prev, current: current)

                    return MacCPUInfo(
                        model: model,
                        physicalCores: physical,
                        logicalCores: logical,
                        totalUsage: total,
                        totalIdle: 100 - total,
                        coreUsages: perCore
                    )
                }
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }

}
