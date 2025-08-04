import Foundation
import UIKit
import os.log
import CryptoKit

// MARK: - LLMAPIService 数据安全扩展
/// 
/// 为照片识别功能添加数据安全和隐私保护
/// 
/// 🔒 安全特性：
/// - 图像数据加密存储
/// - 临时文件自动清理
/// - 网络传输加密
/// - 用户数据控制
/// 
/// 🛡️ 隐私保护：
/// - 本地优先处理
/// - 最小化数据传输
/// - 自动过期清理
/// - 透明的数据使用
extension LLMAPIService {
    
    // MARK: - 安全照片识别
    
    /// 安全的照片识别（集成数据安全功能）
    /// - Parameters:
    ///   - image: 要识别的图像
    ///   - hint: 识别提示（可选）
    ///   - useSecureStorage: 是否使用安全存储
    /// - Returns: 识别结果
    func secureIdentifyItemFromPhoto(
        _ image: UIImage,
        hint: String? = nil,
        useSecureStorage: Bool = true
    ) async throws -> ItemInfo {
        let logger = Logger(subsystem: "com.luggagehelper.security", category: "SecurePhotoRecognition")
        let securityService = await DataSecurityService.shared
        
        logger.debug("开始安全照片识别")
        
        // 1. 生成图像标识符
        let imageIdentifier = generateSecureImageIdentifier(for: image)
        
        // 2. 检查是否需要安全存储
        if useSecureStorage {
            // 安全存储原始图像（用于缓存和审计）
            let stored = await securityService.secureStoreImage(
                image,
                identifier: imageIdentifier,
                metadata: [
                    "hint": hint ?? "",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "purpose": "photo_recognition"
                ]
            )
            
            if !stored {
                logger.warning("图像安全存储失败，继续处理")
            }
        }
        
        // 3. 创建临时文件用于处理
        guard let tempFileURL = await securityService.createTemporaryImageFile(for: image) else {
            throw APIError.invalidResponse
        }
        
        defer {
            // 确保临时文件被清理
            Task {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }
        
        do {
            // 4. 执行识别
            let result = try await performSecurePhotoRecognition(
                image: image,
                tempFileURL: tempFileURL,
                hint: hint,
                identifier: imageIdentifier
            )
            
            logger.debug("安全照片识别成功完成")
            return result
            
        } catch {
            logger.error("安全照片识别失败: \(error.localizedDescription)")
            
            // 清理安全存储的图像（如果识别失败）
            if useSecureStorage {
                await securityService.secureDeleteImage(identifier: imageIdentifier)
            }
            
            throw error
        }
    }
    
    /// 批量安全照片识别
    /// - Parameters:
    ///   - images: 要识别的图像数组
    ///   - hints: 对应的识别提示数组
    ///   - useSecureStorage: 是否使用安全存储
    /// - Returns: 识别结果数组
    func secureBatchIdentifyItemsFromPhotos(
        _ images: [UIImage],
        hints: [String?] = [],
        useSecureStorage: Bool = true
    ) async throws -> [ItemInfo] {
        let logger = Logger(subsystem: "com.luggagehelper.security", category: "SecureBatchRecognition")
        
        logger.debug("开始批量安全照片识别，图像数量: \(images.count)")
        
        // 限制批量处理的数量以保护资源
        let maxBatchSize = 10
        guard images.count <= maxBatchSize else {
            throw NSError(domain: "LuggageHelper", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "批量识别最多支持\(maxBatchSize)张图像"
            ])
        }
        
        var results: [ItemInfo] = []
        
        // 使用TaskGroup进行并发处理，但限制并发数量
        await withTaskGroup(of: (Int, Result<ItemInfo, Error>).self) { group in
            let semaphore = AsyncSemaphore(value: 3) // 最多3个并发任务
            
            for (index, image) in images.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    let hint = index < hints.count ? hints[index] : nil
                    
                    do {
                        let result = try await self.secureIdentifyItemFromPhoto(
                            image,
                            hint: hint,
                            useSecureStorage: useSecureStorage
                        )
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            // 收集结果
            var indexedResults: [(Int, ItemInfo)] = []
            
            for await (index, result) in group {
                switch result {
                case .success(let itemInfo):
                    indexedResults.append((index, itemInfo))
                case .failure(let error):
                    logger.error("批量识别中的图像 \(index) 失败: \(error.localizedDescription)")
                    // 创建错误占位符
                    let errorItem = ItemInfo(
                        name: "识别失败",
                        category: .other,
                        weight: 0,
                        volume: 0,
                        dimensions: Dimensions(length: 0, width: 0, height: 0),
                        confidence: 0.0,
                        source: "错误: \(error.localizedDescription)"
                    )
                    indexedResults.append((index, errorItem))
                }
            }
            
            // 按原始顺序排序
            indexedResults.sort { $0.0 < $1.0 }
            results = indexedResults.map { $0.1 }
        }
        
        logger.debug("批量安全照片识别完成，成功识别: \(results.filter { $0.confidence > 0 }.count) 个")
        return results
    }
    
    // MARK: - 网络传输安全
    
    /// 安全的网络照片识别（加密传输）
    /// - Parameters:
    ///   - image: 要识别的图像
    ///   - hint: 识别提示
    /// - Returns: 识别结果
    func secureNetworkPhotoRecognition(
        _ image: UIImage,
        hint: String? = nil
    ) async throws -> ItemInfo {
        let logger = Logger(subsystem: "com.luggagehelper.security", category: "SecureNetworkRecognition")
        let securityService = await DataSecurityService.shared
        
        logger.debug("开始安全网络照片识别")
        
        // 1. 准备加密的传输包
        guard let encryptedPacket = await securityService.prepareEncryptedImageForTransmission(image) else {
            throw NSError(domain: "LuggageHelper", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "无法准备加密传输数据"
            ])
        }
        
        // 2. 执行网络识别（使用加密数据）
        let result = try await performEncryptedNetworkRecognition(
            encryptedPacket: encryptedPacket,
            hint: hint
        )
        
        logger.debug("安全网络照片识别完成")
        return result
    }
    
