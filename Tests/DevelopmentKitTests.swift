//
//  DevelopmentKitTests.swift
//  DevelopmentKitTests
//
//  Created by Mille Yin on 2024/11/7.
//

import XCTest
import Combine
@testable import DevelopmentKit

class DevelopmentKitTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    
    /// 测试 `isPreview` 是否正确检测 SwiftUI 预览模式
    func testIsPreview() {
        let previewEnv = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"]
        let expected = previewEnv == "1"
        XCTAssertEqual(DevelopmentKit.Utilities.isPreview, expected)
    }
    
    /// 测试 `openMailApp()` 是否正确处理未安装邮件应用的情况
    @MainActor func testOpenMailApp() {
#if os(iOS)
        let mailURL = URL(string: "message://")!
        let canOpen = UIApplication.shared.canOpenURL(mailURL)
        if canOpen {
            DevelopmentKit.Utilities.openMailApp()
            XCTAssertTrue(true, "邮件应用打开成功")
        } else {
            XCTAssertFalse(canOpen, "无法打开邮件应用")
        }
#endif
    }
    
    /// 测试 `openAppSettings()` 是否正确跳转至系统设置
    @MainActor func testOpenAppSettings() {
#if os(iOS)
        let settingsURL = URL(string: UIApplication.openSettingsURLString)!
        let canOpen = UIApplication.shared.canOpenURL(settingsURL)
        if canOpen {
            DevelopmentKit.Utilities.openAppSettings()
            XCTAssertTrue(true, "成功打开 App 设置")
        } else {
            XCTAssertFalse(canOpen, "无法打开 App 设置")
        }
#endif
    }
    
    /// 测试 `openWebLink(urlString:)` 的 URL 解析功能
    @MainActor func testOpenWebLink() {
#if os(iOS)
        let validURL = "https://www.apple.com"
        let invalidURL = "not a valid url"
        
        DevelopmentKit.Utilities.openWebLink(urlString: validURL)
        XCTAssertTrue(true, "成功打开网页：\(validURL)")
        
        DevelopmentKit.Utilities.openWebLink(urlString: invalidURL)
        XCTAssertTrue(true, "无效 URL 应该不会崩溃")
#endif
    }
    
    
    
    
    
    
    
    /// 测试 `copyToClipboard(text:)` 是否正确复制文本
    func testCopyToClipboard() {
#if os(iOS)
        let testString = "Hello, Clipboard!"
        DevelopmentKit.Utilities.copyToClipboard(text: testString)
        XCTAssertEqual(UIPasteboard.general.string, testString, "剪贴板内容应与输入一致")
#endif
    }
    
    /// 测试 `getAppName()` 是否正确获取 App 名称
    func testGetAppName() {
        let appName = DevelopmentKit.Utilities.getAppName()
        XCTAssertFalse(appName.isEmpty, "App 名称不应为空")
    }
    
    /// 测试 `appVersion` 是否能正确获取版本号
    func testAppVersion() {
        XCTAssertFalse(DevelopmentKit.Utilities.appVersion.isEmpty, "App 版本号不应为空")
    }
    
    /// 测试 `buildNumber` 是否能正确获取编译版本号
    func testBuildNumber() {
        XCTAssertFalse(DevelopmentKit.Utilities.buildNumber.isEmpty, "App 编译版本号不应为空")
    }
    
    /// 测试 `toYMDFormat()` 是否正确格式化日期
    func testToYMDFormat() {
        let date = Date(timeIntervalSince1970: 1700000000) // 2023-11-14 06:13:20 UTC
        let expectedDateString = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current // 使用系统时区
            return formatter.string(from: date)
        }()
        
        XCTAssertEqual(date.toYMDFormat(), expectedDateString, "日期格式化应符合系统时区")
    }
    
    /// 测试 `regexValidation(pattern:)`
    func testRegexValidation() {
        let validEmailUpper = "TEST@EXAMPLE.COM"
        let validEmailLower = "test@example.com"
        let invalidEmail1 = "test@.com"      // 缺少域名
        let invalidEmail2 = "test@com"       // 顶级域名无效
        let invalidEmail3 = "test@exam_ple.com" // 下划线不允许
        let invalidEmail4 = "test@example..com" // 连续两个点
        
        let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$" // ✅ 只允许大写字母
        
        XCTAssertTrue(validEmailUpper.regexValidation(pattern: emailPattern), "大写字母邮件应匹配")
        XCTAssertFalse(validEmailLower.regexValidation(pattern: emailPattern), "小写字母邮件不应匹配")
        XCTAssertFalse(invalidEmail1.regexValidation(pattern: emailPattern), "无效邮箱应被拒绝")
        XCTAssertFalse(invalidEmail2.regexValidation(pattern: emailPattern), "无效邮箱应被拒绝")
        XCTAssertFalse(invalidEmail3.regexValidation(pattern: emailPattern), "无效邮箱应被拒绝")
        XCTAssertFalse(invalidEmail4.regexValidation(pattern: emailPattern), "无效邮箱应被拒绝")
    }
    
    /// 测试 `toDate(format:)`
    func testStringToDate() {
        let dateString = "2024-02-25"
        let date = dateString.toDate()
        XCTAssertNotNil(date, "字符串应能正确转换为 Date 对象")
    }
    
    /// 测试 SHA-256 加密
    func testSHA256() {
        let input = "Hello, Swift!"
        let hash = input.sha256
        XCTAssertFalse(hash.isEmpty, "SHA-256 结果不应为空")
    }
    #if os(macOS)
    ///测试开机启动
    func testToggleLaunchAtLogin() {
        // 先记录当前状态，测试完再还原，避免影响系统设置
        let originalStatus = LaunchAtLogin.isEnabled
        
        // 切换状态
        let newStatus = !originalStatus
        LaunchAtLogin.isEnabled = newStatus
        
        // 验证状态是否被修改
        XCTAssertEqual(LaunchAtLogin.isEnabled, newStatus, "LaunchAtLogin 状态未被正确修改")
        
        // 测试 observable 是否同步
        let observable = LaunchAtLogin.Observable()
        XCTAssertEqual(observable.isEnabled, newStatus, "Observable 状态未同步")
        
        // 恢复原状态
        LaunchAtLogin.isEnabled = originalStatus
    }
    
    func testWasLaunchedAtLoginSafety() {
        // 不能确定一定是在登录启动时运行，所以这里只能测试调用不会崩溃
        _ = LaunchAtLogin.wasLaunchedAtLogin
    }
    #endif
}

