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
    
    /// 获取 CloudKit 容器，防止因未注册容器崩溃
    private static func createContainer(identifier: String?) -> CKContainer? {
        // ✅ 如果 `identifier` 为空或无效，直接返回 `nil`
        guard let identifier = identifier, !identifier.isEmpty else {
            print("❌ CloudKit container identifier is nil or empty!")
            return nil
        }
        
        // ✅ 防止 `CKContainer(identifier:)` 直接崩溃
        let container = CKContainer(identifier: identifier)
        if (container.containerIdentifier ?? "").isEmpty {
            print("❌ CloudKit container is misconfigured! Ensure iCloud is enabled in Xcode and the correct container is set.")
            return nil
        }
        
        return container
    }

    /// 初始化 CloudKit 容器
    private static let container: CKContainer? = createContainer(identifier: "iCloud.com.yourcompany.ABC") // ✅ 可动态传入

    /// 仅在 `container` 有效时才初始化 `database`
    private static var database: CKDatabase? {
        return container?.privateCloudDatabase
    }
    
    /// 检查 iCloud 可用性，如果 `CKContainer` 为空则抛出错误
    internal static func checkCloudKitAvailability() async throws {
        guard let container = container else {
            print("❌ CloudKit is unavailable! Ensure iCloud is enabled.")
            throw CloudKitError.containerNotConfigured
        }
        
        do {
            let status = try await container.accountStatus()
            if status != .available {
                print("⚠️ CloudKit is not available. Please enable iCloud in Xcode settings.")
                throw CloudKitError.containerNotConfigured
            }
            print("✅ CloudKit logging is enabled.")
        } catch {
            print("❌ CloudKit error: \(error.localizedDescription)")
            throw error
        }
    }

    /// 存储日志到 CloudKit（如果可用，使用 async/await）
    internal static func saveLogToCloud(_ message: String, file: String, line: Int) async throws {
        guard let _ = database else {
            print("❌ CloudKit database is nil! Ensure iCloud is enabled and correctly configured.")
            throw CloudKitError.containerNotConfigured
        }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date()
        
        let record = CKRecord(recordType: "LogRecords")
        record["timestamp"] = timestamp as CKRecordValue
        record["file"] = fileName as CKRecordValue
        record["line"] = line as CKRecordValue
        record["message"] = message as CKRecordValue
        
        try await saveWithRetry(record: record, maxRetries: 3, initialDelay: 1.0)
    }

    /// 带重试机制的 CloudKit 存储方法
    private static func saveWithRetry(record: CKRecord, maxRetries: Int, initialDelay: Double) async throws {
        guard let database = database else {
            print("❌ CloudKit database is nil! Cannot save log.")
            throw CloudKitError.containerNotConfigured
        }
        
        var attempt = 0
        let delay = initialDelay

        while attempt < maxRetries {
            do {
                let _ = try await database.save(record)
                print("✅ Log successfully saved to CloudKit.")
                return
            } catch let ckError as CKError {
                print("❌ CloudKit save error (Attempt \(attempt + 1)): \(ckError.localizedDescription)")
                if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                    print("⚠️ Network issue detected, will retry.")
                } else if ckError.code == .quotaExceeded {
                    print("❌ CloudKit quota exceeded, cannot save log.")
                    throw ckError
                } else if ckError.code == .notAuthenticated {
                    print("⚠️ CloudKit user not authenticated, please log in to iCloud.")
                    throw ckError
                } else {
                    print("⚠️ Unknown CloudKit error, retrying...")
                }
                attempt += 1
                if attempt < maxRetries {
                    let sleepTime = delay * pow(2.0, Double(attempt))
                    print("⏳ Retrying in \(sleepTime) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                }
            } catch {
                print("❌ Unknown error occurred: \(error.localizedDescription)")
                throw error
            }
        }

        print("❌ Failed to save log after \(maxRetries) attempts. Giving up.")
        throw CloudKitError.containerNotConfigured
    }
}

enum CloudKitError: Error {
    case containerNotConfigured
}
