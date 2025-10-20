# DevelopmentKit

[中文](README_cn.md)

![DALL·E 2025-02-26 09 29 25 - A modern and stylish banner for 'DevelopmentKit', a Swift development toolkit, designed with a 'workshop' or 'tool shed' aesthetic  The background fea](https://github.com/user-attachments/assets/62d9975b-9187-4af9-8df6-edca1a4963ec)

🚀 **DevelopmentKit** is a lightweight Swift toolkit providing **essential iOS utilities**, covering **app management, network detection, clipboard, date handling, regex validation**, and more.

## 📌 Features

- **iOS Device Management**: Open mail app, system settings
- **Network Utilities**: Detect current network type
- **Clipboard**: Copy text to clipboard
- **System Info**: Get app name, version, build number
- **UIKit & SwiftUI Extensions**: Colors, image processing, keyboard management
- **String Processing**: Regex validation, date conversion, SHA-256 encryption
- **Number Formatting**: Format seconds, percentage conversion
- **Logging Utility**: Print logs with timestamp, file, and line number, and optionally store logs in iCloud

---

## 📦 Installation

### 🔹 Swift Package Manager (Recommended)

1. In Xcode, go to **File > Add Packages**
2. Enter `https://github.com/milleyin/DevelopmentKit.git`
3. Select the latest version and add it to your project

---

## 🎉 Special Feature

## Logging Utility (`Log(<T>)`)

### Overview

The `Log()` function logs messages to the Xcode console. Currently, it only supports local logging via `print()`. Cloud storage functionality (e.g., CloudKit or other backend solutions) is under development.

### Usage

```swift
import DevelopmentKit

Log("This is a log message")
```

**Output:**

```
[2025-02-26 18:00:30]<MainView.swift:42>: This is a log message
```



# 📜 DevelopmentKit API List

| API                                                                                                                              | Description                                                                      |
|:---------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------------------------------------|
| isPreview                                                                                                         | Check if running in SwiftUI preview mode                                         |
| openMailApp()                                                                                                     | Open system mail app                                                             |
| openAppSettings()                                                                                                 | Navigate to the current app settings page                                        |
| openWebLink(urlString: String)                                                                                    | Open a web link using SFSafariViewController                                     |
| getNetworkType() -> String                                                                                        | Get current network type (Wi-Fi, Cellular, No Network, etc.)                     |
| copyToClipboard(text: String)                                                                                     | Copy text to clipboard                                                           |
| getAppName() -> String                                                                                            | Get current app name                                                             |
| appVersion: String                                                                                                | Get current app version                                                          |
| buildNumber: String                                                                                               | Get current app build number                                                     |
| UIApplication.hideKeyboard()                                                                                                     | Hide keyboard (resignFirstResponder event)                                       |
| UIColor.init(hex: String, alpha: CGFloat = 1.0)                                                                                  | Initialize UIColor using a hex string                                            |
| Image.repeating(times: Int, spacing: CGFloat) -> some View                                                                       | Repeat Image component multiple times                                            |
| Color.init(hex: String)                                                                                                          | Initialize Color using a hex string                                              |
| Date.toYMDFormat() -> String                                                                                                     | Convert Date to yyyy-MM-dd format string                                         |
| String.regexValidation(pattern: String) -> Bool                                                                                  | Validate string using regex                                                      |
| String.toDate(format: String) -> Date?                                                                                           | Convert string to Date                                                           |
| String.sha256: String                                                                                                            | Compute SHA-256 hash of a string                                                 |
| Log<T>(_ message: T, file: String, line: Int)                                                                                    | Print log message with timestamp, file name, and optionally store it in CloudKit |
| getMemoryInfoPublisher() -> AnyPublisher<MacMemoryInfo, Error>                                                           | Fetch total, free, used, and inactive memory (in GB)                             |
| getCPUInfoPublisher() -> AnyPublisher<MacCPUInfo, Error>                                                                 | Fetch CPU model, core count, usage %, and per-core usage                         |
| getBatteryInfoPublisher() -> AnyPublisher<MacBatteryInfo, Error>                                                         | Fetch battery level, temperature, charging status, and cycle count (macOS only)  |
| getBatteryLevelPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<Int, Never>                                | Continuously observe battery level (iOS only)                                    |
| getLocalIPAddress() -> String?                                                                                    | Get local IPv4 address (Wi-Fi or Cellular)                                       |
| getSystemNetworkThroughputPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<SystemNetworkThroughput, Never> | Observe network throughput (upload/download bytes per second)                    |
| getWiFiSignalLevelPublisher(interval: TimeInterval = 1.0) -> AnyPublisher<WiFiSignalLevel, Never>                 | Observe current Wi-Fi signal strength level (macOS only)                         |
| getNetworkTypePublisher(timeout: TimeInterval = 0.5) -> AnyPublisher<NetworkType, NetworkError>                   | Get current network connection type with optional timeout                        |
| `LaunchAtLoginManager.shared.setEnabled(Bool)` | Enable or disable macOS app launch at login |
| `LaunchAtLoginManager.shared.isEnabled: Bool` | Check whether launch at login is currently enabled |

## 🚀 Contribution Guidelines

### ❌ Do NOT fork the `main` branch
The `main` branch is used for **stable and tested releases** only.

### ✅ Fork the `dev` branch
- The `dev` branch is the **testing branch**, where all modifications are merged and tested.
- **`dev` is the only source for `main`**.
- If you want to contribute, please fork the `dev` branch instead.

---

## 📄 License

**This project is licensed under the GNU General Public License v3.0 (GPL v3.0).**
You are free to modify, distribute, and use it under the terms of the GPL v3.0 license.
Any derivative works must also be licensed under GPL v3.0. Please retain the original author information in all copies and modifications.

---

## 💬 Feedback & Contribution

Feel free to open an issue or submit a PR! 🙌