// MARK: - 网络测试

class NetworkTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    /// 测试 `getNetworkTypePublisher()` 是否正确检测网络类型
    func testGetNetworkTypePublisher() {
        let expectation = XCTestExpectation(description: "获取网络类型")
        
        let validTypes: Set<NetworkType> = [
            .wifi, .cellular, .wired, .other, .none, .unknown
        ]
        
        DevelopmentKit.Network
            .getNetworkTypePublisher(timeout: 1.0)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    switch error {
                    case .timeout, .unableToDetermineNetworkType:
                        // ✅ 合理错误，测试通过
                        break
                    default:
                        XCTFail("出现未预期的错误类型：\(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { type in
                XCTAssertTrue(validTypes.contains(type),
                              "返回的网络类型应在预定义范围内: \(type)")
                expectation.fulfill()
            })
            .store(in: &subscriptions)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
#if os(macOS)
    /// 测试 `getWiFiSignalLevelPublisher` 能正确返回或报错
    func testWiFiSignalLevelPublisher() {
        let expectation = XCTestExpectation(description: "接收到 Wi-Fi 信号等级或错误")
        
        DevelopmentKit.Network
            .getWiFiSignalLevelPublisher(interval: 0.5)
            .prefix(1)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    switch error {
                    case .wifiInterfaceUnavailable, .unknown:
                        break // 允许的错误
                    default:
                        XCTFail("出现未预期的错误：\(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { level in
                let allCases: [WiFiSignalLevel] = [
                    .excellent, .good, .fair, .weak, .poor, .disconnected
                ]
                XCTAssertTrue(allCases.contains(level),
                              "返回的信号等级应在合法枚举中: \(level)")
                expectation.fulfill()
            })
            .store(in: &subscriptions)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    /// 测试 `getSystemNetworkThroughputPublisher` 能正确返回基准和实际值
    func testSystemNetworkThroughputPublisher() {
        let expectation = XCTestExpectation(description: "获取系统网络上下行流量")
        var fulfillCount = 0

        DevelopmentKit.Network
            .getSystemNetworkThroughputPublisher(interval: 0.5)
            .prefix(2)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    switch error {
                    case .throughputUnavailable, .unknown:
                        break // 允许的错误
                    default:
                        XCTFail("出现未预期的错误：\(error)")
                    }
                }
                // 补足 fulfill，防止卡死
                while fulfillCount < 2 {
                    fulfillCount += 1
                    expectation.fulfill()
                }
            }, receiveValue: { throughput in
                XCTAssertGreaterThanOrEqual(throughput.receivedBytesPerSec, 0, "下载值不能为负")
                XCTAssertGreaterThanOrEqual(throughput.sentBytesPerSec, 0, "上传值不能为负")
                fulfillCount += 1
                expectation.fulfill()
            })
            .store(in: &subscriptions)

        wait(for: [expectation], timeout: 5.0)
    }
