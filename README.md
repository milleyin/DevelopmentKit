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

### **Logging Utility (`Log(<T>)`)**

#### **Overview**

The `Log()` function logs messages to the Xcode console, and if CloudKit is enabled, it will automatically store logs in the iCloud private database.

#### **Setup Requirements for CloudKit Logging**

Before using CloudKit for logging, complete the following setup:

1. **Enable CloudKit in Xcode**
   - Open **Signing & Capabilities** in your project.
   - Add **iCloud** capability.
   - Enable **CloudKit**.
   - Ensure a default iCloud container (e.g., `iCloud.com.yourcompany.ABC`) is available.

2. **Update `Info.plist`**
   Add the following key:

   ```xml
   <key>NSUbiquitousContainers</key>
   <dict>
       <key>iCloud.com.yourcompany.ABC</key>
       <dict>
           <key>NSUbiquitousContainerIsDocumentScopePublic</key>
           <false/>
           <key>NSUbiquitousContainerSupportedFolderLevels</key>
           <string>None</string>
       </dict>
   </dict>
   ```

3. **Initialize CloudKit in `AppDelegate.swift` or `App.swift`**

   ```swift
   import DevelopmentKit

   @main
   class AppDelegate: UIResponder, UIApplicationDelegate {
       
       func application(_ application: UIApplication,
                        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
           
           // ✅ Check CloudKit Availability
           Task {
               await CloudKitManager.checkCloudKitAvailability()
           }
           
           return true
       }
   }
   ```

   ```swift
   import DevelopmentKit

   @main
   struct ABCApp: App {
       init() {
           Task {
               await CloudKitManager.checkCloudKitAvailability()
           }
       }

       var body: some Scene {
           WindowGroup {
               ContentView()
           }
       }
   }
   ```

#### **Usage**

```swift
import DevelopmentKit

Log("This is a log message")
```

**Output:**

```
[2025-02-26 18:00:30]<MainView.swift:42>: This is a log message
✅ Log successfully saved to CloudKit.
```

If CloudKit is not enabled:

```
[2025-02-26 18:00:30]<MainView.swift:42>: This is a log message
⚠️ CloudKit is not available.
```

---

## 🚀 Other Usage Examples

### 1️⃣ **Open System Mail App**

```swift
import DevelopmentKit

DevelopmentKit.openMailApp()
```

### 2️⃣ **Open App Settings**

```swift
import DevelopmentKit

DevelopmentKit.openAppSettings()
```

### 3️⃣ **Open Web Link**

```swift
import DevelopmentKit

DevelopmentKit.openWebLink(urlString: "https://www.apple.com")
```

### 4️⃣ **Get Network Type**

```swift
import DevelopmentKit

let networkType = DevelopmentKit.getNetworkType()
print("Current network type: \(networkType)")
```

### 5️⃣ **Copy Text to Clipboard**

```swift
import DevelopmentKit

DevelopmentKit.copyToClipboard(text: "Hello, DevelopmentKit!")
```

### 6️⃣ **Get App Info**

```swift
import DevelopmentKit

print("App Name: \(DevelopmentKit.getAppName())")
print("App Version: \(DevelopmentKit.appVersion)")
print("Build Number: \(DevelopmentKit.buildNumber)")
```

### 7️⃣ **Hide Keyboard**

```swift
import DevelopmentKit
import UIKit

UIApplication.shared.hideKeyboard()
```

### 8️⃣ **SHA-256 Hashing**

```swift
import DevelopmentKit

let hash = "Hello, Swift!".sha256
print("SHA-256: \(hash)")
```

### 9️⃣ **Validate Email**

```swift
import DevelopmentKit

let email = "test@example.com"
let isValid = email.regexValidation(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")
print("Is valid email: \(isValid)")
```

### 🔟 **Date Formatting**

```swift
import DevelopmentKit

let date = Date()
print("Formatted date: \(date.toYMDFormat())")
```

---

## 📜 API List

| API                                                          | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `DevelopmentKit.isPreview`                                   | Check if running in SwiftUI preview mode                     |
| `DevelopmentKit.openMailApp()`                               | Open system mail app                                         |
| `DevelopmentKit.openAppSettings()`                           | Navigate to the current app settings page                    |
| `DevelopmentKit.openWebLink(urlString: String)`              | Open a web link using `SFSafariViewController`               |
| `DevelopmentKit.getNetworkType() -> String`                  | Get current network type (Wi-Fi, Cellular, No Network, etc.) |
| `DevelopmentKit.copyToClipboard(text: String)`               | Copy text to clipboard                                       |
| `DevelopmentKit.getAppName() -> String`                      | Get current app name                                         |
| `DevelopmentKit.appVersion: String`                          | Get current app version                                      |
| `DevelopmentKit.buildNumber: String`                         | Get current app build number                                 |
| `UIApplication.hideKeyboard()`                               | Hide keyboard (`resignFirstResponder` event)                 |
| `UIColor.init(hex: String, alpha: CGFloat = 1.0)`            | Initialize `UIColor` using a hex string                      |
| `Image.repeating(times: Int, spacing: CGFloat) -> some View` | Repeat `Image` component multiple times                      |
| `Color.init(hex: String)`                                    | Initialize `Color` using a hex string                        |
| `Date.toYMDFormat() -> String`                               | Convert `Date` to `yyyy-MM-dd` format string                 |
| `String.regexValidation(pattern: String) -> Bool`            | Validate string using regex                                  |
| `String.toDate(format: String) -> Date?`                     | Convert string to `Date`                                     |
| `String.sha256: String`                                      | Compute `SHA-256` hash of a string                           |
| `Log<T>(_ message: T, file: String, line: Int)`              | Print log message with timestamp, file name, and optionally store it in CloudKit |

---

## 📄 License

This project is licensed under the **MIT License**. You are free to modify and use it, but please retain the original author information.

---

## 💬 Feedback & Contribution

Feel free to open an issue or submit a PR! 🙌
