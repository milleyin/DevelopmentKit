//
//  Utilities.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation
import SwiftUI
#if os(iOS)
import SafariServices
#elseif os(macOS) || targetEnvironment(macCatalyst)
import AppKit
import ServiceManagement
import os.log
#endif

extension DevelopmentKit.Utilities {
    /**
     复制文本到剪贴板。

     - Important: 该方法使用 `UIPasteboard.general` 将文本复制到剪贴板。
     - Attention: 仅适用于 iOS 设备，macOS 不适用。
     - Warning: 该方法仅在 `UIKit` 可用时生效，
       在 `SwiftUI` 或其他非 `UIKit` 设备上可能无法运行。
     - Requires: 需要 `UIKit` 框架支持。
     - Note: 复制后的文本可以在任何支持粘贴功能的应用中使用。

     示例：

     ```swift
     copyToClipboard(text: "Hello, world!")
     ```
     */
    public static func copyToClipboard(text: String) {
    #if canImport(UIKit)
        UIPasteboard.general.string = text
    #endif
    }

    
    /**
     获取 App 名称。

     - Important: 该方法从 `Bundle.main.infoDictionary` 中读取 `CFBundleDisplayName`
       或 `CFBundleName` 以获取应用名称。
     - Attention: 如果 `CFBundleDisplayName` 为空，则回退到 `CFBundleName`。
     - Warning: 该方法可能会返回 `未知应用`，如果 `info.plist` 中没有正确配置应用名称。
     - Requires: 需要访问 `Bundle.main.infoDictionary`。
     - Note: 适用于所有 iOS 设备，可用于日志记录或 UI 展示应用名称。

     示例：

     ```swift
     let appName = getAppName()
     print("当前 App 名称: \(appName)")
     ```
     */
    public static func getAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ??
        "未知应用"
    }
    
    /**
     获取软件版本号。

     - Important: 该方法从 `Bundle.main.infoDictionary` 中读取 `CFBundleShortVersionString`
       以获取应用的当前版本号。
     - Attention: 如果 `CFBundleShortVersionString` 为空，则返回 `Unknown`。
     - Requires: 需要访问 `Bundle.main.infoDictionary`。
     - Note: 适用于所有 iOS 设备，可用于显示应用版本信息。

     示例：

     ```swift
     let version = appVersion
     print("当前软件版本: \(version)")
     ```
     */
    public static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /**
     获取编译版本号。

     - Important: 该方法从 `Bundle.main.infoDictionary` 中读取 `CFBundleVersion`
       以获取应用的编译版本号。
     - Attention: 如果 `CFBundleVersion` 为空，则返回 `Unknown`。
     - Requires: 需要访问 `Bundle.main.infoDictionary`。
     - Note: 适用于所有 iOS 设备，可用于显示应用的编译版本信息。

     示例：

     ```swift
     let build = buildNumber
     print("当前编译版本号: \(build)")
     ```
     */
    public static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    ///运行环境检测
    public static let isPreview: Bool = {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }()
    
    
#if os(iOS)
    /**
     打开 iOS 设置内的当前 App 设置。
     
     - Important: 该方法会尝试打开 `UIApplication.openSettingsURLString`，
     以便用户直接跳转到本 App 在 iOS 设置中的界面。
     - Attention: 仅适用于 iOS 设备，在 macOS 上不可用。
     - Bug: 在某些情况下，系统可能不会正确响应 URL，建议用户手动检查。
     - Warning: 该方法依赖 `UIApplication.shared.open`，
     需要在主线程调用，建议在 `@MainActor` 环境中执行。
     - Requires: 需要 `UIApplication.shared.canOpenURL(url)` 返回 `true` 才能成功打开。
     - Note: 该方法适用于引导用户更改权限、通知或其他 App 相关设置。
     
     示例：
     
     ```swift
     openAppSettings()
     ```
     */
    @MainActor
    public static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
#elseif os(macOS)
    /**
     打开 macOS 系统设置。
     
     - Important: 该方法会尝试打开 `x-apple.systempreferences:`，
     以便用户访问 macOS 系统的偏好设置。
     - Attention: 仅适用于 macOS 设备，在 iOS 上不可用。
     - Bug: 在某些情况下，URL 可能无法正确解析，建议用户手动检查。
     - Warning: 该方法使用 `NSWorkspace.shared.open(url)`，
     需要确保 `NSWorkspace` 具有适当的权限来访问系统设置。
     - Requires: 需要 `NSWorkspace.shared.open(url)` 成功执行，才能正确打开设置。
     - Note: 该方法适用于引导用户修改系统级别的设置，如网络、权限或显示选项。
     
     示例：
     
     ```swift
     openAppSettings()
     ```
     */
    public static func openAppSettings() {
        guard let url = URL(string: "x-apple.systempreferences:") else {
            print("无法打开系统设置")
            return
        }
        NSWorkspace.shared.open(url)
    }
#endif
    