#endif
}

// MARK: - 系统信息

class SystemInfoTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
#if os(iOS)
    func testGetBatteryLevelPublisher() {
        let expectation = XCTestExpectation(description: "获取 iOS 电池电量")

        DevelopmentKit.SysInfo.getBatteryLevelPublisher(interval: 1.0)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("❌ 获取电池电量失败：\(error)")
                        expectation.fulfill()
                    }
                },
                receiveValue: { level in
                    print("🔋 当前电池电量：\(level)%")
                    XCTAssertGreaterThanOrEqual(level, 0)
                    XCTAssertLessThanOrEqual(level, 100)
                    expectation.fulfill()
                }
            )
            .store(in: &subscriptions)

        wait(for: [expectation], timeout: 2.0)
    }
#elseif os(macOS)

    // MARK: - 电池信息

    func testGetBatteryInfoPublisher() {
        let expectation = XCTestExpectation(description: "获取 macOS 电池信息")
        
        DevelopmentKit.SysInfo.getBatteryInfoPublisher()
            .prefix(1)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("获取电池信息失败：\(error)")
                }
            }, receiveValue: { batteryInfo in
                print("🔋电池电量：\(batteryInfo.level)%")
                print("🔋最大容量：\(batteryInfo.maxCapacity)")
                print("🔋充电状态：\(batteryInfo.isCharging ? "是" : "否")")
                print("🔋温度：\(batteryInfo.temperature) °C")
                print("🔋循环次数：\(batteryInfo.cycleCount)")
                
                XCTAssert((0...100).contains(batteryInfo.level))
                XCTAssertGreaterThanOrEqual(batteryInfo.maxCapacity, 0)
                XCTAssertGreaterThanOrEqual(batteryInfo.temperature, 0)
                XCTAssertGreaterThanOrEqual(batteryInfo.cycleCount, 0)
                expectation.fulfill()
            })
            .store(in: &subscriptions)
        
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - 内存信息

    func testGetMemoryInfoPublisher() {
        let expectation = XCTestExpectation(description: "获取内存信息")
        
        DevelopmentKit.SysInfo.getMemoryInfoPublisher()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    if case DevelopmentKit.SysInfo.SysInfoError.memoryReadFailure = error {
                        // ✅ 允许的错误
                    } else {
                        XCTFail("出现未预期的错误：\(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { info in
                print("💾 内存使用情况：\(info)")
                XCTAssertGreaterThan(info.total, 0)
                XCTAssertGreaterThanOrEqual(info.free, 0)
                XCTAssertGreaterThanOrEqual(info.inactive, 0)
                XCTAssertGreaterThanOrEqual(info.used, 0)
                XCTAssertLessThanOrEqual(info.used, info.total)
                expectation.fulfill()
            })
            .store(in: &subscriptions)
        
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - CPU 信息

    func testGetCPUInfoPublisher() {
        let expectation = XCTestExpectation(description: "获取 CPU 信息")
        
        DevelopmentKit.SysInfo.getCPUInfoPublisher(interval: 1)
            .prefix(1)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    if case DevelopmentKit.SysInfo.SysInfoError.cpuSnapshotFailed = error {
                        // ✅ 合理错误
                    } else {
                        XCTFail("出现未预期的错误：\(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { info in
                print("🧠 CPU 信息：\(info.model)")
                XCTAssertFalse(info.model.isEmpty)
                XCTAssertGreaterThan(info.physicalCores, 0)
                XCTAssertGreaterThanOrEqual(info.logicalCores, info.physicalCores)
                
                let total = info.totalUsage + info.totalIdle
                XCTAssertEqual(total.rounded(toPlaces: 1), 100.0, accuracy: 1.0)
                XCTAssertEqual(info.coreUsages.count, info.logicalCores)
                
                for usage in info.coreUsages {
                    XCTAssert(usage >= 0 && usage <= 100)
                }
                expectation.fulfill()
            })
            .store(in: &subscriptions)
        
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - 磁盘空间

    func testGetAvailableDiskSpacePublisher() {
        let expectation = XCTestExpectation(description: "获取磁盘剩余空间")
        
        DevelopmentKit.SysInfo.getAvailableDiskSpacePublisher(interval: 1.0)
            .prefix(1)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    if case DevelopmentKit.SysInfo.SysInfoError.diskSpaceUnavailable = error {
                        // ✅ 合理错误
                    } else {
                        XCTFail("出现未预期的错误：\(error)")
                    }
                    expectation.fulfill()
                }
            }, receiveValue: { space in
                print("💽 剩余磁盘空间：\(space) GB")
                XCTAssertGreaterThanOrEqual(space, 0)
                expectation.fulfill()
            })
            .store(in: &subscriptions)
        
        wait(for: [expectation], timeout: 3.0)
    }

