// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  DevelopmentKit.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2024/11/7.
//

import Foundation
#if os(iOS)
import SafariServices
import CoreLocation
import MapKit
import Network

#endif

public class DevelopmentKit {
    
    /// DevelopmentKit 版本号
    public static let version: String = "0.0.2(2025011)"
    
    // MARK: - 运行环境检测
    /**
     运行环境检测，判断是否在 SwiftUI 预览模式下

     - Returns: `true` 表示当前代码在 SwiftUI 预览模式运行
     */
    public static let isPreview: Bool = {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }()

    // MARK: - iOS 专属功能
    #if os(iOS)

    /// 打开系统邮箱 App
    @MainActor
    public static func openMailApp() {
        guard let url = URL(string: "message://"), UIApplication.shared.canOpenURL(url) else {
            print("无法打开邮件应用")
            return
        }
        UIApplication.shared.open(url)
    }

    /// 打开 iOS 设置内的本 App 设置
    @MainActor
    public static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    /// 打开网页链接
    @MainActor
    public static func openWebLink(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("无效的 URL")
            return
        }
        
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                print("无法获取 Root View Controller")
                return
            }
            let safariVC = SFSafariViewController(url: url)
            rootVC.present(safariVC, animated: true)
        } else {
            print("iOS 版本过低，不支持打开 Safari")
        }
    }

    /// 获取当前网络类型
    public static func getNetworkType() -> String {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue.global(qos: .background)
        var networkType = "未知"

        let semaphore = DispatchSemaphore(value: 0)

        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    networkType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    networkType = "蜂窝移动网络"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    networkType = "有线网络"
                } else if path.usesInterfaceType(.other) {
                    networkType = "其他网络"
                } else {
                    networkType = "无网络连接"
                }
            }
            monitor.cancel()
            semaphore.signal()
        }
        monitor.start(queue: queue)

        _ = semaphore.wait(timeout: .now() + 0.5)
        return networkType
    }

    #endif

    // MARK: - 通用功能
    /// 复制文本到剪贴板
    public static func copyToClipboard(text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    /// 获取 App 名称
    public static func getAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
               Bundle.main.infoDictionary?["CFBundleName"] as? String ??
               "未知应用"
    }

    /// 获取软件版本号
    public static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// 获取编译版本号
    public static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}


// MARK: - 全局方法


/**
 全局日志方法，支持 `Log("xxx")` 直接调用

 - Important: 该方法是 `DevelopmentKit.Log` 方法的全局封装，方便直接调用
 - Attention: `file` 和 `line` 默认参数用于自动获取当前文件名和行号
 - Bug: 目前无已知 Bug
 - Warning: `DevelopmentKit.Log` 负责实际日志处理，该方法仅作为快捷方式
 - Requires: 需要 `DevelopmentKit`
 - Remark: `Log` 方法用于调试和日志记录，可直接在项目中调用
 - Note: `print` 输出格式如下：
 
   `[yyyy-MM-dd HH:mm:ss]<文件名:行号>: 日志内容`
 
 - Precondition: `message` 必须能够转换为 `String`
 - Postcondition: 日志信息已打印到 Xcode 控制台
 
 示例：
 
 ```swift
 Log("测试日志输出")
 ```
 
 输出：
 
 ```
 [2025-02-26 18:00:30]<MainView.swift:42>: 测试日志输出
 ```

 - parameter message: 需要记录的日志内容
 - parameter file: 调用该方法的文件路径，默认使用 `#file`
 - parameter line: 调用该方法的代码行号，默认使用 `#line`
 - Returns: 无返回值
 - Throws: 无异常抛出
 */
public func Log<T>(_ message: T,
                   file: String = #file,
                   line: Int = #line) {
    DevelopmentKit.Log(message, file: file, line: line)
}

