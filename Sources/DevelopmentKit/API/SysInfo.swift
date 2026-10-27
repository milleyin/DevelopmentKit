//
//  SysInfo.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import CoreWLAN
import AppKit
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
// Darwin 可选导入，通常 Foundation 已经隐式包含
#endif
//MARK: - 电池信息接口
extension DevelopmentKit.SysInfo {
#if os(iOS)
    /**
     获取当前 iOS 设备的电池电量百分比（0~100），以 Publisher 方式定时推送。
     
     - Important: 本方法使用 `UIDevice.current.batteryLevel` 获取电量值。该接口必须启用电池监控（`UIDevice.current.isBatteryMonitoringEnabled = true`）才能生效。电量值以定时器方式定期更新，适合用于 UI 显示、电量监控图表等用途。
     
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
    public static func getBatteryLevelPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<Int, SysInfoError> {
        // 启用电池监控
        UIDevice.current.isBatteryMonitoringEnabled = true

        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .tryMap { _ in
                let level = UIDevice.current.batteryLevel
                if level < 0 {
                    throw SysInfoError.batteryUnavailable
                }
                return Int(level * 100)
            }
            .mapError { error in
                (error as? SysInfoError) ?? .unknown(error)
            }
            .eraseToAnyPublisher()
    }
#elseif os(macOS)
    
    /**
     获取当前 macOS 设备的电池信息，包括电量、电池最大容量、充电状态、电池温度与循环次数。
     
     - Important: 只通过公开接口取值：IOPS（`IOPowerSources.h` / `IOPSKeys.h`），以及 `IOPMPowerSource` 注册表条目上在 `IOPM.h` 中有常量定义的属性。不读取 `BatteryData` 等没有公开常量的结构，避免 SDK 成为调用方 App 的审核风险。需要运行在具有内建电池的设备（如 MacBook）上，台式机（如 Mac mini / Mac Studio）输出 `.batteryUnavailable`。

     - Note:
        - 所有电池信息均为当前状态的一次性采样，非持续监听。
        - `temperature` 与 `cycleCount` 在系统未通过公开接口提供时为 `nil`，不视为失败（例如 macOS 27 起注册表不再发布顶层 `Temperature`）。
        - `isCharging` 表示接着外部电源，不等于电池正在充电（如优化充电停在 80% 时仍为 `true`），落差与原因见 `MacBatteryInfo.isCharging`。
        - 循环次数可用于评估电池健康状况，通常 Apple 建议 Mac 电池循环不超过 1000 次。

     - Returns: 一个 `AnyPublisher<MacBatteryInfo, SysInfoError>`，成功时输出一次 `MacBatteryInfo` 后结束。

     - Throws: 本方法不会直接抛出异常，但可能通过 Publisher 输出以下错误：
        - `SysInfoError.batteryUnavailable`：IOPS 中没有内建电池，或缺少电量字段。
        - `SysInfoError.unknown`：其他未预期错误。

     使用示例：

     ```swift
     getBatteryInfoPublisher()
         .sink(receiveCompletion: { ... }, receiveValue: { battery in
             print("电量：\(battery.level)%")
             if let cycleCount = battery.cycleCount {
                print("循环次数：\(cycleCount)")
            }
         })
         .store(in: &cancellables)
     ```
     */
    public static func getBatteryInfoPublisher() -> AnyPublisher<MacBatteryInfo, SysInfoError> {
        return Future<MacBatteryInfo, SysInfoError> { promise in
            do {
                let info = try getMacBatteryInfo()
                promise(.success(info))
            } catch let error as SysInfoError {
                promise(.failure(error))
            } catch {
                promise(.failure(.unknown(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 打开电池服务
    @available(*, deprecated, message: "残留：已由 readPowerSourceRegistryProperties() 取代，下一提交物理删除")
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
    /**
     采集并组装电池信息：读取 IOPS 描述字典与电源注册表公开属性，交给纯函数组装。

     - Returns: 组装好的 `MacBatteryInfo`。
     - Throws: `SysInfoError.batteryUnavailable`：没有内建电池，或 IOPS 缺少电量字段。
     */
    private static func getMacBatteryInfo() throws -> MacBatteryInfo {
        let iopsDescription = try readInternalBatteryDescription()
        let registryProperties = readPowerSourceRegistryProperties()
        return try makeBatteryInfo(iopsDescription: iopsDescription, registryProperties: registryProperties)
    }

    /**
     读取内建电池在 IOPS 中的描述字典。

     - Returns: 内建电池的 IOPS 描述字典。
     - Throws: `SysInfoError.batteryUnavailable`：IOPS 快照不可用，或其中没有内建电池。
     */
    private static func readInternalBatteryDescription() throws -> [String: Any] {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources: NSArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
            throw SysInfoError.batteryUnavailable
        }
        for source in sources {
            // 按类型挑内建电池而不是取第一个：接了 UPS 时第一个电源可能是 UPS
            guard let description: NSDictionary = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue(),
                  let dictionary = description as? [String: Any],
                  dictionary[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else {
                continue
            }
            return dictionary
        }
        throw SysInfoError.batteryUnavailable
    }

    /**
     读取电源注册表条目上在 `IOPM.h` 中有常量定义的属性。

     - Returns: 只含 `kIOPMPSBatteryTemperatureKey`、`kIOPMPSCycleCountKey` 中实际存在的键；找不到条目时为空字典。
     - Important: 按公开基类 `IOPMPowerSource` 匹配，不使用 `AppleSmartBattery` 类名；只读有公开常量的键，
       不读取 `BatteryData` 等未公开结构。
     - Note: 这两个属性在部分系统上不存在（macOS 27 起没有顶层 `Temperature`），缺失不视为错误。
     */
    private static func readPowerSourceRegistryProperties() -> [String: Any] {
        // IOPM.h 将 kIOPMPS* 定义为 IOPMPowerSource 的属性，按基类匹配才与这份公开契约一致
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMPowerSource"))
        guard service != 0 else {
            return [:]
        }
        defer { IOObjectRelease(service) }

        var properties: [String: Any] = [:]
        for key in [kIOPMPSBatteryTemperatureKey, kIOPMPSCycleCountKey] {
            // Create 规则返回 +1 引用，必须 takeRetainedValue，否则每次调用泄漏一个对象
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                properties[key] = value
            }
        }
        return properties
    }

    /**
     由 IOPS 描述字典与电源注册表属性组装电池信息（纯函数，不读取任何系统状态）。

     - Parameter iopsDescription: 内建电池的 IOPS 描述字典。
     - Parameter registryProperties: 电源注册表属性，键为 `kIOPMPSBatteryTemperatureKey`、`kIOPMPSCycleCountKey`。
     - Returns: 组装好的 `MacBatteryInfo`；温度与循环次数在系统未提供时为 `nil`。
     - Throws: `SysInfoError.batteryUnavailable`：缺少 `kIOPSCurrentCapacityKey` / `kIOPSMaxCapacityKey`，或最大容量不为正数。
     - Note: 温度来源按优先级：
       1. IOPS `kIOPSTemperatureKey`：IOPSKeys.h 写明单位为 °C（整数）。
       2. 注册表 `kIOPMPSBatteryTemperatureKey`：IOPM.h 未写单位，macOS 上为 Smart Battery 格式（0.1 K）。
     */
    static func makeBatteryInfo(iopsDescription: [String: Any], registryProperties: [String: Any]) throws -> MacBatteryInfo {
        guard let currentCapacity = iopsDescription[kIOPSCurrentCapacityKey] as? Int,
              let maxCapacity = iopsDescription[kIOPSMaxCapacityKey] as? Int,
              maxCapacity > 0 else {
            // 旧实现在最大容量为 0 时会在 Float 转 Int 处崩溃，这里改为明确报错
            throw SysInfoError.batteryUnavailable
        }

        let temperature: Double?
        if let celsius = iopsDescription[kIOPSTemperatureKey] as? Int {
            // 目前 powerd 并未填写此键；放在首位是因为它是唯一写明单位的公开契约，系统一旦提供即自动生效
            temperature = Double(celsius)
        } else if let deciKelvin = registryProperties[kIOPMPSBatteryTemperatureKey] as? Int {
            // macOS 上为 0.1 K：AppleSmartBattery.cpp 的平台注释、SBS 规范 Temperature()、
            // powerd 的 NCC_TEMP_THRESH（2912 即 18 °C）三方一致；旧实现的 /100 在发热时会严重偏低
            temperature = (Double(deciKelvin) / 10 - 273.15).rounded(toPlaces: 2)
        } else {
            temperature = nil
        }

        return MacBatteryInfo(
            level: currentCapacity * 100 / maxCapacity,
            maxCapacity: maxCapacity,
            // 有意按"接着外部电源"取值而不读 kIOPSIsChargingKey，两者的落差见 MacBatteryInfo.isCharging 文档
            isCharging: iopsDescription[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
            temperature: temperature,
            cycleCount: registryProperties[kIOPMPSCycleCountKey] as? Int
        )
    }
//    private static func getMacBatteryInfo() -> MacBatteryInfo {
//        var batteryInfo = MacBatteryInfo()
//        
//        _ = IOPSCopyPowerSourcesInfo()
//        
//        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
//            return batteryInfo  // 如果获取电池信息失败，返回默认值
//        }
//        
//        guard let sources: NSArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
//            return batteryInfo  // 如果获取电池源失败，返回默认值
//        }
//        
//        // 遍历每个电池源
//        for ps in sources {
//            guard let info: NSDictionary = IOPSGetPowerSourceDescription(snapshot, ps as CFTypeRef)?.takeUnretainedValue() else {
//                continue  // 如果获取电池信息失败，则跳过
//            }
//            
//            // 获取电池最大容量、电量、充电状态
//            if let capacity = info[kIOPSMaxCapacityKey] as? Int,
//               let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int {
//                batteryInfo.maxCapacity = capacity
//                batteryInfo.level = Int((Float(currentCapacity) / Float(capacity)) * 100)
//            }
//            
//            // 获取充电状态
//            if let powerState = info[kIOPSPowerSourceStateKey] as? String {
//                batteryInfo.isCharging = (powerState == kIOPSACPowerValue)
//            }
//            
//            // 获取电池温度
//            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
//            if service != 0 {
//                let temp = getBatteryTemperature(service)
//                if temp != -1 {
//                    batteryInfo.temperature = temp
//                }
//                let cycleCount = getBatteryCycleCount(service)
//                if cycleCount != -1 {
//                    batteryInfo.cycleCount = cycleCount
//                }
//                IOObjectRelease(service)  // 释放服务
//            }
//            
//            break  // 获取到电池信息后直接跳出循环
//        }
//        
//        return batteryInfo
//    }
    
    // 获取电池温度（摄氏度）
    @available(*, deprecated, message: "残留：已由 readPowerSourceRegistryProperties() + makeBatteryInfo 取代，下一提交物理删除")
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
    @available(*, deprecated, message: "残留：已由 readPowerSourceRegistryProperties() + makeBatteryInfo 取代，下一提交物理删除")
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

//MARK: - host 端口
extension DevelopmentKit.SysInfo {

    /**
     取一份 host 端口的发送权交给 `body` 使用，`body` 返回后释放。

     - Parameter body: 用 host 端口读取系统信息的闭包。
     - Returns: `body` 的返回值。
     - Important: `mach_host_self()` 每调用一次，本进程对 host 端口的发送权就多一个用户引用，必须用 `mach_port_deallocate` 成对释放，否则引用随调用次数累积。需要 host 端口时经由本方法取用，不要直接调用 `mach_host_self()`。
     */
    private static func withHostPort<Value>(_ body: (host_t) -> Value) -> Value {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        return body(host)
    }
}

//MARK: - 内存信息接口
extension DevelopmentKit.SysInfo {
    
    /**
     获取当前 macOS 系统的内存使用信息，包括总内存、空闲内存、已使用内存与可回收内存（Inactive Memory）。
     
     - Important:
     - interval <= 0 时，一次性返回当前内存信息，非持续监测。
     - interval > 0 时，定时通过 Timer.publish 推送内存状态，第一个值在一个间隔之后输出；
     - 数据单位为 **GiB（1024³ 字节，四舍五入至小数点后两位）**，方便用于 UI 显示或存储记录。
     
     - Note:
     - 本方法通过 `host_statistics64()` 获取内存页数据，并结合 `sysctl` 获取总内存大小。
     - 可回收内存（`inactive`）指的是暂时未使用但可被系统回收的内存块，属于 macOS 的内存优化策略之一。
     - `used` 按活动监视器“已使用内存”的口径近似：物理内存减去空闲页与文件缓存页。Apple 未公开算法；`vm_stat` 与活动监视器同时对照三组，相差在 0.2 GiB 以内。
     - `free` 只算空闲页，不含 speculative 页，与 `vm_stat` 的 “Pages free” 同口径。
     
     - Returns: 一个 `AnyPublisher<MacMemoryInfo, SysInfoError>`，成功时返回封装的 `MacMemoryInfo`，失败时包含系统错误信息。
     
     - Throws: 不会直接抛出异常，但返回的 Publisher 在以下情况可能通过 `.failure` 报错：
     - 读不到内存页统计（`host_statistics64` 失败）或物理内存总量（`hw.memsize`）时，输出 `SysInfoError.memoryReadFailure`。
     
     使用示例：
     
     ```swift
     getMemoryInfoPublisher()
     .sink(receiveCompletion: { ... }, receiveValue: { memory in
     print("总内存：\(memory.total) GiB")
     print("空闲内存：\(memory.free) GiB")
     })
     .store(in: &cancellables)
     ```
     */
    public static func getMemoryInfoPublisher(interval: TimeInterval = 1) -> AnyPublisher<MacMemoryInfo, SysInfoError> {
        func readMemoryInfo() throws -> MacMemoryInfo {
            let HOST_VM_INFO64_COUNT = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
            var stats = vm_statistics64()
            var count = mach_msg_type_number_t(HOST_VM_INFO64_COUNT)
            let result = withHostPort { host in
                withUnsafeMutablePointer(to: &stats) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        host_statistics64(host, HOST_VM_INFO64, $0, &count)
                    }
                }
            }
            
            guard result == KERN_SUCCESS else {
                throw SysInfoError.memoryReadFailure
            }
            
            // 获取总内存
            var totalMemory: UInt64 = 0
            var sizeOfMem = MemoryLayout<UInt64>.size
            // 读失败时总量停在 0，算出的已用和调用方的比例都没有意义，按读取失败处理
            guard sysctlbyname("hw.memsize", &totalMemory, &sizeOfMem, nil, 0) == 0 else {
                throw SysInfoError.memoryReadFailure
            }
            
            return makeMemoryInfo(statistics: stats, pageSize: UInt64(vm_kernel_page_size), totalBytes: totalMemory)
        }
        
        if interval <= 0 {
            return Future<MacMemoryInfo, SysInfoError> { promise in
                do {
                    let info = try readMemoryInfo()
                    promise(.success(info))
                } catch let error as SysInfoError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.unknown(error)))
                }
            }
            .eraseToAnyPublisher()
        } else {
            return Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .tryMap { _ in
                    try readMemoryInfo()
                }
                .mapError { error in
                    (error as? SysInfoError) ?? .unknown(error)
                }
                .eraseToAnyPublisher()
        }
    }
    
    /**
     由一次 `host_statistics64` 读数与物理内存总量组装内存信息（纯函数，不读取任何系统状态）。
     
     - Parameter statistics: `HOST_VM_INFO64` 的读数。
     - Parameter pageSize: 每页字节数。
     - Parameter totalBytes: 物理内存总量（字节）。
     - Returns: 各项换算为 GiB、保留两位小数的 `MacMemoryInfo`。
     - Note:
     - `used` = 物理内存 − 空闲页 − 文件缓存页，按活动监视器“已使用内存”的口径近似。
     - 内核的 `free_count` 含 speculative 页（`vm_stat` 打印 “Pages free” 时减去了它），speculative 页同时计入文件缓存页（`external_page_count`）。所以空闲页先减去 speculative，否则会扣两次。
     - Important: 页数是 `natural_t`（UInt32），无符号相减一旦下溢会直接崩溃，所以换成 Int64 再算；读数自相矛盾时（如 speculative 多于空闲页），结果取 0，不输出负数。
     */
    static func makeMemoryInfo(statistics: vm_statistics64, pageSize: UInt64, totalBytes: UInt64) -> MacMemoryInfo {
        let page = Int64(pageSize)
        let total = Int64(totalBytes)
        let freePages = max(Int64(statistics.free_count) - Int64(statistics.speculative_count), 0)
        let cachedPages = Int64(statistics.external_page_count)
        let used = max(total - (freePages + cachedPages) * page, 0)
        
        func toGiB(_ bytes: Int64) -> Double {
            (Double(bytes) / 1_073_741_824).rounded(toPlaces: 2)
        }
        
        return MacMemoryInfo(
            total: toGiB(total),
            free: toGiB(freePages * page),
            used: toGiB(used),
            inactive: toGiB(Int64(statistics.inactive_count) * page)
        )
    }
}

//MARK: - CPU信息接口
extension DevelopmentKit.SysInfo {
    /**
     获取当前 macOS 系统的 CPU 信息，包括型号、核心数、总体使用率及每个核心使用率。
     
     - Important: 本方法支持一次性采样与定时采样两种模式，调用方可通过 `interval` 参数控制行为：
     - 若 `interval <= 0`，将仅采样一次（结果为历史累计快照，非实时占用率）；
     - 若 `interval > 0`，则每隔指定时间推送一次“当前 CPU 活动占用率”（基于差值计算）。第一拍只记下基准读数，第一个值在第二拍输出；某一拍读不到 CPU 状态，或与上一拍之间所有核心都没有新的 tick（间隔过短）时，这一拍不输出。
     
     - Note: 使用率的计算基于 `host_processor_info()` 返回的数据，结果单位为百分比（%）。每个核心的使用率包含用户态、系统态及 nice 态之和，不区分线程类型。支持 Apple Silicon 与 Intel 架构的 macOS 设备。型号 `model` 取自没有公开文档的 sysctl 名称，系统未提供时为 `nil`，不视为失败；用法限制见 `MacCPUInfo.model`。
     
     - Returns: 一个 `AnyPublisher<MacCPUInfo, SysInfoError>`，成功时返回 `MacCPUInfo`，失败时返回错误信息。
     
     - Throws: 不会直接抛出异常。只有一次性采样可能通过 `.failure` 输出错误：
     - 读不到 CPU 状态（`host_processor_info` 失败）时输出 `SysInfoError.cpuSnapshotFailed`。
     
     使用示例：
     
     ```swift
     getCPUInfoPublisher()
     .sink(receiveCompletion: { ... }, receiveValue: { info in
     print(info.model ?? "未知型号")
     print(info.totalUsage)
     })
     .store(in: &cancellables)
     ```
     */
    public static func getCPUInfoPublisher(interval: TimeInterval = 1) -> AnyPublisher<MacCPUInfo, SysInfoError> {

        func readStaticInfo() -> (model: String?, physical: Int, logical: Int) {
            var modelBuffer = [CChar](repeating: 0, count: 256)
            var size = modelBuffer.count
            let status = sysctlbyname("machdep.cpu.brand_string", &modelBuffer, &size, nil, 0)
            let brand = String(cString: modelBuffer)
            // 这个 sysctl 名称没有公开文档，可能随系统版本消失：读取失败或为空时给 nil，不用空字符串充当"未知"
            let model: String? = (status == 0 && !brand.isEmpty) ? brand : nil

            var physicalCores: Int32 = 0
            var logicalCores: Int32 = 0
            size = MemoryLayout.size(ofValue: physicalCores)
            sysctlbyname("hw.physicalcpu", &physicalCores, &size, nil, 0)
            sysctlbyname("hw.logicalcpu", &logicalCores, &size, nil, 0)

            return (model, Int(physicalCores), Int(logicalCores))
        }

        if interval <= 0 {
            return Future<MacCPUInfo, SysInfoError> { promise in
                let (model, physical, logical) = readStaticInfo()
                guard let snapshot = readCPUTicks() else {
                    promise(.failure(.cpuSnapshotFailed))
                    return
                }
                
                var coreUsages: [Double] = []
                for core in snapshot.cores {
                    let used = core.user + core.system + core.nice
                    let total = used + core.idle
                    let percent = (used / total) * 100
                    coreUsages.append(percent)
                }

                let totalUsage = coreUsages.reduce(0, +) / Double(snapshot.cores.count)
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
            var previous: CPUTickSnapshot? = nil

            return Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .compactMap { _ in
                    guard let current = readCPUTicks() else { return nil }
                    defer { previous = current }
                    guard let prev = previous, let usage = cpuUsage(previous: prev, current: current) else { return nil }

                    return MacCPUInfo(
                        model: model,
                        physicalCores: physical,
                        logicalCores: logical,
                        totalUsage: usage.total,
                        totalIdle: 100 - usage.total,
                        coreUsages: usage.perCore
                    )
                }
                .setFailureType(to: SysInfoError.self)
                .eraseToAnyPublisher()
        }
    }
    
    /**
     一次 `host_processor_info` 读数：每个核心自开机以来在各状态下累计的 tick 数。

     - Note: 单次读数是累计值，两次读数之差才对应这段时间内的占用，见 `cpuUsage(previous:current:)`。
     */
    struct CPUTickSnapshot {
        /// 单个核心在各状态下累计的 tick 数
        struct Core {
            let user: Double
            let system: Double
            let idle: Double
            let nice: Double
        }

        /// 各核心的读数，顺序即 `host_processor_info` 返回的处理器顺序
        let cores: [Core]
    }

    /**
     读取各核心自开机以来累计的 tick。

     - Returns: 本次读数；`host_processor_info` 失败时为 nil。
     - Important: `host_processor_info` 把结果放在内核为本进程新分配的缓冲区里，复制出数值后必须用 `vm_deallocate` 归还，否则每读一次漏掉一块缓冲区（至少一页）。
     */
    private static func readCPUTicks() -> CPUTickSnapshot? {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = withHostPort { host in
            host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &cpuInfoCount)
        }
        guard result == KERN_SUCCESS, let info = cpuInfo else { return nil }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let stateCount = Int(CPU_STATE_MAX)
        let cores = (0..<Int(cpuCount)).map { index -> CPUTickSnapshot.Core in
            let base = index * stateCount
            return CPUTickSnapshot.Core(
                user: Double(info[base + Int(CPU_STATE_USER)]),
                system: Double(info[base + Int(CPU_STATE_SYSTEM)]),
                idle: Double(info[base + Int(CPU_STATE_IDLE)]),
                nice: Double(info[base + Int(CPU_STATE_NICE)])
            )
        }
        return CPUTickSnapshot(cores: cores)
    }

    /**
     由两次读数算出这段时间内的 CPU 占用率。

     - Parameters:
       - previous: 较早的读数。
       - current: 较晚的读数，与 `previous` 来自同一台机器；核心数不同时，只按两者共有的前几个核心逐一配对。
     - Returns: 总体占用率与每核占用率（%）；两次读数之间所有核心都没有新的 tick 时为 nil，表示这段间隔测不出占用。
     - Note:
       - 已用 = 用户态 + 系统态 + nice 态。总体占用按 tick 加权：各核已用之和除以各核全部 tick 之和，不是各核百分比的平均。
       - 单个核心两次读数之间没有新的 tick 时，该核记 0，不除出 NaN。
     */
    static func cpuUsage(previous: CPUTickSnapshot, current: CPUTickSnapshot) -> (total: Double, perCore: [Double])? {
        var usedTicks: Double = 0
        var allTicks: Double = 0
        var perCore: [Double] = []

        for (before, after) in zip(previous.cores, current.cores) {
            let used = (after.user - before.user) + (after.system - before.system) + (after.nice - before.nice)
            let all = used + (after.idle - before.idle)
            perCore.append(all > 0 ? used / all * 100 : 0)
            usedTicks += used
            allTicks += all
        }

        guard allTicks > 0 else { return nil }
        return (usedTicks / allTicks * 100, perCore)
    }


}

//MARK: - 磁盘容量信息接口
extension DevelopmentKit.SysInfo {

    /**
     获取根卷（`/`）的可用空间（GiB），并按 `interval` 定时推送。
     
     - Important: 读取所用的 `volumeAvailableCapacityKey` 属于 Apple"需声明理由的 API"（磁盘空间类）。DevelopmentKit 已在自身的 `PrivacyInfo.xcprivacy` 中申报 `NSPrivacyAccessedAPICategoryDiskSpace` / `85F4.1` （向设备使用者显示磁盘空间），调用方无需为本方法重复申报，但必须遵守该理由的约束：
        - 只在本机向用户显示；数值及其衍生信息不得离开设备（含统计上报、日志上传），也不得用于识别设备。
        - 若用它判断"空间是否足够写入或下载"，属于 `E174.1`，须在 App 自己的隐私清单中申报。
        - 若要放进用户主动提交的问题报告，属于 `7D9E.1`，同样须由 App 自己申报。
        - 按 Apple 现行文档，iOS / iPadOS / tvOS / visionOS / watchOS 强制申报（2024-05-01 起未申报的提交不被 App Store Connect 接受），macOS 未列入；本 SDK 的申报在 macOS 上没有副作用。
     
     - Note:
        - 单位是 GiB（按 1024³ 换算后向下取整），不是系统设置、访达使用的十进制 GB，同一容量的数值约小 7%。
        - 通常小于访达显示的"可用"：访达的口径一般还包含系统可清除（purgeable）的空间。要与访达接近，可改用 `volumeAvailableCapacityForImportantUsageKey`（同属磁盘空间类，申报不变）。
        - 默认 `interval` 为 1 秒，但磁盘空间变化缓慢，建议调用方显式传入 60 秒以上，避免无谓耗电。
        - 读取失败会以 `.diskSpaceUnavailable` 结束整条定时流；需要持续监听时由调用方 `.retry` 或重新订阅。
     
     - Parameter interval: 推送间隔（秒），默认为 `1.0`。
     - Returns: `AnyPublisher<Int, SysInfoError>`，每隔 `interval` 秒输出一次根卷可用空间（GiB）。
     - Throws: 不直接抛出；读取失败时 Publisher 输出 `SysInfoError.diskSpaceUnavailable` 并结束。
     
     示例：
    ```swift
         DevelopmentKit.SysInfo.getAvailableDiskSpacePublisher(interval: 60)
             .sink(receiveCompletion: { _ in }, receiveValue: { availableGiB in
                 print("当前磁盘可用空间：\(availableGiB) GiB")
             })
    ```
         */
    public static func getAvailableDiskSpacePublisher(interval: TimeInterval = 1.0) -> AnyPublisher<Int, SysInfoError> {
        return Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .tryMap { _ in
                    guard let gib = getAvailableDiskSpaceInGiB() else {
                        throw SysInfoError.diskSpaceUnavailable
                    }
                    return gib
                }
            .mapError { error in
                (error as? SysInfoError) ?? .unknown(error)
            }
            .eraseToAnyPublisher()
    }

    /// 获取根卷可用空间（单位：GiB，按 1024³ 换算后向下取整）；读取失败时为 nil
    private static func getAvailableDiskSpaceInGiB() -> Int? {
        // 获取根目录路径（也可以替换为其他目录）
        let path = URL(fileURLWithPath: "/")
        
        do {
            // 只请求真正用到的键：volumeTotalCapacityKey 同属"需声明理由的 API"，读了不用也算使用
            let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            
            // 将字节转换为 GiB（1 GiB = 1024 * 1024 * 1024 bytes）
            if let availableCapacity = values.volumeAvailableCapacity {
                return Int(availableCapacity / (1024 * 1024 * 1024))  // 转换为 GiB
            } else {
                return nil  // 如果获取不到可用容量，返回 nil
            }
        } catch {
            print("无法获取磁盘信息: \(error.localizedDescription)")
            return nil
        }
    }
}