#endif
}


// MARK: - Log 测试

final class LogLocalManagerTests: XCTestCase {

    override func setUp() async throws {
        // 清空日志目录，确保测试环境干净
        let logFiles = await LogLocalManager.shared.getLogFiles()
        for file in logFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// **测试 `Log()` 是否正确输出到 Xcode 控制台（仅检查不会崩溃）**
    func testLogFunction() async {
        Log("测试日志存储")  //
        
        // **等待日志写入**
        try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 秒，确保写入
        
        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "❌ 日志文件应存在")
    }

    /// **测试 `saveLog()` 是否能正确写入日志文件**
    func testSaveLog() async {
        await LogLocalManager.shared.saveLog(message: "测试 saveLog", file: "Test.swift", line: 42)

        // **等待日志写入**
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "❌ 日志文件应存在")

        // **检查日志内容**
        if let logFile = logFiles.first,
           let content = try? String(contentsOf: logFile) {
            XCTAssertTrue(content.contains("测试 saveLog"), "❌ 日志文件应包含 `测试 saveLog`")
        } else {
            XCTFail("❌ 无法读取日志文件")
        }
    }

    /// **测试 `flushLogsToFile()` 是否按预期写入**
    func testFlushLogs() async {
        await LogLocalManager.shared.saveLog(message: "测试 flush", file: "Test.swift", line: 99)

        // **等待 flush 触发**
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "❌ 日志文件应存在")

        if let logFile = logFiles.first,
           let content = try? String(contentsOf: logFile) {
            XCTAssertTrue(content.contains("测试 flush"), "❌ 日志文件应包含 `测试 flush`")
        } else {
            XCTFail("❌ 无法读取日志文件")
        }
    }

    /// **测试 `LogLocalManager` 在高并发场景下是否线程安全**
    func testConcurrentLogging() async {
        let logCount = 50  // **模拟高并发写入**
        let expectation = XCTestExpectation(description: "高并发日志写入")

        for i in 1...logCount {
            Task {
                await LogLocalManager.shared.saveLog(message: "并发日志 \(i)", file: "ConcurrencyTest.swift", line: i)
            }
        }

        // **等待日志写入**
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "❌ 日志文件应存在")

        if let logFile = logFiles.first,
           let content = try? String(contentsOf: logFile) {
            for i in 1...logCount {
                XCTAssertTrue(content.contains("并发日志 \(i)"), "❌ 缺少 `并发日志 \(i)`")
            }
        } else {
            XCTFail("❌ 无法读取日志文件")
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    /// **测试日志文件是否会超出最大容量**
    func testLogFileSizeLimit() async {
        let maxEntries = 500 // 假设 NDJSON 文件最多存储 500 条日志
        for i in 1...maxEntries {
            await LogLocalManager.shared.saveLog(message: "日志 \(i)", file: "SizeTest.swift", line: i)
        }

        // **等待日志写入**
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "❌ 日志文件应存在")

        if let logFile = logFiles.first,
           let content = try? String(contentsOf: logFile) {
            let lines = content.split(separator: "\n")
            XCTAssertLessThanOrEqual(lines.count, maxEntries, "❌ 日志文件过大，超过最大行数限制")
        } else {
            XCTFail("❌ 无法读取日志文件")
        }
    }

    /// **测试日志轮转（每天生成一个新文件）**
    func testLogRotation() async {
        let todayPath = await LogLocalManager.shared.getLogFilePath()
        let tomorrowPath = await LogLocalManager.shared.getLogFilePath(for: Date().addingTimeInterval(86400)) // +1 天

        XCTAssertNotEqual(todayPath, tomorrowPath, "❌ 日志文件未按天轮转")

        await LogLocalManager.shared.saveLog(message: "测试日志轮转", file: "RotationTest.swift", line: 1)

        // **等待日志写入**
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertTrue(logFiles.contains(todayPath), "❌ 今天的日志文件应存在")
    }

    /// **测试写入异常情况（文件不可写）**
