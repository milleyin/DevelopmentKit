# DevelopmentKit 优化待办事项

> 日期：2026-01-17  
> 当前版本：0.0.10(2025062)

---

## 🔴 高优先级（影响稳定性和正确性）

### 1. 修复 LogLocalManager 并发安全问题
**文件**: `LogLocalManager.swift`  
**问题**: `lastFlushTime` 在 actor 中可能存在竞争条件
```swift
// 当前代码
private var lastFlushTime = Date()  // ⚠️ 在定时器和 saveLog 中都访问

// 建议方案
// 1. 使用 AsyncStream 代替 Timer 实现定时刷新
// 2. 确保所有状态访问都在 actor 内部同步
```
**影响**: 高并发场景下可能导致日志丢失或重复写入

---

### 2. 统一错误处理机制
**文件**: 全局  
**问题**: 错误类型分散，部分使用 NSError，部分使用自定义错误
```swift
// 建议创建统一的错误类型
public enum DevelopmentKitError: Error {
    case network(NetworkError)
    case sysInfo(SysInfoError)
    case log(LogError)
    case utilities(UtilitiesError)
}

// 或者至少确保每个模块的错误类型都定义完整
```
**任务清单**:
- [ ] 检查所有错误类型定义是否完整
- [ ] 统一错误处理方式
- [ ] 在测试中验证所有错误场景

---

### 3. 清理 LogLocalManager 中的重复代码
**文件**: `LogLocalManager.swift`  
**问题**: `getLogFileURL()` (115行) 和 `getLogFilePath()` (131行) 功能重复
```swift
// 第 115 行
private func getLogFileURL() -> URL { ... }

// 第 131 行
func getLogFilePath(for date: Date = Date()) -> URL { ... }
```
**任务**:
- [ ] 合并为一个方法
- [ ] 统一方法命名（建议使用 `getLogFilePath`）
- [ ] 移除 `logsDirectory` 的重复计算
- [ ] 更新所有调用处

---

### 4. 添加平台版本兼容性标注
**文件**: `Network.swift`, `SysInfo.swift`, `Utilities.swift`  
**问题**: 缺少 `@available` 标记，不清楚最低支持版本
```swift
// 建议为所有公开 API 添加
@available(iOS 14.0, macOS 11.0, *)
public static func getNetworkTypePublisher(...) -> ... { }
```
**任务**:
- [ ] 确定项目支持的最低系统版本
- [ ] 为所有公开 API 添加 `@available` 标记
- [ ] 在 Package.swift 中声明平台要求
- [ ] 更新文档说明系统要求

---

## 🟡 中优先级（影响代码质量和可维护性）

### 5. 优化版本号管理
**文件**: `DevelopmentKit.swift`  
**当前代码**:
```swift
public static let version: String = "0.0.10(2025062)"
```
**问题**:
- 版本号硬编码，容易忘记更新
- 格式不标准（`2025062` 含义不明）
- 没有分离版本号和构建号

**建议方案**:
```swift
// 方案 1: 从 Bundle 读取
public static var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
}

public static var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
}

// 方案 2: 使用语义化版本
public struct Version {
    static let major = 0
    static let minor = 0
    static let patch = 10
    static let build = "2025062"
    
    static var fullVersion: String {
        "\(major).\(minor).\(patch)+\(build)"
    }
}
```
**任务**:
- [ ] 选择版本管理方案
- [ ] 实现版本号读取逻辑
- [ ] 更新文档说明版本号含义
- [ ] 在 CI/CD 中自动更新版本

---

### 6. 优化网络监控的资源管理
**文件**: `Network.swift`  
**问题**: 每次订阅都创建新的 `NWPathMonitor` 或 `Timer`
```swift
// 当前问题
// 1. getNetworkTypePublisher - 每次订阅创建新 monitor
// 2. getWiFiSignalLevelPublisher - 每次订阅创建新 timer
// 3. getSystemNetworkThroughputPublisher - 每次订阅创建新 timer
```
**建议**:
```swift
// 方案 1: 在文档中明确说明需要使用 .share()
/// - Important: 多个订阅者应使用 `.share()` 避免重复监听
/// ```
/// let shared = getNetworkTypePublisher().share()
/// ```

// 方案 2: 提供单例式的监听器
public class NetworkMonitor {
    public static let shared = NetworkMonitor()
    public let networkTypePublisher: AnyPublisher<NetworkType, Never>
    // ...
}
```
**任务**:
- [ ] 评估两种方案的优劣
- [ ] 实现选定方案
- [ ] 更新文档和示例代码
- [ ] 添加相关测试

---

### 7. 改进全局函数命名
**文件**: `DevelopmentKit.swift`  
**问题**:
```swift
public func Log<T>(_ message: T, ...)  // 可能与其他库冲突
public func isPreview() -> Bool  // 应该是属性而非函数
```
**建议**:
```swift
// 方案 1: 添加前缀避免冲突
public func DKLog<T>(_ message: T, ...)

