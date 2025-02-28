//
//  LogLocalManager.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/28.
//

import Foundation

internal actor LogLocalManager {
    static let shared = LogLocalManager()
    private let logDirectory: URL
    private var logBuffer: [String] = []  // **日志缓存**
    private let minBufferedLogs = 10  // **至少 10 条日志触发写入**
    private let maxBufferedLogs = 100  // **最多缓存 100 条，超过必须写入**
    private let flushInterval: TimeInterval = 2  // **2 秒未写入，自动 flush**
    private var lastFlushTime = Date()

    private init() {
        let fileManager = FileManager.default
        let bundleID = Bundle.main.bundleIdentifier ?? "UnknownApp"

        #if os(iOS) || os(macOS)
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #endif

        logDirectory = directory.appendingPathComponent("Logs").appendingPathComponent(bundleID)

        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // **定时 flush**
        Task {
            await self.periodicFlush()
        }
    }

    /// **追加日志到 NDJSON 文件（使用缓存优化写入）**
    func saveLog(message: String, file: String, line: Int) async {
        let logEntry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
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
    private func periodicFlush() async {
        while true {
            try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
            let timeSinceLastFlush = Date().timeIntervalSince(lastFlushTime)

            if !logBuffer.isEmpty && timeSinceLastFlush >= flushInterval {
                await flushLogsToFile()
            }
        }
    }

    /// **将缓存的日志写入文件**
    private func flushLogsToFile() async {
        guard !logBuffer.isEmpty else { return }

        let logFileURL = getLogFileURL()
        let logMessages = logBuffer.joined(separator: "\n") + "\n"  // **NDJSON 格式**

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                _ = try? fileHandle.seekToEnd()  // ✅ 忽略返回值，防止警告
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "\(dateFormatter.string(from: Date())).log"
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

        // 格式化日期，确保日志按天存储
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "\(dateFormatter.string(from: date)).log"

        return logsDirectory.appendingPathComponent(fileName)
    }

    /// 获取日志目录路径
    private static var logsDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent("Logs/\(Bundle.main.bundleIdentifier ?? "UnknownApp")")
    }
}
