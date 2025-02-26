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
- **日志功能**：打印带有时间戳、文件名和行号的日志

---

## 📦 安装

### 🔹 Swift Package Manager（推荐）
1. 在 Xcode 选择 **File > Add Packages**
2. 输入 `https://github.com/milleyin/DevelopmentKit.git`
3. 选择最新版本并添加到项目

---

## 🚀 使用示例

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

### 8️⃣ **字符串 SHA-256 加密**
```swift
import DevelopmentKit

let hash = "Hello, Swift!".sha256
print("SHA-256: \(hash)")
```

### 9️⃣ **验证电子邮件**
```swift
import DevelopmentKit

let email = "test@example.com"
let isValid = email.regexValidation(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$")
print("Email 是否有效: \(isValid)")
```

### 🔟 **日期格式化**
```swift
import DevelopmentKit

let date = Date()
print("格式化日期: \(date.toYMDFormat())")
```

### 1️⃣1️⃣ **日志功能**

```swift
import DevelopmentKit

Log("这是一条日志信息")
```

输出：

```
[2025-02-26 18:00:30]<MainView.swift:42>: 这是一条日志信息
```

---

## 📄 许可证
本项目采用 **MIT License**，可自由修改和使用，但请保留原作者信息。

---

## 💬 反馈 & 贡献
欢迎提 Issue 或 PR 贡献代码！ 🙌