// 方案 2: 使用属性
public var isPreview: Bool {
    DevelopmentKit.Utilities.isPreview
}

// 方案 3: 完全移除全局函数，统一使用命名空间
DevelopmentKit.log("message")
DevelopmentKit.Utilities.isPreview
```
**任务**:
- [ ] 确定命名策略
- [ ] 重命名全局函数
- [ ] 提供弃用警告（如果需要向后兼容）
- [ ] 更新所有示例代码

---

### 8. 清理无用代码
**问题**: 多处存在无用或重复的代码
```swift
// LogLocalManager.swift
_ = try? fileHandle.seekToEnd()  // ✅ 忽略返回值，防止警告
// 注释说明即可，不需要 _ =

// SysInfo.swift (第 79 行)
_ = IOPSCopyPowerSourcesInfo()  // 重复调用，第 81 行又调用了一次

// Utilities.swift
_ = FileManager.default  // 完全无用的一行
```
**任务**:
- [ ] 移除 `_ = FileManager.default`
- [ ] 修复 `IOPSCopyPowerSourcesInfo()` 重复调用
- [ ] 清理不必要的 `_ =` 赋值
- [ ] 移除注释掉的测试代码（如 `testWriteFailure`）

---

### 9. 优化测试代码
**文件**: `DevelopmentKitTests.swift`  
**问题**: 测试使用硬编码延迟，执行时间过长
```swift
try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 秒
try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 秒
```
**建议**:
```swift
// 方案 1: 使用依赖注入
actor LogLocalManager {
    let config: Configuration
    
    struct Configuration {
        var flushInterval: TimeInterval = 2.0
        var maxBufferedLogs: Int = 100
    }
}

// 方案 2: 使用环境变量检测测试环境
private var flushInterval: TimeInterval {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_TESTS"] == "1" ? 0.1 : 2.0
}
```
**任务**:
- [ ] 实现配置化的时间间隔
- [ ] 减少测试等待时间
- [ ] 添加更多边界条件测试
- [ ] 提高测试覆盖率

---

## 🟢 低优先级（改进和增强）

### 10. 补充缺失的数据结构定义
**问题**: 代码中使用但未找到定义的类型
- `NetworkType`
- `NetworkError`
- `WiFiSignalLevel`
- `SystemNetworkThroughput`
- `MacBatteryInfo`
- `MacMemoryInfo`
- `MacCPUInfo`
- `SysInfoError`

**任务**:
- [ ] 确认这些类型的定义位置
- [ ] 如果缺失，补充定义
- [ ] 确保所有类型都是 `public`
- [ ] 添加 `Codable`、`Equatable` 等协议（如果需要）

---

### 11. 添加日志查询功能
**文件**: `LogLocalManager.swift`  
**当前情况**: 只能写入日志，没有便捷的读取方法
```swift
// 建议添加
public struct LogEntry: Codable {
    let timestamp: Date
    let file: String
    let line: Int
    let message: String
}

extension LogLocalManager {
    /// 查询指定日期范围的日志
    func queryLogs(
        from: Date,
        to: Date,
        filter: ((LogEntry) -> Bool)? = nil
    ) async throws -> [LogEntry]
    
    /// 获取最近 N 条日志
    func getRecentLogs(count: Int) async throws -> [LogEntry]
    
    /// 清理过期日志
    func cleanOldLogs(olderThan days: Int) async throws
}
```
**任务**:
- [ ] 定义 `LogEntry` 结构
- [ ] 实现日志查询方法
- [ ] 实现日志清理方法
- [ ] 添加相关测试

---

### 12. 性能优化
**优化点**:

#### 12.1 缓存不变的系统信息
**文件**: `SysInfo.swift`
```swift
// 问题：每次调用都重新获取总内存（实际不会变）
func readMemoryInfo() throws -> MacMemoryInfo {
    var totalMemory: UInt64 = 0
    var sizeOfMem = MemoryLayout<UInt64>.size
    sysctlbyname("hw.memsize", &totalMemory, &sizeOfMem, nil, 0)  // ⚠️ 可以缓存
}

// 建议
private static let totalMemory: UInt64 = {
    var total: UInt64 = 0
    var size = MemoryLayout<UInt64>.size
    sysctlbyname("hw.memsize", &total, &size, nil, 0)
    return total
}()
```

#### 12.2 优化文件 I/O
**文件**: `LogLocalManager.swift`
```swift
// 当前：每次都创建 FileHandle
if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
    // ...
}