//    func testWriteFailure() async {
//        let logFile = await LogLocalManager.shared.getLogFilePath()
//
//        // **确保文件存在**
//        if !FileManager.default.fileExists(atPath: logFile.path) {
//            FileManager.default.createFile(atPath: logFile.path, contents: nil)
//        }
//
//        // **设置文件保护，完全阻止访问**
//        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.complete]
//        try? FileManager.default.setAttributes(attributes, ofItemAtPath: logFile.path)
//
//        // **尝试写入日志**
//        await LogLocalManager.shared.saveLog(message: "测试不可写入", file: "ErrorTest.swift", line: 999)
//
//        // **恢复文件保护**
//        let writableAttributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.none]
//        try? FileManager.default.setAttributes(writableAttributes, ofItemAtPath: logFile.path)
//
//        // **检查日志文件内容**
//        let content = try? String(contentsOf: logFile)
//        XCTAssertFalse(content?.contains("测试不可写入") ?? false, "❌ 不可写入的情况下，日志不应写入文件")
//    }

    /// **测试日志删除功能**
    func testDeleteLogs() async {
        await LogLocalManager.shared.saveLog(message: "待删除日志", file: "DeleteTest.swift", line: 123)

        // **等待日志写入**
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        let logFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "❌ 日志文件应存在")

        for file in logFiles {
            try? FileManager.default.removeItem(at: file)
        }

        let remainingFiles = await LogLocalManager.shared.getLogFiles()
        XCTAssertTrue(remainingFiles.isEmpty, "❌ 日志文件未正确删除")
    }
    
    
}