#if os(iOS)
    /**
     打开网页链接。
     
     - Important: 该方法会尝试打开指定的 URL。
     在 iOS 16.0 及以上版本，会使用 `SFSafariViewController` 进行网页展示。
     - Attention: 仅适用于 iOS 设备，macOS 不适用。
     - Bug: 如果 `urlString` 无效或无法解析，则方法不会执行任何操作。
     - Warning: 低于 iOS 16.0 的设备不支持 `SFSafariViewController`，
     可能需要额外处理。
     - Requires: 需要传入有效的 `urlString`，否则不会执行任何操作。
     - Note: 该方法适用于在 App 内部打开网页，而不是跳转到外部 Safari 浏览器。
     
     示例：
     
     ```swift
     openWebLink(urlString: "https://www.apple.com")
     ```
     */
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
#elseif os(macOS)
    public static func openWebLink(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("无效的 URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
#endif
    
#if os(iOS)
    /**
     在 iOS 设备上打开邮件应用。
     
     - Important: 该方法使用 `message://` URL 以尝试打开邮件应用。
     - Attention: 仅适用于 iOS 设备，macOS 不支持此方法。
     - Bug: 在部分设备或系统版本上，可能无法正确响应 `message://` URL。
     - Warning: 该方法依赖 `UIApplication.shared.open(url)`，必须在主线程调用，建议在 `@MainActor` 环境中执行。
     - Requires: 设备必须安装邮件应用，并支持 `UIApplication.shared.canOpenURL(url)`。
     - Returns: 无返回值。
     - Throws: 无异常抛出。
     - Note: 如果设备上未安装邮件应用，该方法不会有任何作用。
     
     ### 示例：
     ```swift
     openMailApp()
     ```
     */
    @MainActor
    public static func openMailApp() {
        guard let url = URL(string: "message://"), UIApplication.shared.canOpenURL(url) else {
            print("无法打开邮件应用")
            return
        }
        UIApplication.shared.open(url)
    }
#endif
    
#if os(macOS)
    /**
     在 macOS 设备上打开默认邮件客户端。
     
     - Important: 该方法使用 `mailto:` URL 以尝试打开默认邮件客户端。
     - Attention: 仅适用于 macOS 设备，iOS 不支持此方法。
     - Bug: 在部分 macOS 版本上，可能无法正确解析 `mailto:` URL。
     - Warning: 该方法依赖 `NSWorkspace.shared.open(url)`，不会检查邮件客户端的可用性。
     - Requires: 设备必须安装邮件客户端，并支持 `NSWorkspace.shared.open(url)`。
     - Returns: 无返回值。
     - Throws: 无异常抛出。
     - Note: 如果设备上未安装邮件客户端，该方法不会有任何作用。
     
     ### 示例：
     ```swift
     openMailApp()
     ```
     */
    public static func openMailApp() {
        guard let url = URL(string: "mailto:") else {
            print("无法打开邮件应用")
            return
        }
        NSWorkspace.shared.open(url)
    }
#endif
}

#if os(macOS) || targetEnvironment(macCatalyst)

public enum LaunchAtLogin {
    private static let logger = Logger(subsystem: "com.sindresorhus.LaunchAtLogin", category: "main")
    fileprivate static let observable = Observable()

    /**
     为你的应用程序切换 “登录时启动 ”或检查是否启用。
    */
    public static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            observable.objectWillChange.send()

            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }

                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.error("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }

    /**
     应用程序是否在登录时启动。

    - Important: 此属性只能在 `NSApplicationDelegate#applicationDidFinishLaunching`中选中。
    */
    public static var wasLaunchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

extension LaunchAtLogin {
    final class Observable: ObservableObject {
        var isEnabled: Bool {
            get { LaunchAtLogin.isEnabled }
            set {
                LaunchAtLogin.isEnabled = newValue
            }
        }
    }
}

extension LaunchAtLogin {
    /**
     该软件包附带一个 `LaunchAtLogin.Toggle` 视图，它与内置的 `Toggle` 视图类似，但具有预定义的绑定和标签。点击该视图可切换应用程序的 “登录时启动”。

    ```
    struct ContentView: View {
        var body: some View {
            LaunchAtLogin.Toggle()
        }
    }
    ```

     默认标签为 “登录时启动”，但可根据本地化和其他需要进行重写：

    ```
    struct ContentView: View {
        var body: some View {
            LaunchAtLogin.Toggle {
                Text("Launch at login")
            }
        }
    }
    ```
    */
    public struct Toggle<Label: View>: View {
        @ObservedObject private var launchAtLogin = LaunchAtLogin.observable
        private let label: Label

        /**
         创建显示自定义标签的切换按钮。

        - Parameters:
            - label: 描述切换目的的视图。
        */
        public init(@ViewBuilder label: () -> Label) {
            self.label = label()
        }

        public var body: some View {
            SwiftUI.Toggle(isOn: $launchAtLogin.isEnabled) { label }
        }
    }
}

extension LaunchAtLogin.Toggle<Text> {
    /**
     创建根据本地化字符串键生成标签的切换开关。

     该初始化程序会使用提供的 `titleKey` 代您创建一个 ``Text`` 视图。

    - Parameters:
        - titleKey: 切换按钮本地化标题的键值，用于描述切换按钮的用途。
    */
    public init(_ titleKey: LocalizedStringKey) {
        label = Text(titleKey)
    }

    /**
    创建一个可从字符串生成标签的切换视图。

    该初始化程序会使用提供的 “title ”为您创建一个 “Text ”视图。

    - Parameters:
        - title: 描述切换目的的字符串。
    */
    public init(_ title: some StringProtocol) {
        label = Text(title)
    }

    /**
     创建一个切换按钮，默认标题为 “登录时启动”。
    */
    public init() {
        self.init("Launch at login")
    }
}
#endif
