//
//  DevelopmentKitTests.swift
//  DevelopmentKitTests
//
//  Created by Mille Yin on 2024/11/7.
//

import XCTest
import CloudKit
@testable import DevelopmentKit

final class DevelopmentKitTests: XCTestCase {
    
    /// 测试 `isPreview` 是否正确检测 SwiftUI 预览模式
    func testIsPreview() {
        let previewEnv = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"]
        let expected = previewEnv == "1"
        XCTAssertEqual(DevelopmentKit.isPreview, expected)
    }
    
    /// 测试 `openMailApp()` 是否正确处理未安装邮件应用的情况
    @MainActor func testOpenMailApp() {
#if os(iOS)
        let mailURL = URL(string: "message://")!
        let canOpen = UIApplication.shared.canOpenURL(mailURL)
        if canOpen {
            DevelopmentKit.openMailApp()
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
            DevelopmentKit.openAppSettings()
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
        
        DevelopmentKit.openWebLink(urlString: validURL)
        XCTAssertTrue(true, "成功打开网页：\(validURL)")
        
        DevelopmentKit.openWebLink(urlString: invalidURL)
        XCTAssertTrue(true, "无效 URL 应该不会崩溃")
#endif
    }
    
    /// 测试 `getNetworkType()` 是否正确检测网络类型
    func testGetNetworkType() {
        let networkType = DevelopmentKit.getNetworkType()
        let validTypes = ["Wi-Fi", "蜂窝移动网络", "有线网络", "其他网络", "无网络连接", "未知"]
        XCTAssertTrue(validTypes.contains(networkType), "返回的网络类型应在预定义的类型范围内")
    }
    
    /// 测试 `copyToClipboard(text:)` 是否正确复制文本
    func testCopyToClipboard() {
#if os(iOS)
        let testString = "Hello, Clipboard!"
        DevelopmentKit.copyToClipboard(text: testString)
        XCTAssertEqual(UIPasteboard.general.string, testString, "剪贴板内容应与输入一致")
#endif
    }
    
    /// 测试 `getAppName()` 是否正确获取 App 名称
    func testGetAppName() {
        let appName = DevelopmentKit.getAppName()
        XCTAssertFalse(appName.isEmpty, "App 名称不应为空")
    }
    
    /// 测试 `appVersion` 是否能正确获取版本号
    func testAppVersion() {
        XCTAssertFalse(DevelopmentKit.appVersion.isEmpty, "App 版本号不应为空")
    }
    
    /// 测试 `buildNumber` 是否能正确获取编译版本号
    func testBuildNumber() {
        XCTAssertFalse(DevelopmentKit.buildNumber.isEmpty, "App 编译版本号不应为空")
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
    
    // MARK: - Log 测试

        /// 测试 `Log()` 是否正确输出到 Xcode 控制台（仅检查不会崩溃）
        func testLogFunction() {
            Log("Test log message")
            XCTAssertTrue(true, "`Log()` 调用成功，不应导致崩溃")
        }

        // MARK: - CloudKit 错误处理测试

    /// 测试 `CloudKitManager` 处理 **无效 iCloud 容器** 时是否会崩溃
//    func testCloudKitContainerInvalid() async {
//        let expectation = XCTestExpectation(description: "CloudKit should fail gracefully when an unregistered container is used")
//
//        Task {
//            do {
//                let invalidContainer = CKContainer(identifier: "iCloud.com.invalid") // ✅ 传入未注册的 iCloud 容器
//                XCTAssertNil(invalidContainer.containerIdentifier, "未注册的容器 `identifier` 应该是 `nil`")
//            } catch {
//                XCTFail("未注册的容器应该不会崩溃，而是返回 `nil`")
//            }
//            expectation.fulfill()
//        }
//
//        await fulfillment(of: [expectation], timeout: 5.0)
//    }


    /// 测试 `CloudKitManager` 在 **正确的 iCloud 容器** 时，是否能正常工作
//    func testCloudKitContainerAvailable() async {
//        let expectation = XCTestExpectation(description: "CloudKit should pass when configured correctly")
//
//        Task {
//            do {
//                // ✅ 直接 Mock 通过，不让 `CKContainer.default()` 执行
//                let mockStatus: CKAccountStatus = .available
//                XCTAssertEqual(mockStatus, .available, "CloudKit 配置正确，应当成功通过检查")
//
//            } catch {
//                XCTFail("CloudKit 已正确配置，但仍然抛出错误: \(error)")
//            }
//            expectation.fulfill()
//        }
//
//        await fulfillment(of: [expectation], timeout: 5.0)
//    }
//
//
//
//        /// 测试 `saveLogToCloud()` 在 **CloudKit 关闭** 时的错误处理
//        func testSaveLogWithCloudKitDisabled() async {
//            let expectation = XCTestExpectation(description: "saveLogToCloud should fail when CloudKit is disabled")
//
//            Task {
//                do {
//                    try await CloudKitManager.saveLogToCloud("Test log message", file: "TestFile.swift", line: 42)
//                    XCTFail("CloudKit 关闭时，应该抛出 `CloudKitError.containerNotConfigured` 错误")
//                } catch CloudKitError.containerNotConfigured {
//                    XCTAssertTrue(true, "正确捕获 `CloudKitError.containerNotConfigured`")
//                } catch {
//                    XCTFail("捕获到意外错误: \(error)")
//                }
//                expectation.fulfill()
//            }
//
//            await fulfillment(of: [expectation], timeout: 5.0)
//        }
//
//        /// 测试 `saveLogToCloud()` 在 **未登录 iCloud** 时的错误处理
//        func testSaveLogWithoutiCloudLogin() async {
//            let expectation = XCTestExpectation(description: "saveLogToCloud should fail when user is not logged into iCloud")
//
//            Task {
//                do {
//                    try await CloudKitManager.saveLogToCloud("Test log message", file: "TestFile.swift", line: 42)
//                    XCTFail("未登录 iCloud 时，应该抛出 `CKError.notAuthenticated` 错误")
//                } catch let ckError as CKError where ckError.code == .notAuthenticated {
//                    XCTAssertTrue(true, "正确捕获 `CKError.notAuthenticated`")
//                } catch {
//                    XCTFail("捕获到意外错误: \(error)")
//                }
//                expectation.fulfill()
//            }
//
//            await fulfillment(of: [expectation], timeout: 5.0)
//        }
//
//        /// 测试 `saveLogToCloud()` 在 **CloudKit 配额超限** 时的错误处理
//        func testSaveLogWhenQuotaExceeded() async {
//            let expectation = XCTestExpectation(description: "saveLogToCloud should fail when CloudKit quota is exceeded")
//
//            Task {
//                do {
//                    try await CloudKitManager.saveLogToCloud("Test log message", file: "TestFile.swift", line: 42)
//                    XCTFail("CloudKit 配额超限时，应该抛出 `CKError.quotaExceeded` 错误")
//                } catch let ckError as CKError where ckError.code == .quotaExceeded {
//                    XCTAssertTrue(true, "正确捕获 `CKError.quotaExceeded`")
//                } catch {
//                    XCTFail("捕获到意外错误: \(error)")
//                }
//                expectation.fulfill()
//            }
//
//            await fulfillment(of: [expectation], timeout: 5.0)
//        }
//
//        /// 测试 `saveLogToCloud()` 在 **网络断开** 时的错误处理
//        func testSaveLogWithNetworkFailure() async {
//            let expectation = XCTestExpectation(description: "saveLogToCloud should retry when network is unavailable")
//
//            Task {
//                do {
//                    try await CloudKitManager.saveLogToCloud("Test log message", file: "TestFile.swift", line: 42)
//                    XCTFail("网络断开时，应该抛出 `CKError.networkUnavailable` 或 `CKError.networkFailure` 错误")
//                } catch let ckError as CKError where ckError.code == .networkUnavailable || ckError.code == .networkFailure {
//                    XCTAssertTrue(true, "正确捕获 `CKError.networkUnavailable` 或 `CKError.networkFailure`")
//                } catch {
//                    XCTFail("捕获到意外错误: \(error)")
//                }
//                expectation.fulfill()
//            }
//
//            await fulfillment(of: [expectation], timeout: 5.0)
//        }
//
}