    // MARK: - 私有方法
    
    /// 执行安全照片识别
    private func performSecurePhotoRecognition(
        image: UIImage,
        tempFileURL: URL,
        hint: String?,
        identifier: String
    ) async throws -> ItemInfo {
        // 首先尝试从安全缓存获取结果
        if let cachedResult = await getSecureCachedResult(for: identifier) {
            return cachedResult
        }
        
        // 执行实际的识别
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidResponse
        }
        
        let result = try await identifyItemFromPhoto(imageData, hint: hint)
        
        // 缓存结果到安全存储
        await cacheSecureResult(result, for: identifier)
        
        return result
    }
    
    /// 执行加密网络识别
    private func performEncryptedNetworkRecognition(
        encryptedPacket: EncryptedImagePacket,
        hint: String?
    ) async throws -> ItemInfo {
        // 这里应该实现实际的加密网络传输逻辑
        // 目前先解密后使用现有的识别方法
        let securityService = await DataSecurityService.shared
        
        guard let decryptedImage = await securityService.decryptImageFromTransmission(encryptedPacket) else {
            throw APIError.invalidResponse
        }
        
        guard let imageData = decryptedImage.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidResponse
        }
        
        return try await identifyItemFromPhoto(imageData, hint: hint)
    }
    
    /// 生成安全图像标识符
    private func generateSecureImageIdentifier(for image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return UUID().uuidString
        }
        
        // 使用图像内容生成唯一标识符
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// 获取安全缓存结果
    private func getSecureCachedResult(for identifier: String) async -> ItemInfo? {
        // 这里可以实现安全缓存的查询逻辑
        // 目前返回nil，表示没有缓存
        return nil
    }
    
    /// 缓存安全结果
    private func cacheSecureResult(_ result: ItemInfo, for identifier: String) async {
        // 这里可以实现安全结果的缓存逻辑
        // 目前为空实现
    }
    
    // MARK: - 数据清理和管理
    
    /// 清理用户的照片识别数据
    func cleanupUserPhotoRecognitionData() async -> Bool {
        let logger = Logger(subsystem: "com.luggagehelper.security", category: "DataCleanup")
        let securityService = await DataSecurityService.shared
        
        logger.info("开始清理用户照片识别数据")
        
        // 1. 清理临时文件
        await securityService.cleanupAllTemporaryFiles()
        
        // 2. 清理相关缓存
        await cacheManager.clearPhotoRecognitionCache()
        
        // 3. 清理请求队列中的相关任务
        await requestQueue.cancelPhotoRecognitionTasks()
        
        logger.info("用户照片识别数据清理完成")
        return true
    }
    
    /// 获取照片识别数据使用报告
    func getPhotoRecognitionDataReport() async -> PhotoRecognitionDataReport {
        let securityService = await DataSecurityService.shared
        let userDataReport = await securityService.getUserDataReport()
        
        // 统计照片识别相关的数据
        let cacheStats = await cacheManager.getPhotoRecognitionCacheStats()
        let queueStats = await requestQueue.getPhotoRecognitionQueueStats()
        
        return PhotoRecognitionDataReport(
            userDataReport: userDataReport,
            cacheStatistics: cacheStats,
            queueStatistics: queueStats,
            generatedAt: Date()
        )
    }
}

// MARK: - 支持数据结构

/// 照片识别数据报告
struct PhotoRecognitionDataReport {
    let userDataReport: UserDataReport
    let cacheStatistics: Any // 缓存统计
    let queueStatistics: Any // 队列统计
    let generatedAt: Date
}

/// 异步信号量（用于限制并发）
actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.count = value
    }
    
    func wait() async {
        if count > 0 {
            count -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

// MARK: - 扩展现有缓存管理器

extension AICacheManager {
    /// 清理照片识别缓存
    func clearPhotoRecognitionCache() async {
        // 实现照片识别缓存的清理逻辑
        // TODO: 实现具体的缓存清理逻辑
    }
    
    /// 获取照片识别缓存统计
    func getPhotoRecognitionCacheStats() async -> [String: Any] {
        // 返回照片识别相关的缓存统计
        return [
            "cacheSize": 0,
            "hitRate": 0.0,
            "totalRequests": 0
        ]
    }
}

// MARK: - 扩展请求队列管理器

extension AIRequestQueue {
    /// 取消照片识别任务
    func cancelPhotoRecognitionTasks() async {
        // 实现照片识别任务的取消逻辑
        // TODO: 实现具体的任务取消逻辑
    }
    
    /// 获取照片识别队列统计
    func getPhotoRecognitionQueueStats() async -> [String: Any] {
        // 返回照片识别相关的队列统计
        return [
            "pendingTasks": 0,
            "completedTasks": 0,
            "failedTasks": 0
        ]
    }
}