import Foundation
import UIKit
import CryptoKit
import os.log

// MARK: - 照片识别缓存管理器
/// 
/// 专门为照片识别功能设计的智能缓存系统
/// 
/// 🎯 核心特性：
/// - 相似度匹配：基于图像内容的智能缓存匹配
/// - 多级存储：内存缓存 + 磁盘缓存 + 相似度索引
/// - 智能清理：基于使用频率和相似度的清理策略
/// - 性能优化：并行处理和预计算优化
/// 
/// 📊 缓存策略：
/// - 精确匹配：相同图片哈希直接命中
/// - 相似匹配：相似度>0.8的图片复用结果
/// - 渐进式缓存：从粗糙到精细的多级匹配
/// - 智能过期：基于识别准确度的动态过期时间
/// 
/// ⚡ 性能指标：
/// - 缓存命中率目标：>70%
/// - 相似度计算时间：<200ms
/// - 内存使用限制：<100MB
/// - 磁盘缓存大小：<500MB
@MainActor
class PhotoRecognitionCacheManager: ObservableObject {
    
    // MARK: - Dependencies
    private let imageHasher: ImageHasher
    private let similarityMatcher: ImageSimilarityMatcher
    private let cacheStorage: PhotoCacheStorage
    
    // MARK: - Configuration
    private let maxMemoryCacheSize: Int = 50 // 最大内存缓存数量
    private let maxDiskCacheSize: Int = 100 * 1024 * 1024 // 100MB磁盘缓存
    private let similarityThreshold: Double = 0.8 // 相似度阈值
    private let defaultCacheExpiry: TimeInterval = 7 * 24 * 60 * 60 // 7天
    
    // MARK: - Cache Storage
    private var memoryCache: [String: PhotoRecognitionResult] = [:]
    private var similarityIndex: [String: [String]] = [:] // hash -> similar hashes
    private var accessCount: [String: Int] = [:]
    private var lastAccess: [String: Date] = [:]
    
    // MARK: - Statistics
    @Published var cacheHitRate: Double = 0.0
    @Published var totalCacheSize: Int = 0
    @Published var similarityMatchCount: Int = 0
    
    // MARK: - Dependencies
    private let dataSecurityService = DataSecurityService.shared
    private let logger = Logger(subsystem: "com.luggagehelper.cache", category: "PhotoRecognitionCache")
    
    // MARK: - Initialization
    
