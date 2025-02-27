# DevelopmentKit

[English](README.md)

![DALL·E 2025-02-26 09 29 25 - A modern and stylish banner for 'DevelopmentKit', a Swift development toolkit, designed with a 'workshop' or 'tool shed' aesthetic  The background fea](https://github.com/user-attachments/assets/62d9975b-9187-4af9-8df6-edca1a4963ec)

🚀 **DevelopmentKit** 是一个 Swift 轻量级工具库，提供 **iOS 常用功能封装**，涵盖 **应用管理、网络检测、剪贴板、日期处理、正则验证** 等。

## 📌 功能特性

- **iOS 设备管理**：邮件、系统设置
- **网络工具**：获取当前网络类型
- **剪贴板**：复制文本
- **系统信息**：获取 App 名称、版本号、编译号
- **UIKit & SwiftUI 扩展**：颜色、图片处理、键盘管理
- **字符串处理**：正则验证、日期转换、SHA-256 加密
- **数值计算**：秒数格式化、百分比转换
- **日志功能**：打印日志到 Xcode 控制台，并可选存储到 iCloud（CloudKit）

---

## 📦 安装

### 🔹 Swift Package Manager（推荐）

1. 在 Xcode 选择 **File > Add Packages**
2. 输入 `https://github.com/milleyin/DevelopmentKit.git`
3. 选择最新版本并添加到项目

---

# 🎉 特色功能

## **日志功能 (`Log(<T>)`)**

### **功能概述**

`Log()` 方法用于将日志信息输出到 Xcode 控制台。目前仅支持本地 `print()` 输出，云存储功能（如 CloudKit 或其他服务器存储）仍在开发中。

### **使用方法**

```swift
import DevelopmentKit

Log("这是一条日志信息")
```

**输出示例：**

```
[2025-02-26 18:00:30]<MainView.swift:42>: 这是一条日志信息
```

---

## 🚀 其他功能示例

### 1️⃣ **打开系统邮件**

```swift
import DevelopmentKit

DevelopmentKit.openMailApp()
```

### 2️⃣ **打开 App 设置**

```swift
import DevelopmentKit

DevelopmentKit.openAppSettings()
```

### 3️⃣ **打开网页链接**

```swift
import DevelopmentKit

DevelopmentKit.openWebLink(urlString: "https://www.apple.com")
```

### 4️⃣ **获取网络类型**

```swift
import DevelopmentKit

let networkType = DevelopmentKit.getNetworkType()
print("当前网络类型: \(networkType)")
```

### 5️⃣ **复制文本到剪贴板**

```swift
import DevelopmentKit

DevelopmentKit.copyToClipboard(text: "Hello, DevelopmentKit!")
```

### 6️⃣ **获取 App 信息**

```swift
import DevelopmentKit

print("App 名称: \(DevelopmentKit.getAppName())")
print("App 版本: \(DevelopmentKit.appVersion)")
print("编译版本: \(DevelopmentKit.buildNumber)")
```

### 7️⃣ **隐藏键盘**

```swift
import DevelopmentKit
import UIKit

UIApplication.shared.hideKeyboard()
```

### 8️⃣ **SHA-256 加密**

```swift
import DevelopmentKit

let hash = "Hello, Swift!".sha256
print("SHA-256: \(hash)")
```

### 9️⃣ **验证电子邮件**

```swift
import DevelopmentKit

let email = "test@example.com"
let isValid = email.regexValidation(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")
print("Email 是否有效: \(isValid)")
```

### 🔟 **日期格式化**

```swift
import DevelopmentKit

let date = Date()
print("格式化日期: \(date.toYMDFormat())")
```

---

## 📜 API 列表

| API 名称 | 功能描述 |
|----------|----------|
| `DevelopmentKit.isPreview` | 判断是否在 SwiftUI 预览模式运行 |
| `DevelopmentKit.openMailApp()` | 打开系统邮件应用 |
| `DevelopmentKit.openAppSettings()` | 跳转到 iOS 系统设置中的当前应用设置页面 |
| `DevelopmentKit.openWebLink(urlString: String)` | 在 `SFSafariViewController` 中打开网页 |
| `DevelopmentKit.getNetworkType() -> String` | 获取当前网络类型（Wi-Fi、蜂窝、无网络等） |
| `DevelopmentKit.copyToClipboard(text: String)` | 复制文本到剪贴板 |
| `DevelopmentKit.getAppName() -> String` | 获取当前 App 名称 |
| `DevelopmentKit.appVersion: String` | 获取当前 App 版本号 |
| `DevelopmentKit.buildNumber: String` | 获取当前 App 编译版本号 |
| `UIApplication.hideKeyboard()` | 隐藏键盘（发送 `resignFirstResponder` 事件） |
| `Log<T>(_ message: T, file: String, line: Int)` | 在 Xcode 控制台打印日志，并在启用 CloudKit 后自动存储到 iCloud |

---

## 如何参与

📌 分支管理规范 (Branch Management Guidelines)

🚫 请勿 Fork main 分支
    •    main 分支用于发布 已通过测试的稳定版本 代码，请勿直接 Fork 此分支。

🚀 开发 & 测试分支 (Dev)
    •    Dev 分支为 测试分支，所有功能修改和代码变更都会 首先合并到此分支进行测试。
    •    Dev 分支是 main 分支的 唯一来源，即 main 分支的更新 只能从 Dev 分支合并。
    •    如欲参与开发，请 Fork Dev 分支，而非 main 分支。

---

## 📄 许可证

本项目采用 **MIT License**，可自由修改和使用，但请保留原作者信息。

---

## 💬 反馈 & 贡献

欢迎提 Issue 或 PR 贡献代码！ 🙌
