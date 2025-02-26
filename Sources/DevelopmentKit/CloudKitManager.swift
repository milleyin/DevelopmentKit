//
//  CloudKitManager.swift
//  DevelopmentKit
//
//  Created by Mille Yin on 2025/2/26.
//

import Foundation
import CloudKit

@MainActor
internal class CloudKitManager {
    
    private static let container = CKContainer.default()
    private static let database = container.privateCloudDatabase

    /// 需要隔离的状态变量，防止并发冲突
    private static var isCloudEnabled: Bool = false
    private static var hasCheckedCloudStatus = false

    /// 检查 iCloud 可用性（只检查一次）
    internal static func checkCloudKitAvailability() async {
        guard !hasCheckedCloudStatus else { return }

        do {
            let status = try await container.accountStatus()
            isCloudEnabled = (status == .available)
            hasCheckedCloudStatus = true
            print(isCloudEnabled ? "✅ CloudKit logging is enabled." : "⚠️ CloudKit is not available.")
        } catch {
            print("❌ CloudKit error: \(error.localizedDescription)")
        }
    }

    /// 存储日志到 CloudKit（如果可用，使用 async/await）
    internal static func saveLogToCloud(_ message: String, file: String, line: Int) {
        Task { @MainActor in
            await checkCloudKitAvailability()  // 确保状态检查在主线程执行
            
            guard isCloudEnabled else {
                print("⚠️ CloudKit is disabled. Skipping log storage.")
                return
            }

            let fileName = (file as NSString).lastPathComponent
            let timestamp = Date()

            let record = CKRecord(recordType: "LogRecords")
            record["timestamp"] = timestamp as CKRecordValue
            record["file"] = fileName as CKRecordValue
            record["line"] = line as CKRecordValue
            record["message"] = message as CKRecordValue

            await saveWithRetry(record: record, maxRetries: 3, initialDelay: 1.0)
        }
    }

    /// 带重试机制的 CloudKit 存储方法
    private static func saveWithRetry(record: CKRecord, maxRetries: Int, initialDelay: Double) async {
        var attempt = 0
        var delay = initialDelay

        while attempt < maxRetries {
            do {
                let _ = try await database.save(record)
                print("✅ Log successfully saved to CloudKit.")
                return
            } catch {
                print("❌ Failed to save log (Attempt \(attempt + 1)): \(error.localizedDescription)")
                attempt += 1
                if attempt < maxRetries {
                    let sleepTime = delay * pow(2.0, Double(attempt))  // 指数退避
                    print("⏳ Retrying in \(sleepTime) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                }
            }
        }

        print("❌ Failed to save log after \(maxRetries) attempts. Giving up.")
    }
}