    init() {
        self.imageHasher = ImageHasher()
        self.similarityMatcher = ImageSimilarityMatcher()
        self.cacheStorage = PhotoCacheStorage()
        
        // 启动时加载缓存统计
        Task {
            await loadCacheStatistics()
            await schedulePeriodicMaintenance()
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取缓存的识别结果
    /// - Parameter image: 输入图像
    /// - Returns: 缓存的识别结果，如果没有则返回nil
    func getCachedResult(for image: UIImage) async -> PhotoRecognitionResult? {
        let imageHash = await imageHasher.generateHash(for: image)
        
        // 1. 尝试精确匹配
        if let exactResult = await getExactMatch(for: imageHash) {
            await recordCacheHit(hash: imageHash, type: .exact)
            return exactResult
        }
        
        // 2. 尝试相似度匹配
        if let similarResult = await getSimilarMatch(for: image, hash: imageHash) {
            await recordCacheHit(hash: imageHash, type: .similar)
            return similarResult
        }
        
        await recordCacheMiss(hash: imageHash)
        return nil
    }
    
    /// 缓存识别结果（集成数据安全）
    /// - Parameters:
    ///   - image: 输入图像
    ///   - result: 识别结果
    func cacheResult(for image: UIImage, result: PhotoRecognitionResult) async {
        let imageHash = await imageHasher.generateHash(for: image)
        
        // 创建增强的缓存条目
        let enhancedResult = await createEnhancedResult(result, for: image, hash: imageHash)
        
        // 安全存储原始图像（如果需要）
        let secureStored = await dataSecurityService.secureStoreImage(
            image,
            identifier: "cache-\(imageHash)",
            metadata: [
                "purpose": "photo_recognition_cache",
                "confidence": "\(result.confidence)",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
        
        if !secureStored {
            logger.warning("图像安全存储失败，继续缓存处理")
        }
        
        // 存储到内存缓存
        await storeInMemoryCache(hash: imageHash, result: enhancedResult)
        
        // 存储到磁盘缓存
        await cacheStorage.store(result: enhancedResult, for: imageHash)
        
        // 更新相似度索引
        await updateSimilarityIndex(for: image, hash: imageHash)
        
        // 检查缓存大小并清理
        await cleanupIfNeeded()
    }
    
    /// 查找相似的缓存结果
    /// - Parameters:
    ///   - image: 目标图像
    ///   - threshold: 相似度阈值
    /// - Returns: 相似的缓存结果数组
    func findSimilarCachedResults(for image: UIImage, threshold: Double = 0.7) async -> [PhotoRecognitionResult] {
        let cachedImages = await getAllCachedImages()
        let similarImages = await similarityMatcher.findSimilarImages(
            to: image,
            in: cachedImages,
            threshold: threshold
        )
        
        var results: [PhotoRecognitionResult] = []
        for similarImage in similarImages {
            if let result = await getCachedResult(for: similarImage.image) {
                results.append(result)
            }
        }
        
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    /// 使缓存失效（集成安全删除）
    /// - Parameter imageHash: 图像哈希
    func invalidateCache(for imageHash: String) async {
        // 安全删除存储的图像
        await dataSecurityService.secureDeleteImage(identifier: "cache-\(imageHash)")
        
        // 从内存缓存中移除
        memoryCache.removeValue(forKey: imageHash)
        
        // 从磁盘缓存中移除
        await cacheStorage.remove(for: imageHash)
        
        // 清理相似度索引
        await cleanupSimilarityIndex(for: imageHash)
        
        // 清理访问记录
        accessCount.removeValue(forKey: imageHash)
        lastAccess.removeValue(forKey: imageHash)
    }
    
    /// 清理过期缓存
    func cleanupExpiredCache() async {
        let now = Date()
        var expiredHashes: [String] = []
        
        // 检查内存缓存
        for (hash, result) in memoryCache {
            if let expiryDate = result.cacheExpiryDate, expiryDate < now {
                expiredHashes.append(hash)
            }
        }
        
        // 清理过期项
        for hash in expiredHashes {
            await invalidateCache(for: hash)
        }
        
        // 清理磁盘缓存中的过期项
        await cacheStorage.cleanupExpired()
        
        await updateCacheStatistics()
    }
    
    /// 获取缓存统计信息
    func getCacheStatistics() async -> PhotoCacheStatistics {
        let memorySize = memoryCache.count
        let diskSize = await cacheStorage.getTotalSize()
        let totalHits = accessCount.values.reduce(0, +)
        let similarityMatches = similarityMatchCount
        
        return PhotoCacheStatistics(
            memoryEntries: memorySize,
            diskSize: diskSize,
            totalHits: totalHits,
            cacheHitRate: cacheHitRate,
            similarityMatches: similarityMatches,
            averageResponseTime: await calculateAverageResponseTime()
        )
    }
    
    /// 清空所有缓存（集成安全清理）
    func clearAllCache() async {
        // 安全删除所有缓存相关的图像
        for imageHash in memoryCache.keys {
            await dataSecurityService.secureDeleteImage(identifier: "cache-\(imageHash)")
        }
        
        memoryCache.removeAll()
        similarityIndex.removeAll()
        accessCount.removeAll()
        lastAccess.removeAll()
        
        await cacheStorage.clearAll()
        await updateCacheStatistics()
    }
    
    // MARK: - Private Methods
    
    /// 获取精确匹配的结果
    private func getExactMatch(for hash: String) async -> PhotoRecognitionResult? {
        // 先检查内存缓存
        if let memoryResult = memoryCache[hash] {
            await updateAccessRecord(for: hash)
            return memoryResult
        }
        
        // 检查磁盘缓存
        if let diskResult = await cacheStorage.load(for: hash) {
            // 加载到内存缓存
            await storeInMemoryCache(hash: hash, result: diskResult)
            await updateAccessRecord(for: hash)
            return diskResult
        }
        
        return nil
    }
    
    /// 获取相似匹配的结果
    private func getSimilarMatch(for image: UIImage, hash: String) async -> PhotoRecognitionResult? {
        // 检查相似度索引
        let similarHashes = await findSimilarHashes(for: hash)
        
        for similarHash in similarHashes {
            if let result = await getExactMatch(for: similarHash) {
                // 验证相似度
                if let cachedImage = await cacheStorage.loadImage(for: similarHash) {
                    let similarity = await similarityMatcher.calculateSimilarity(
                        between: image,
                        and: cachedImage
                    )
                    
                    if similarity >= similarityThreshold {
                        // 创建基于相似度的结果副本
                        let adjustedResult = await createSimilarityAdjustedResult(
                            result,
                            similarity: similarity,
                            originalHash: similarHash,
                            newHash: hash
                        )
                        
                        // 缓存调整后的结果
                        await storeInMemoryCache(hash: hash, result: adjustedResult)
                        
                        return adjustedResult
                    }
                }
            }
        }
        
        // 如果索引中没有找到，尝试直接搜索所有缓存图像
        let allCachedImages = await cacheStorage.getAllCachedImages()
        let similarImages = await similarityMatcher.findSimilarImages(
            to: image,
            in: allCachedImages,
            threshold: similarityThreshold
        )
        
        if let mostSimilar = similarImages.first {
            if let result = await getExactMatch(for: mostSimilar.hash) {
                let adjustedResult = await createSimilarityAdjustedResult(
                    result,
                    similarity: mostSimilar.similarity,
                    originalHash: mostSimilar.hash,
                    newHash: hash
                )
                
                // 更新相似度索引
                await updateSimilarityIndexEntry(originalHash: mostSimilar.hash, newHash: hash)
                
                // 缓存调整后的结果
                await storeInMemoryCache(hash: hash, result: adjustedResult)
                
                return adjustedResult
            }
        }
        
        return nil
    }
    
    /// 创建增强的识别结果
    private func createEnhancedResult(
        _ result: PhotoRecognitionResult,
        for image: UIImage,
        hash: String
    ) async -> PhotoRecognitionResult {
        let imageMetadata = await extractImageMetadata(from: image)
        let cacheExpiryDate = calculateExpiryDate(for: result)
        
        var enhancedResult = PhotoRecognitionResult(
            itemInfo: result.itemInfo,
            confidence: result.confidence,
            recognitionMethod: result.recognitionMethod,
            processingTime: result.processingTime,
            imageMetadata: imageMetadata,
            alternatives: result.alternatives,
            qualityScore: result.qualityScore
        )
        
        // 设置缓存相关属性
        enhancedResult.cacheExpiryDate = cacheExpiryDate
        enhancedResult.userFeedback = result.userFeedback
        enhancedResult.isVerified = result.isVerified
        enhancedResult.correctedInfo = result.correctedInfo
        
        return enhancedResult
    }
    
    /// 创建基于相似度调整的结果
    private func createSimilarityAdjustedResult(
        _ originalResult: PhotoRecognitionResult,
        similarity: Double,
        originalHash: String,
        newHash: String
    ) async -> PhotoRecognitionResult {
        // 根据相似度调整置信度
        let adjustedConfidence = originalResult.confidence * similarity
        
        var result = PhotoRecognitionResult(
            itemInfo: originalResult.itemInfo,
            confidence: adjustedConfidence,
            recognitionMethod: originalResult.recognitionMethod,
            processingTime: 0.1,
            imageMetadata: originalResult.imageMetadata,
            alternatives: originalResult.alternatives,
            qualityScore: originalResult.qualityScore
        )
        
        // 设置缓存相关属性
        result.cacheExpiryDate = originalResult.cacheExpiryDate
        result.userFeedback = nil
        result.isVerified = false
        result.correctedInfo = nil
        
        return result
    }
    
    /// 存储到内存缓存
    private func storeInMemoryCache(hash: String, result: PhotoRecognitionResult) async {
        memoryCache[hash] = result
        
        // 检查内存缓存大小
        if memoryCache.count > maxMemoryCacheSize {
            await evictLeastRecentlyUsed()
        }
    }
    
    /// 更新相似度索引
    private func updateSimilarityIndex(for image: UIImage, hash: String) async {
        let cachedImages = await getAllCachedImages()
        
        // 找到相似的图片
        let similarImages = await similarityMatcher.findSimilarImages(
            to: image,
            in: cachedImages,
            threshold: similarityThreshold
        )
        
        // 更新双向索引
        var similarHashes: [String] = []
        for similarImage in similarImages {
            let similarHash = similarImage.hash
            similarHashes.append(similarHash)
            
            // 更新反向索引
            if similarityIndex[similarHash] == nil {
                similarityIndex[similarHash] = []
            }
            if !similarityIndex[similarHash]!.contains(hash) {
                similarityIndex[similarHash]!.append(hash)
            }
        }
        
        similarityIndex[hash] = similarHashes
    }
    
    /// 查找相似的哈希值
    private func findSimilarHashes(for hash: String) async -> [String] {
        return similarityIndex[hash] ?? []
    }
    
    /// 更新相似度索引条目
    private func updateSimilarityIndexEntry(originalHash: String, newHash: String) async {
        // 将新哈希添加到原始哈希的相似列表中
        if similarityIndex[originalHash] == nil {
            similarityIndex[originalHash] = []
        }
        if !similarityIndex[originalHash]!.contains(newHash) {
            similarityIndex[originalHash]!.append(newHash)
        }
        
        // 将原始哈希添加到新哈希的相似列表中
        if similarityIndex[newHash] == nil {
            similarityIndex[newHash] = []
        }
        if !similarityIndex[newHash]!.contains(originalHash) {
            similarityIndex[newHash]!.append(originalHash)
        }
    }
    
    /// 清理相似度索引
    private func cleanupSimilarityIndex(for hash: String) async {
        // 移除该哈希的索引
        let similarHashes = similarityIndex[hash] ?? []
        similarityIndex.removeValue(forKey: hash)
        
        // 从其他哈希的索引中移除该哈希
        for similarHash in similarHashes {
            if var hashes = similarityIndex[similarHash] {
                hashes.removeAll { $0 == hash }
                if hashes.isEmpty {
                    similarityIndex.removeValue(forKey: similarHash)
                } else {
                    similarityIndex[similarHash] = hashes
                }
            }
        }
    }
    
    /// 驱逐最近最少使用的缓存项
    private func evictLeastRecentlyUsed() async {
        guard !lastAccess.isEmpty else { return }
        
        // 找到最久未访问的项
        let lruHash = lastAccess.min { $0.value < $1.value }?.key
        
        if let hashToEvict = lruHash {
            memoryCache.removeValue(forKey: hashToEvict)
            accessCount.removeValue(forKey: hashToEvict)
            lastAccess.removeValue(forKey: hashToEvict)
        }
    }
    
    /// 检查并清理缓存
    private func cleanupIfNeeded() async {
        let currentSize = await cacheStorage.getTotalSize()
        
        if currentSize > maxDiskCacheSize {
            await performIntelligentCleanup()
        }
    }
    
    /// 执行智能清理
    private func performIntelligentCleanup() async {
        // 获取所有缓存项的使用统计
        let allHashes = Array(accessCount.keys)
        
        // 按使用频率和最后访问时间排序
        let sortedHashes = allHashes.sorted { hash1, hash2 in
            let count1 = accessCount[hash1] ?? 0
            let count2 = accessCount[hash2] ?? 0
            let access1 = lastAccess[hash1] ?? Date.distantPast
            let access2 = lastAccess[hash2] ?? Date.distantPast
            
            // 优先清理使用频率低且访问时间久的项
            if count1 != count2 {
                return count1 < count2
            }
            return access1 < access2
        }
        
        // 清理前30%的项
        let itemsToRemove = Int(Double(sortedHashes.count) * 0.3)
        for i in 0..<min(itemsToRemove, sortedHashes.count) {
            await invalidateCache(for: sortedHashes[i])
        }
    }
    
    /// 更新访问记录
    private func updateAccessRecord(for hash: String) async {
        accessCount[hash, default: 0] += 1
        lastAccess[hash] = Date()
    }
    
    /// 记录缓存命中
    private func recordCacheHit(hash: String, type: CacheHitType) async {
        await updateAccessRecord(for: hash)
        
        if type == .similar {
            similarityMatchCount += 1
        }
        
        await updateCacheStatistics()
    }
    
    /// 记录缓存未命中
    private func recordCacheMiss(hash: String) async {
        await updateCacheStatistics()
    }
    
    /// 更新缓存统计
    private func updateCacheStatistics() async {
        let totalRequests = accessCount.values.reduce(0, +)
        let totalHits = memoryCache.count + similarityMatchCount
        
        if totalRequests > 0 {
            cacheHitRate = Double(totalHits) / Double(totalRequests)
        }
        
        let entryCount = await cacheStorage.getEntryCount()
        totalCacheSize = memoryCache.count + entryCount
    }
    
    /// 加载缓存统计
    private func loadCacheStatistics() async {
        await updateCacheStatistics()
    }
    
    /// 计算过期时间
    private func calculateExpiryDate(for result: PhotoRecognitionResult) -> Date {
        // 根据识别置信度调整过期时间
        let baseExpiry = defaultCacheExpiry
        let confidenceMultiplier = result.confidence // 0.0 - 1.0
        let adjustedExpiry = baseExpiry * Double(confidenceMultiplier)
        
        return Date().addingTimeInterval(max(adjustedExpiry, 24 * 60 * 60)) // 最少1天
    }
    
    /// 提取图像元数据
    private func extractImageMetadata(from image: UIImage) async -> LuggageHelper.ImageMetadata {
        let size = image.size
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        
        return LuggageHelper.ImageMetadata(
            width: Int(size.width),
            height: Int(size.height),
            fileSize: imageData.count,
            format: "JPEG",
            dominantColors: await extractDominantColors(from: image),
            brightness: await calculateBrightness(from: image),
            contrast: await calculateContrast(from: image),
            hasText: false,
            estimatedObjects: 1
        )
    }
    
    /// 提取主要颜色
    private func extractDominantColors(from image: UIImage) async -> [String] {
        // 简化实现：返回固定颜色
        return ["#FFFFFF", "#000000", "#808080"]
    }
    
    /// 计算亮度
    private func calculateBrightness(from image: UIImage) async -> Double {
        // 简化实现：返回固定值
        return 0.5
    }
    
    /// 计算对比度
    private func calculateContrast(from image: UIImage) async -> Double {
        // 简化实现：返回固定值
        return 0.5
    }
    
    /// 获取所有缓存的图像
    private func getAllCachedImages() async -> [CachedImage] {
        return await cacheStorage.getAllCachedImages()
    }
    
    /// 计算平均响应时间
    private func calculateAverageResponseTime() async -> Double {
        // 简化实现：返回估算值
        return 0.15 // 150ms
    }
    
    /// 预热缓存
    /// - Parameter images: 要预热的图像数组
    func preloadCache(for images: [UIImage]) async {
        let imageHashes = await withTaskGroup(of: String.self) { group in
            var hashes: [String] = []
            
            for image in images {
                group.addTask {
                    return await self.imageHasher.generateHash(for: image)
                }
            }
            
            for await hash in group {
                hashes.append(hash)
            }
            
            return hashes
        }
        
        // 批量加载缓存结果
        let cachedResults = await cacheStorage.batchLoad(for: imageHashes)
        
        // 将结果加载到内存缓存
        for (hash, result) in cachedResults {
            await storeInMemoryCache(hash: hash, result: result)
        }
        
        print("Preloaded \(cachedResults.count) cache entries into memory")
    }
    
    /// 优化相似度索引
    func optimizeSimilarityIndex() async {
        let allHashes = Array(similarityIndex.keys)
        var optimizedIndex: [String: [String]] = [:]
        
        // 重新计算所有相似度关系
        await withTaskGroup(of: (String, [String]).self) { group in
            for hash in allHashes {
                group.addTask {
                    let similarHashes = await self.findSimilarHashesForOptimization(hash: hash)
                    return (hash, similarHashes)
                }
            }
            
            for await (hash, similarHashes) in group {
                optimizedIndex[hash] = similarHashes
            }
        }
        
        similarityIndex = optimizedIndex
        print("Optimized similarity index for \(optimizedIndex.count) entries")
    }
    
    /// 为优化查找相似哈希
    private func findSimilarHashesForOptimization(hash: String) async -> [String] {
        // 这里可以实现更复杂的相似度计算逻辑
        // 目前返回现有的相似哈希
        return similarityIndex[hash] ?? []
    }
    
    /// 定期维护
    private func schedulePeriodicMaintenance() async {
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in // 每小时
            Task {
                await self.cleanupExpiredCache()
                await self.cleanupIfNeeded()
                
                // 每6小时优化一次相似度索引
                let hour = Calendar.current.component(.hour, from: Date())
                if hour % 6 == 0 {
                    await self.optimizeSimilarityIndex()
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum CacheHitType {
    case exact
    case similar
}

/// 照片缓存统计
struct PhotoCacheStatistics {
    let memoryEntries: Int
    let diskSize: Int
    let totalHits: Int
    let cacheHitRate: Double
    let similarityMatches: Int
    let averageResponseTime: Double
    
    var formattedDiskSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(diskSize), countStyle: .file)
    }
    
    var formattedHitRate: String {
        return String(format: "%.1f%%", cacheHitRate * 100)
    }
}

// 移除这个扩展，因为属性已经在AIModels.swift中定义了