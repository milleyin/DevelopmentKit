//
//  File.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation
import UIKit

#if os(iOS)
extension UIApplication {
    /**
     隐藏键盘。
     
     - Important: 该方法使用 `UIResponder.resignFirstResponder`，
       通过 `sendAction` 方式使当前第一响应者失去焦点，从而关闭键盘。
     - Attention: 仅适用于 iOS 设备，macOS 和其他平台不支持。
     - Note: 适用于需要手动关闭键盘的场景，
       例如点击空白区域时。
     
     示例：
     
     ```swift
     UIApplication.shared.hideKeyboard()
     ```
     */
    public func hideKeyboard() {
        self.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
