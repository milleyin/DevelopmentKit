//
//  LogLocalManager.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/28.
//

import Foundation

/// **日志本地管理器**
///
/// `LogLocalManager` 是一个线程安全的 actor，负责将应用日志以 NDJSON 格式存储到本地磁盘。
///
/// - Important:
///   - 使用 Swift Concurrency 的 `actor` 隔离，确保日志写入的线程安全。
///   - 采用缓存机制，减少磁盘 I/O 次数，提升性能。
///   - 日志按天存储，每天生成一个新的 `.log` 文件。
///
/// - Note:
///   - **缓存策略**：至少缓存 10 条日志，最多缓存 100 条或 2 秒未写入时自动 flush。
///   - **日志路径**：`Application Support/Logs/{BundleID}/{yyyy-MM-dd}.log`
///   - **日志格式**：NDJSON (Newline Delimited JSON)，每行一条 JSON 记录。
///
/// - Version: 1.1
///   - 修复并发竞争条件，移除不必要的 `@MainActor`
///   - 复用 `DateFormatter`，避免频繁创建
///   - 后台定时任务支持优雅取消，防止资源泄漏
///   - 新增 `flush()` 方法，支持手动强制写入
///
/// 示例：
/// ```swift
/// await LogLocalManager.shared.saveLog(message: "测试日志", file: "Test.swift", line: 42)
/// await LogLocalManager.shared.flush()     // 手动强制写入
/// await LogLocalManager.shared.shutdown()  // 应用退出时调用
/// ```
internal actor LogLocalManager {
    static let shared = LogLocalManager()
    private let logDirectory: URL
    private var logBuffer: [String] = []  // **日志缓存**
    private let minBufferedLogs = 10  // **至少 10 条日志触发写入**
    private let maxBufferedLogs = 100  // **最多缓存 100 条，超过必须写入**
    private let flushInterval: TimeInterval = 2  // **2 秒未写入，自动 flush**
    private var lastFlushTime = Date()
    
    // 修复问题 2: 复用 DateFormatter，避免重复创建
    private let iso8601Formatter = ISO8601DateFormatter()
    private let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // 修复问题 3: 添加生命周期管理，支持取消后台任务
    private var flushTask: Task<Void, Never>?

    private init() {
        let fileManager = FileManager.default
        let bundleID = Bundle.main.bundleIdentifier ?? "UnknownApp"

        #if os(iOS) || os(macOS)
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #endif

        logDirectory = directory.appendingPathComponent("Logs").appendingPathComponent(bundleID)

        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // 修复问题 3: 保存 Task 引用，以便后续可以取消
        flushTask = Task {
            await self.periodicFlush()
        }
    }
    
    /// 手动强制 flush 所有缓存日志
    /// - Note: 立即将所有缓存日志写入磁盘，不会停止后台定时任务
    func flush() async {
        if !logBuffer.isEmpty {
            await flushLogsToFile()
        }
    }
    
    /// 修复问题 3: 提供优雅关闭方法
    /// - Warning: 此方法会永久停止后台定时任务，仅在应用退出时调用
    /// - Note: 调用此方法会停止后台定时任务，并将缓存中的日志全部写入磁盘
    func shutdown() async {
        flushTask?.cancel()
        flushTask = nil
        
        // 确保剩余日志被写入
        await flush()
    }
    
    deinit {
        // 确保 actor 销毁时取消后台任务
        flushTask?.cancel()
    }

    /// **追加日志到 NDJSON 文件（使用缓存优化写入）**
    func saveLog(message: String, file: String, line: Int) async {
        let logEntry: [String: Any] = [
            "timestamp": iso8601Formatter.string(from: Date()),  // 使用复用的 formatter
            "file": (file as NSString).lastPathComponent,
            "line": line,
            "message": message
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: logEntry),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        logBuffer.append(jsonString)

        let timeSinceLastFlush = Date().timeIntervalSince(lastFlushTime)

        // **触发条件**
        if logBuffer.count >= maxBufferedLogs || timeSinceLastFlush >= flushInterval {
            await flushLogsToFile()
        }
    }

    /// **定期 Flush（保证即使日志量低，也不会丢失日志）**
    /// 修复问题 3: 支持通过 Task.isCancelled 检测并优雅退出
    private func periodicFlush() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
            
            // 再次检查任务是否被取消
            guard !Task.isCancelled else { break }
            
            let timeSinceLastFlush = Date().timeIntervalSince(lastFlushTime)

            if !logBuffer.isEmpty && timeSinceLastFlush >= flushInterval {
                await flushLogsToFile()
            }
        }
        
        // 任务取消时，确保剩余日志被写入
        if !logBuffer.isEmpty {
            await flushLogsToFile()
        }
    }

    /// **将缓存的日志写入文件**
    private func flushLogsToFile() async {
        guard !logBuffer.isEmpty else { return }

        let logFileURL = getLogFileURL()
        let logMessages = logBuffer.joined(separator: "\n") + "\n"  // **NDJSON 格式**

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                _ = try? fileHandle.seekToEnd()  // 忽略返回值，防止警告
                if let data = logMessages.data(using: .utf8) {
                    _ = try? fileHandle.write(contentsOf: data)
                }
                _ = try? fileHandle.close()
            }
        } else {
            do {
                try logMessages.write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("❌ 日志写入失败: \(error)")
            }
        }

        // **清空缓存，重置写入时间**
        logBuffer.removeAll()
        lastFlushTime = Date()
    }

    /// **获取日志文件路径（私有，仅供内部使用）**
    private func getLogFileURL() -> URL {
        let fileName = "\(fileNameFormatter.string(from: Date())).log"  // 使用复用的 formatter
        return logDirectory.appendingPathComponent(fileName)
    }

    /// **获取本地日志文件列表（供 `LogUploadManager` 使用）**
    func getLogFiles() async -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }
    }
}

extension LogLocalManager {
    
    /// 获取当前日志文件路径
    /// - Parameter date: 可选参数，默认为当前日期，支持查询特定日期的日志文件
    /// - Returns: 当前应用日志文件路径
    func getLogFilePath(for date: Date = Date()) -> URL {
        let fileManager = FileManager.default
        let logsDirectory = Self.logsDirectory

        // 确保日志目录存在
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        // 使用复用的 formatter
        let fileName = "\(fileNameFormatter.string(from: date)).log"

        return logsDirectory.appendingPathComponent(fileName)
    }

    /// 获取日志目录路径
    private static var logsDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent("Logs/\(Bundle.main.bundleIdentifier ?? "UnknownApp")")
    }
}
