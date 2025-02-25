# DevelopmentKit

🚀 **DevelopmentKit** 是一个 Swift 轻量级工具库，提供 **iOS 常用功能封装**，涵盖 **应用管理、网络检测、剪贴板、日期处理、正则验证** 等。

## 📌 功能特性
- **iOS 设备管理**：邮件、系统设置、Apple Maps 导航
- **网络工具**：获取当前网络类型
- **剪贴板**：复制文本
- **系统信息**：获取 App 名称、版本号、编译号
- **UIKit & SwiftUI 扩展**：颜色、图片处理、键盘管理
- **字符串处理**：正则验证、日期转换、SHA-256 加密
- **数值计算**：秒数格式化、百分比转换

---

## 📦 安装

### 🔹 Swift Package Manager（推荐）
1. 在 Xcode 选择 **File > Add Packages**
2. 输入 `https://github.com/your-repo/DevelopmentKit.git`
3. 选择最新版本并添加到项目

---

## 🚀 使用示例

### 1️⃣ **打开系统邮件**
```swift
import DevelopmentKit

openMailApp()
```

### 2️⃣ **打开 App 设置**
```swift
import DevelopmentKit

openAppSettings()
```

### 3️⃣ **打开网页链接**
```swift
import DevelopmentKit

openWebLink(urlString: "https://www.apple.com")
```

### 4️⃣ **获取网络类型**
```swift
import DevelopmentKit

let networkType = getNetworkType()
print("当前网络类型: \(networkType)")
```

### 5️⃣ **在 Apple Maps 导航**
```swift
import DevelopmentKit
import CoreLocation

let destination = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
openInAppleMaps(start: nil, destination: destination, destinationName: "San Francisco")
```

### 6️⃣ **复制文本到剪贴板**
```swift
import DevelopmentKit

copyToClipboard(text: "Hello, DevelopmentKit!")
```

### 7️⃣ **获取 App 信息**
```swift
import DevelopmentKit

print("App 名称: \(getAppName())")
print("App 版本: \(appVersion)")
print("编译版本: \(buildNumber)")
```

### 8️⃣ **隐藏键盘**
```swift
import DevelopmentKit
import UIKit

UIApplication.shared.hideKeyboard()
```

### 9️⃣ **字符串 SHA-256 加密**
```swift
import DevelopmentKit

let hash = "Hello, Swift!".sha256
print("SHA-256: \(hash)")
```

### 🔟 **验证电子邮件**
```swift
import DevelopmentKit

let email = "test@example.com"
let isValid = email.regexValidation(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")
print("Email 是否有效: \(isValid)")
```

### 1️⃣1️⃣ **日期格式化**
```swift
import DevelopmentKit

let date = Date()
print("格式化日期: \(date.toYMDFormat())")
```

---

## 📜 API 列表

| API 名称 | 功能描述 |
|----------|----------|
| `openMailApp()` | 打开系统邮件应用 |
| `openAppSettings()` | 跳转到 iOS 系统设置中的当前应用设置页面 |
| `openWebLink(urlString: String)` | 使用 `SFSafariViewController` 在应用内打开网页 |
| `getNetworkType() -> String` | 获取当前网络类型（Wi-Fi、蜂窝、无网络等） |
| `openInAppleMaps(start: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D, destinationName: String)` | 在 Apple Maps 进行导航 |
| `copyToClipboard(text: String)` | 复制文本到剪贴板 |
| `getAppName() -> String` | 获取当前 App 的名称 |
| `appVersion: String` | 获取当前 App 版本号 |
| `buildNumber: String` | 获取当前 App 编译版本号 |
| `UIApplication.hideKeyboard()` | 隐藏键盘（发送 `resignFirstResponder` 事件） |
| `UIColor.init(hex: String, alpha: CGFloat = 1.0)` | 使用十六进制字符串初始化 `UIColor` |
| `Image.repeating(times: Int, spacing: CGFloat) -> some View` | 使 `Image` 组件重复显示多次 |
| `Color.init(hex: String)` | 使用十六进制字符串初始化 `Color` |
| `Date.toYMDFormat() -> String` | 将 `Date` 转换为 `yyyy-MM-dd` 格式字符串 |
| `String.regexValidation(pattern: String) -> Bool` | 使用正则表达式验证字符串 |
| `String.toDate(format: String) -> Date?` | 将字符串转换为 `Date` |
| `String.sha256: String` | 计算字符串的 `SHA-256` 哈希值 |
| `Double.toPercentage(decimals: Int) -> String` | 将 `Double` 转换为百分比字符串 |
| `Int.intToTimeFormat(hoursOnly: Bool) -> String` | 将秒数转换为 `小时:分钟:秒` 格式字符串 |

---

## 📄 许可证
本项目采用 **MIT License**，可自由修改和使用，但请保留原作者信息。

---

## 💬 反馈 & 贡献
欢迎提 Issue 或 PR 贡献代码！ 🙌
