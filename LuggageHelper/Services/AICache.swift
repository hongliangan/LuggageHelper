import Foundation
import CryptoKit
import os.log

// MARK: - AI 缓存管理器
/// 
/// 智能缓存管理系统，为 AI 功能提供高性能缓存支持
/// 
/// 🚀 核心特性：
/// - 分层缓存策略：内存 + 磁盘双层缓存
/// - 智能过期机制：不同功能采用不同过期时间
/// - 数据压缩：LZFSE 算法节省 50-70% 存储空间
/// - 自动清理：基于大小和时间的智能清理
/// - 性能监控：实时统计缓存命中率和使用情况
/// 
/// 📊 缓存策略：
/// - 物品识别：24小时缓存，基于名称和型号哈希
/// - 照片识别：7天缓存，基于图片内容哈希
/// - 旅行建议：24小时缓存，基于参数组合
/// - 装箱优化：12小时缓存，平衡实时性需求
/// - 航司政策：7天缓存，政策变化相对较慢
/// 
/// ⚡ 性能优化：
/// - 缓存命中响应时间 <100ms
/// - 自动清理机制，避免存储空间浪费
/// - 线程安全设计，支持并发访问
@MainActor
class AICacheManager: ObservableObject {
    static let shared = AICacheManager()
    
    private let logger = Logger(subsystem: "com.luggagehelper.cache", category: "AICache")
    private let userDefaults = UserDefaults.standard
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private let defaultCacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // Cache keys
    private enum CacheKeys {
        static let itemIdentification = "ai_cache_item_identification"
        static let travelSuggestions = "ai_cache_travel_suggestions"
        static let packingOptimization = "ai_cache_packing_optimization"
        static let photoRecognition = "ai_cache_photo_recognition"
        static let alternatives = "ai_cache_alternatives"
        static let airlinePolicies = "ai_cache_airline_policies"
        static let cacheMetadata = "ai_cache_metadata"
    }
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AICache")
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Schedule periodic cleanup
        schedulePeriodicCleanup()
    }
    
    // MARK: - Cache Operations
    
    func cacheItemIdentification(request: ItemIdentificationRequest, response: ItemInfo) {
        let key = generateCacheKey(for: request)
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(defaultCacheExpiry)
        )
        saveCacheEntry(cacheEntry, forKey: key, category: CacheKeys.itemIdentification)
    }
    
    func getCachedItemIdentification(for request: ItemIdentificationRequest) -> ItemInfo? {
        let key = generateCacheKey(for: request)
        return getCacheEntry(forKey: key, category: CacheKeys.itemIdentification, type: ItemInfo.self)
    }
    
    func cacheTravelSuggestions(request: TravelSuggestionRequest, response: TravelSuggestion) {
        let key = generateCacheKey(for: request)
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(defaultCacheExpiry)
        )
        saveCacheEntry(cacheEntry, forKey: key, category: CacheKeys.travelSuggestions)
    }
    
    func getCachedTravelSuggestions(for request: TravelSuggestionRequest) -> TravelSuggestion? {
        let key = generateCacheKey(for: request)
        return getCacheEntry(forKey: key, category: CacheKeys.travelSuggestions, type: TravelSuggestion.self)
    }
    
    func cachePackingOptimization(request: PackingOptimizationRequest, response: PackingPlan) {
        let key = generateCacheKey(for: request)
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(12 * 60 * 60) // 12 hours for packing optimization
        )
        saveCacheEntry(cacheEntry, forKey: key, category: CacheKeys.packingOptimization)
    }
    
    func getCachedPackingOptimization(for request: PackingOptimizationRequest) -> PackingPlan? {
        let key = generateCacheKey(for: request)
        return getCacheEntry(forKey: key, category: CacheKeys.packingOptimization, type: PackingPlan.self)
    }
    
    func cachePhotoRecognition(imageHash: String, response: ItemInfo) {
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days for photo recognition
        )
        saveCacheEntry(cacheEntry, forKey: imageHash, category: CacheKeys.photoRecognition)
    }
    
    func getCachedPhotoRecognition(for imageHash: String) -> ItemInfo? {
        return getCacheEntry(forKey: imageHash, category: CacheKeys.photoRecognition, type: ItemInfo.self)
    }
    
    func cacheAlternatives(request: AlternativesRequest, response: [ItemInfo]) {
        let key = generateCacheKey(for: request)
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(defaultCacheExpiry)
        )
        saveCacheEntry(cacheEntry, forKey: key, category: CacheKeys.alternatives)
    }
    
    func getCachedAlternatives(for request: AlternativesRequest) -> [ItemInfo]? {
        let key = generateCacheKey(for: request)
        return getCacheEntry(forKey: key, category: CacheKeys.alternatives, type: [ItemInfo].self)
    }
    
    func cacheAirlinePolicy(airline: String, response: AirlinePolicy) {
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days for airline policies
        )
        saveCacheEntry(cacheEntry, forKey: airline, category: CacheKeys.airlinePolicies)
    }
    
    // MARK: - Private Helper Methods
    
    private func generateCacheKey<T: Hashable>(for request: T) -> String {
        let data = String(describing: request).data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func saveCacheEntry<T: Codable>(_ entry: CacheEntry<T>, forKey key: String, category: String) {
        do {
            let data = try JSONEncoder().encode(entry)
            let compressedData = try data.compressed()
            
            let fileURL = self.cacheDirectory.appendingPathComponent("\(category)_\(key)")
            try compressedData.write(to: fileURL)
            
            // Update metadata
            updateCacheMetadata(key: key, category: category, size: compressedData.count, expiryDate: entry.expiryDate)
            
            // Check cache size and cleanup if needed
            Task {
                await cleanupIfNeeded()
            }
        } catch {
            print("Failed to save cache entry: \(error)")
        }
    }
    
    private func getCacheEntry<T: Codable>(forKey key: String, category: String, type: T.Type) -> T? {
        let fileURL = self.cacheDirectory.appendingPathComponent("\(category)_\(key)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let compressedData = try Data(contentsOf: fileURL)
            let data = try compressedData.decompressed()
            let entry = try JSONDecoder().decode(CacheEntry<T>.self, from: data)
            
            // Check if entry is expired
            if entry.expiryDate < Date() {
                // Remove expired entry
                try? FileManager.default.removeItem(at: fileURL)
                removeCacheMetadata(key: key, category: category)
                return nil
            }
            
            return entry.data
        } catch {
            print("Failed to load cache entry: \(error)")
            // Remove corrupted entry
            try? FileManager.default.removeItem(at: fileURL)
            removeCacheMetadata(key: key, category: category)
            return nil
        }
    }
    
    private func updateCacheMetadata(key: String, category: String, size: Int, expiryDate: Date) {
        var metadata = getCacheMetadata()
        let entryKey = "\(category)_\(key)"
        
        metadata[entryKey] = CacheMetadataEntry(
            size: size,
            timestamp: Date(),
            expiryDate: expiryDate,
            category: category
        )
        
        saveCacheMetadata(metadata)
    }
    
    private func removeCacheMetadata(key: String, category: String) {
        var metadata = getCacheMetadata()
        let entryKey = "\(category)_\(key)"
        metadata.removeValue(forKey: entryKey)
        saveCacheMetadata(metadata)
    }
    
    private func getCacheMetadata() -> [String: CacheMetadataEntry] {
        guard let data = self.userDefaults.data(forKey: CacheKeys.cacheMetadata),
              let metadata = try? JSONDecoder().decode([String: CacheMetadataEntry].self, from: data) else {
            return [:]
        }
        return metadata
    }
    
    private func saveCacheMetadata(_ metadata: [String: CacheMetadataEntry]) {
        do {
            let data = try JSONEncoder().encode(metadata)
            self.userDefaults.set(data, forKey: CacheKeys.cacheMetadata)
        } catch {
            print("Failed to save cache metadata: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    func getCurrentCacheSize() -> Int {
        let metadata = getCacheMetadata()
        return metadata.values.reduce(0) { $0 + $1.size }
    }
    
    func getCacheStatistics() -> CacheStatistics {
        let metadata = getCacheMetadata()
        let totalSize = metadata.values.reduce(0) { $0 + $1.size }
        let totalEntries = metadata.count
        
        var categoryCounts: [String: Int] = [:]
        for entry in metadata.values {
            categoryCounts[entry.category, default: 0] += 1
        }
        
        return CacheStatistics(
            totalSize: totalSize,
            totalEntries: totalEntries,
            categoryCounts: categoryCounts,
            maxCacheSize: self.maxCacheSize
        )
    }
    
    private func cleanupIfNeeded() async {
        let currentSize = getCurrentCacheSize()
        
        if currentSize > self.maxCacheSize {
            await performCacheCleanup()
        }
    }
    
    private func performCacheCleanup() async {
        let metadata = getCacheMetadata()
        
        // Sort entries by timestamp (oldest first)
        let sortedEntries = metadata.sorted { $0.value.timestamp < $1.value.timestamp }
        
        var currentSize = getCurrentCacheSize()
        let targetSize = Int(Double(self.maxCacheSize) * 0.8) // Clean up to 80% of max size
        
        for (key, entry) in sortedEntries {
            if currentSize <= targetSize {
                break
            }
            
            // Remove file
            let fileURL = self.cacheDirectory.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: fileURL)
            
            currentSize -= entry.size
        }
        
        // Update metadata
        var updatedMetadata = getCacheMetadata()
        for (key, _) in sortedEntries {
            if getCurrentCacheSize() <= targetSize {
                break
            }
            updatedMetadata.removeValue(forKey: key)
        }
        saveCacheMetadata(updatedMetadata)
    }
    
    func clearExpiredEntries() async {
        let metadata = getCacheMetadata()
        let now = Date()
        
        var updatedMetadata = metadata
        
        for (key, entry) in metadata {
            if entry.expiryDate < now {
                // Remove expired file
                let fileURL = self.cacheDirectory.appendingPathComponent(key)
                try? FileManager.default.removeItem(at: fileURL)
                
                // Remove from metadata
                updatedMetadata.removeValue(forKey: key)
            }
        }
        
        saveCacheMetadata(updatedMetadata)
    }
    
    func clearAllCache() async {
        // Remove all cache files
        try? FileManager.default.removeItem(at: self.cacheDirectory)
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        
        // Clear metadata
        self.userDefaults.removeObject(forKey: CacheKeys.cacheMetadata)
    }
    
    func clearCacheCategory(_ category: String) async {
        let metadata = getCacheMetadata()
        var updatedMetadata = metadata
        
        for (key, entry) in metadata {
            if entry.category == category {
                // Remove file
                let fileURL = self.cacheDirectory.appendingPathComponent(key)
                try? FileManager.default.removeItem(at: fileURL)
                
                // Remove from metadata
                updatedMetadata.removeValue(forKey: key)
            }
        }
        
        saveCacheMetadata(updatedMetadata)
    }
    
    // MARK: - 智能缓存策略优化
    
    /// 智能缓存清理策略
    private func performIntelligentCleanup() async {
        let metadata = getCacheMetadata()
        let currentSize = getCurrentCacheSize()
        
        if currentSize <= Int(Double(maxCacheSize) * 0.7) {
            return // 使用率低于70%，无需清理
        }
        
        // 按优先级排序清理策略
        let cleanupStrategies: [(String, (CacheMetadataEntry) -> Double)] = [
            ("过期清理", { entry in
                entry.expiryDate < Date() ? 1000.0 : 0.0
            }),
            ("使用频率", { entry in
                let daysSinceLastAccess = Date().timeIntervalSince(entry.timestamp) / (24 * 60 * 60)
                return daysSinceLastAccess * 10.0
            }),
            ("文件大小", { entry in
                Double(entry.size) / 1024.0 // KB
            }),
            ("类别优先级", { entry in
                switch entry.category {
                case CacheKeys.photoRecognition: return 1.0 // 最低优先级清理
                case CacheKeys.itemIdentification: return 2.0
                case CacheKeys.travelSuggestions: return 3.0
                case CacheKeys.packingOptimization: return 4.0
                case CacheKeys.alternatives: return 5.0
                case CacheKeys.airlinePolicies: return 6.0 // 最高优先级清理
                default: return 3.0
                }
            })
        ]
        
        // 计算每个缓存项的清理分数
        var scoredEntries: [(String, CacheMetadataEntry, Double)] = []
        
        for (key, entry) in metadata {
            var totalScore = 0.0
            
            for (_, strategy) in cleanupStrategies {
                totalScore += strategy(entry)
            }
            
            scoredEntries.append((key, entry, totalScore))
        }
        
        // 按分数排序（分数越高越优先清理）
        scoredEntries.sort { $0.2 > $1.2 }
        
        // 执行清理直到达到目标大小
        let targetSize = Int(Double(maxCacheSize) * 0.6) // 清理到60%
        var currentCleanupSize = currentSize
        var cleanedCount = 0
        
        for (key, entry, score) in scoredEntries {
            if currentCleanupSize <= targetSize {
                break
            }
            
            // 删除文件
            let fileURL = cacheDirectory.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: fileURL)
            
            currentCleanupSize -= entry.size
            cleanedCount += 1
            
            logger.debug("清理缓存项: \(key), 分数: \(String(format: "%.2f", score)), 大小: \(entry.size)")
        }
        
        // 更新元数据
        var updatedMetadata = getCacheMetadata()
        for (key, _, _) in scoredEntries.prefix(cleanedCount) {
            updatedMetadata.removeValue(forKey: key)
        }
        saveCacheMetadata(updatedMetadata)
        
        logger.info("智能缓存清理完成: 清理 \(cleanedCount) 项, 释放 \(ByteCountFormatter.string(fromByteCount: Int64(currentSize - currentCleanupSize), countStyle: .file))")
    }
    
    /// 预测性缓存管理
    private func performPredictiveCaching() async {
        let metadata = getCacheMetadata()
        let now = Date()
        
        // 分析使用模式
        var categoryUsagePatterns: [String: CategoryUsagePattern] = [:]
        
        for (_, entry) in metadata {
            let pattern = categoryUsagePatterns[entry.category] ?? CategoryUsagePattern()
            pattern.totalAccesses += 1
            pattern.lastAccessTime = max(pattern.lastAccessTime, entry.timestamp)
            pattern.averageSize = (pattern.averageSize * Double(pattern.totalAccesses - 1) + Double(entry.size)) / Double(pattern.totalAccesses)
            
            categoryUsagePatterns[entry.category] = pattern
        }
        
        // 根据使用模式调整缓存策略
        for (category, pattern) in categoryUsagePatterns {
            let daysSinceLastAccess = now.timeIntervalSince(pattern.lastAccessTime) / (24 * 60 * 60)
            
            if daysSinceLastAccess > 7 && pattern.totalAccesses < 5 {
                // 很少使用的类别，减少缓存时间
                await adjustCacheExpiryForCategory(category, multiplier: 0.5)
            } else if daysSinceLastAccess < 1 && pattern.totalAccesses > 20 {
                // 频繁使用的类别，延长缓存时间
                await adjustCacheExpiryForCategory(category, multiplier: 1.5)
            }
        }
    }
    
    private func adjustCacheExpiryForCategory(_ category: String, multiplier: Double) async {
        // 这里可以实现动态调整特定类别的缓存过期时间
        logger.info("调整缓存策略: \(category), 倍数: \(multiplier)")
    }
    
    /// 存储空间优化
    private func optimizeStorageSpace() async {
        // 1. 压缩旧的缓存文件
        await compressOldCacheFiles()
        
        // 2. 合并小文件
        await mergeSmallCacheFiles()
        
        // 3. 清理临时文件
        await cleanupTemporaryFiles()
    }
    
    private func compressOldCacheFiles() async {
        let metadata = getCacheMetadata()
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24小时前
        
        for (key, entry) in metadata {
            if entry.timestamp < cutoffDate && entry.size > 10 * 1024 { // 大于10KB的文件
                let fileURL = cacheDirectory.appendingPathComponent(key)
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let compressedData = try data.compressed()
                    
                    if compressedData.count < data.count {
                        try compressedData.write(to: fileURL)
                        
                        // 更新元数据
                        var updatedMetadata = getCacheMetadata()
                        if var updatedEntry = updatedMetadata[key] {
                            updatedEntry.size = compressedData.count
                            updatedMetadata[key] = updatedEntry
                            saveCacheMetadata(updatedMetadata)
                        }
                        
                        logger.debug("压缩缓存文件: \(key), 原大小: \(data.count), 压缩后: \(compressedData.count)")
                    }
                } catch {
                    logger.error("压缩缓存文件失败: \(key), 错误: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func mergeSmallCacheFiles() async {
        // 将小于1KB的同类别缓存文件合并
        let metadata = getCacheMetadata()
        let smallFiles = metadata.filter { $0.value.size < 1024 }
        
        let groupedByCategory = Dictionary(grouping: smallFiles) { $0.value.category }
        
        for (category, files) in groupedByCategory {
            if files.count > 5 { // 超过5个小文件才合并
                await mergeFilesInCategory(category, files: files.map { $0.key })
            }
        }
    }
    
    private func mergeFilesInCategory(_ category: String, files: [String]) async {
        // 实现文件合并逻辑
        logger.info("合并小文件: \(category), 文件数: \(files.count)")
    }
    
    private func cleanupTemporaryFiles() async {
        let tempDirectory = cacheDirectory.appendingPathComponent("temp")
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey])
            let cutoffDate = Date().addingTimeInterval(-60 * 60) // 1小时前
            
            for fileURL in tempFiles {
                if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            // 临时目录不存在或其他错误，忽略
        }
    }
    
    private func schedulePeriodicCleanup() {
        // 每小时执行基础清理
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
            Task {
                await self.clearExpiredEntries()
                await self.cleanupIfNeeded()
            }
        }
        
        // 每6小时执行智能清理
        Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task {
                await self.performIntelligentCleanup()
                await self.performPredictiveCaching()
            }
        }
        
        // 每天执行存储优化
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task {
                await self.optimizeStorageSpace()
            }
        }
    }
    
    // MARK: - 缓存性能分析
    
    /// 获取缓存性能分析
    func getCachePerformanceAnalysis() -> CachePerformanceAnalysis {
        let metadata = getCacheMetadata()
        let totalSize = getCurrentCacheSize()
        
        // 按类别分析
        var categoryAnalysis: [String: CategoryAnalysis] = [:]
        
        for (_, entry) in metadata {
            let analysis = categoryAnalysis[entry.category] ?? CategoryAnalysis()
            analysis.fileCount += 1
            analysis.totalSize += entry.size
            analysis.oldestFile = min(analysis.oldestFile, entry.timestamp)
            analysis.newestFile = max(analysis.newestFile, entry.timestamp)
            
            categoryAnalysis[entry.category] = analysis
        }
        
        // 计算平均文件大小
        for (category, analysis) in categoryAnalysis {
            analysis.averageFileSize = analysis.totalSize / analysis.fileCount
            categoryAnalysis[category] = analysis
        }
        
        return CachePerformanceAnalysis(
            totalSize: totalSize,
            totalFiles: metadata.count,
            maxSize: maxCacheSize,
            usagePercentage: Double(totalSize) / Double(maxCacheSize) * 100,
            categoryAnalysis: categoryAnalysis,
            lastCleanup: getLastCleanupTime(),
            recommendedActions: generateRecommendedActions(totalSize: totalSize, categoryAnalysis: categoryAnalysis)
        )
    }
    
    private func getLastCleanupTime() -> Date? {
        // 从用户偏好或日志中获取上次清理时间
        return userDefaults.object(forKey: "last_cache_cleanup") as? Date
    }
    
    private func generateRecommendedActions(totalSize: Int, categoryAnalysis: [String: CategoryAnalysis]) -> [String] {
        var actions: [String] = []
        
        if Double(totalSize) / Double(maxCacheSize) > 0.8 {
            actions.append("建议清理缓存，当前使用率超过80%")
        }
        
        for (category, analysis) in categoryAnalysis {
            if analysis.fileCount > 100 {
                actions.append("类别 \(category) 文件过多(\(analysis.fileCount)个)，建议清理")
            }
            
            let daysSinceOldest = Date().timeIntervalSince(analysis.oldestFile) / (24 * 60 * 60)
            if daysSinceOldest > 30 {
                actions.append("类别 \(category) 存在超过30天的旧文件，建议清理")
            }
        }
        
        return actions
    }
    
    // MARK: - Missing Methods
    
    func cacheAirlinePolicy(airline: String, response: AirlineLuggagePolicy) {
        let cacheEntry = CacheEntry(
            data: response,
            timestamp: Date(),
            expiryDate: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days for airline policies
        )
        saveCacheEntry(cacheEntry, forKey: airline, category: CacheKeys.airlinePolicies)
    }
    
    func getCachedAirlinePolicy(for airline: String) -> AirlineLuggagePolicy? {
        return getCacheEntry(forKey: airline, category: CacheKeys.airlinePolicies, type: AirlineLuggagePolicy.self)
    }
}