// 建议：复用 FileHandle（但要注意线程安全）
```

**任务**:
- [ ] 缓存不变的系统信息（总内存、CPU 型号等）
- [ ] 优化 LogLocalManager 的文件 I/O
- [ ] 使用 Instruments 进行性能分析
- [ ] 添加性能基准测试

---

### 13. 扩展方法整理
**问题**: 测试中使用了扩展方法，但未找到定义
```swift
date.toYMDFormat()
"test@example.com".regexValidation(pattern: ...)
"2024-02-25".toDate()
input.sha256
```
**任务**:
- [ ] 找到或创建 `Date+Extensions.swift`
- [ ] 找到或创建 `String+Extensions.swift`
- [ ] 确保扩展方法有文档注释
- [ ] 评估是否需要公开这些扩展

---

### 14. 添加配置系统
**建议**:
```swift
public struct DevelopmentKitConfiguration {
    // 日志配置
    public var logFlushInterval: TimeInterval = 2.0
    public var maxLogBufferSize: Int = 100
    public var minBufferedLogs: Int = 10
    public var logRetentionDays: Int = 7
    
    // 网络监控配置
    public var networkMonitorTimeout: TimeInterval = 0.5
    
    // 性能配置
    public var enablePerformanceMonitoring: Bool = false
    
    public static var shared = DevelopmentKitConfiguration()
}

// 使用
DevelopmentKitConfiguration.shared.logFlushInterval = 5.0
```
**任务**:
- [ ] 设计配置结构
- [ ] 实现配置系统
- [ ] 支持从 plist 或 JSON 加载配置
- [ ] 添加配置验证

---

### 15. 提供 async/await 版本的 API
**当前**: 大部分 API 只有 Combine 版本
```swift
// 当前
func getNetworkTypePublisher() -> AnyPublisher<NetworkType, NetworkError>

// 建议同时提供
func getNetworkType() async throws -> NetworkType
```
**任务**:
- [ ] 为主要 API 添加 async/await 版本
- [ ] 保持两种 API 的一致性
- [ ] 更新文档说明两种方式的使用场景
- [ ] 添加迁移指南

---

### 16. 增强文档和示例
**任务**:
- [ ] 创建详细的 README.md
  - [ ] 安装说明
  - [ ] 快速开始
  - [ ] 完整示例
  - [ ] API 文档链接
- [ ] 创建 CHANGELOG.md
- [ ] 添加示例项目（iOS 和 macOS）
- [ ] 创建迁移指南（Breaking Changes）
- [ ] 添加性能最佳实践文档
- [ ] 录制使用视频或 GIF 演示

---

### 17. 平台扩展
**考虑支持更多平台**:
- [ ] watchOS 支持评估
- [ ] tvOS 支持评估
- [ ] visionOS 支持评估
- [ ] Mac Catalyst 完整测试

---

## 📋 代码审查清单

### 代码规范
- [ ] 统一命名规范（函数、变量、类型）
- [ ] 统一访问控制（`public`、`internal`、`private`）
- [ ] 统一错误处理方式
- [ ] 移除所有 TODO 和 FIXME 注释（转移到此文件）

### 安全性
- [ ] 检查所有强制解包（`!`）
- [ ] 检查所有 `try?` 和 `try!`
- [ ] 验证文件权限处理
- [ ] 审查内存管理（循环引用）

### 性能
- [ ] 检查主线程阻塞
- [ ] 优化重复计算
- [ ] 检查内存泄漏
- [ ] 添加性能测试

### 测试
- [ ] 提高代码覆盖率（目标 >80%）
- [ ] 添加集成测试
- [ ] 添加压力测试
- [ ] 测试所有错误场景

---

## 🎯 里程碑规划

### v0.1.0（短期 - 1-2 周）
- [x] 项目代码审查完成
- [ ] 修复高优先级问题（1-4）
- [ ] 清理无用代码
- [ ] 添加基本文档

### v0.5.0（中期 - 1 个月）
- [ ] 完成中优先级优化（5-9）
- [ ] 添加配置系统
- [ ] 提高测试覆盖率
- [ ] 完善文档和示例

### v1.0.0（长期 - 3 个月）
- [ ] 完成所有低优先级改进
- [ ] API 稳定，确定公开接口
- [ ] 完整的文档和示例项目
- [ ] 性能优化完成
- [ ] 准备发布（CocoaPods/SPM）

---

## 💡 讨论待定的问题

1. **项目定位**
   - [ ] 确定主要使用场景（调试工具 vs 生产监控）
   - [ ] 确定目标用户群体

2. **技术选型**
   - [ ] Combine vs async/await 的优先级
   - [ ] 是否需要兼容旧系统版本

3. **功能范围**
   - [ ] 是否添加崩溃日志收集
   - [ ] 是否添加性能分析工具
   - [ ] 是否添加网络请求拦截

4. **发布策略**
   - [ ] 版本号规则
   - [ ] 发布渠道（SPM、CocoaPods、Carthage）
   - [ ] Breaking Changes 策略

---

## 📝 备注

- 优先级可根据实际需求调整
- 每完成一项请打勾 ✅
- 遇到问题记录在对应条目下
- 定期更新此文档

**最后更新**: 2026-01-17
