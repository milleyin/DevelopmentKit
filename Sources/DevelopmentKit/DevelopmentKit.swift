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
    public static let version: String = "0.0.3(2025023)"
    
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
    
    /// 公开方法，让外部模块检查 CloudKit 可用性
//    public static func checkCloudKit() async throws {
//        try await CloudKitManager.checkCloudKitAvailability()
//    }
}


// MARK: - 全局方法

@MainActor
public func Log<T>(_ message: T,
                   file: String = #file,
                   line: Int = #line) {
    
    DevelopmentKit.Log(message, file: file, line: line)
}