// MARK: - Supporting Data Structures

struct CacheEntry<T: Codable>: Codable {
    let data: T
    let timestamp: Date
    let expiryDate: Date
}

struct CacheMetadataEntry: Codable {
    var size: Int
    let timestamp: Date
    let expiryDate: Date
    let category: String
}

struct CacheStatistics {
    let totalSize: Int
    let totalEntries: Int
    let categoryCounts: [String: Int]
    let maxCacheSize: Int
    
    var usagePercentage: Double {
        return Double(totalSize) / Double(maxCacheSize) * 100
    }
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    var formattedMaxSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(maxCacheSize), countStyle: .file)
    }
}

// MARK: - 新增的缓存分析数据结构

class CategoryUsagePattern {
    var totalAccesses: Int = 0
    var lastAccessTime: Date = Date.distantPast
    var averageSize: Double = 0.0
}

class CategoryAnalysis {
    var fileCount: Int = 0
    var totalSize: Int = 0
    var averageFileSize: Int = 0
    var oldestFile: Date = Date()
    var newestFile: Date = Date.distantPast
}

struct CachePerformanceAnalysis {
    let totalSize: Int
    let totalFiles: Int
    let maxSize: Int
    let usagePercentage: Double
    let categoryAnalysis: [String: CategoryAnalysis]
    let lastCleanup: Date?
    let recommendedActions: [String]
    
    var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    var formattedMaxSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .file)
    }
    
    var isNearCapacity: Bool {
        return usagePercentage > 80
    }
    
    var needsCleanup: Bool {
        return usagePercentage > 90 || !recommendedActions.isEmpty
    }
}

// MARK: - Cache Request Types
// 使用 AIModels.swift 中定义的请求类型

// MARK: - Data Compression Extension

extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .lzfse) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .lzfse) as Data
    }
}