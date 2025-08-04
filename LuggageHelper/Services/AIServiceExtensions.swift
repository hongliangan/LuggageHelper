import Foundation
import Combine
import UIKit

/// AI 服务扩展
/// 提供 AI 增强功能的核心服务层
final class AIServiceExtensions {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = AIServiceExtensions()
    
    /// 私有初始化
    private init() {
        setupCache()
    }
    
    // MARK: - 属性
    
    /// API 服务
    private let apiService = LLMAPIService.shared
    
    /// 缓存管理器
    private var cache = NSCache<NSString, CacheItem>()
    
    /// 请求队列
    private let requestQueue = AIRequestQueue()
    
    /// 调试模式
    var enableDebugMode = false
    
    // MARK: - 缓存相关
    
    /// 缓存项
    final class CacheItem {
        let data: Any
        let timestamp: Date
        let expiryDate: Date
        
        init(data: Any, expiryHours: Int = 24) {
            self.data = data
            self.timestamp = Date()
            self.expiryDate = Calendar.current.date(byAdding: .hour, value: expiryHours, to: Date()) ?? Date()
        }
        
        var isExpired: Bool {
            return Date() > expiryDate
        }
    }
    
    /// 设置缓存
    private func setupCache() {
        cache.countLimit = 100 // 最多缓存100个请求
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB 缓存上限
    }
    
    /// 获取缓存
    private func getCachedResponse<T>(for key: String) -> T? {
        guard let cacheItem = cache.object(forKey: key as NSString) else {
            return nil
        }
        
        // 检查是否过期
        if cacheItem.isExpired {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        
        return cacheItem.data as? T
    }
    
    /// 缓存响应
    private func cacheResponse<T>(_ response: T, for key: String, expiryHours: Int = 24) {
        let cacheItem = CacheItem(data: response, expiryHours: expiryHours)
        cache.setObject(cacheItem, forKey: key as NSString)
    }
    
    /// 生成缓存键
    private func cacheKey(for method: String, params: [String: Any]) -> String {
        let sortedParams = params.sorted { $0.key < $1.key }
        let paramsString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(method):\(paramsString)"
    }
    
    // MARK: - 错误处理
    
    /// AI 服务错误
    enum AIServiceError: LocalizedError {
        case networkError(Error)
        case invalidResponse
        case rateLimitExceeded
        case insufficientData
        case recognitionFailed
        case configurationError
        case cacheError
        case imageProcessingError
        case unsupportedFeature
        
        var errorDescription: String? {
            switch self {
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "AI 服务返回无效响应"
            case .rateLimitExceeded:
                return "请求频率过高，请稍后重试"
            case .insufficientData:
                return "提供的信息不足以进行识别"
            case .recognitionFailed:
                return "无法识别该物品，请手动输入"
            case .configurationError:
                return "AI 服务配置错误"
            case .cacheError:
                return "缓存数据访问错误"
            case .imageProcessingError:
                return "图像处理错误"
            case .unsupportedFeature:
                return "当前 API 不支持此功能"
            }
        }
    }
    
    /// 处理 API 错误
    private func handleAPIError(_ error: Error) -> AIServiceError {
        if let apiError = error as? LLMAPIService.APIError {
            switch apiError {
            case .networkError(let error):
                return .networkError(error)
            case .rateLimitExceeded:
                return .rateLimitExceeded
            case .configurationError:
                return .configurationError
            case .invalidResponse, .serverError, .decodingError, .encodingError:
                return .invalidResponse
            case .authenticationFailed:
                return .configurationError
            case .invalidURL:
                return .configurationError
            case .insufficientData:
                return .insufficientData
            case .unsupportedProvider(_):
                return .configurationError
            }
        }
        return .networkError(error)
    }
    
    // MARK: - 请求队列
    
    /// AI 请求队列
    actor AIRequestQueue {
        private var pendingRequests: [String: Task<Any, Error>] = [:]
        private let maxConcurrentRequests = 3
        private var activeRequests = 0
        
        /// 入队请求
        func enqueue<T>(key: String, operation: @escaping () async throws -> T) async throws -> T {
            // 检查是否有相同请求正在进行
            if let existingTask = pendingRequests[key] {
                return try await existingTask.value as! T
            }
            
            // 等待可用槽位
            while activeRequests >= maxConcurrentRequests {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
            
            // 创建新任务
            let task = Task<Any, Error> {
                activeRequests += 1
                defer {
                    activeRequests -= 1
                    pendingRequests.removeValue(forKey: key)
                }
                
                return try await operation()
            }
            
            pendingRequests[key] = task
            return try await task.value as! T
        }
    }
    
    // MARK: - 缓存管理
    
    /// 清除所有缓存
    func clearAllCache() {
        cache.removeAllObjects()
        log("已清除所有缓存")
    }
    
    /// 清除过期缓存
    func clearExpiredCache() {
        // 由于 NSCache 不提供遍历功能，我们需要维护一个键列表
        // 这里简化处理，直接清除所有缓存
        cache.removeAllObjects()
        log("已清除过期缓存")
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> [String: Any] {
        return [
            "cacheLimit": cache.countLimit,
            "costLimit": cache.totalCostLimit
        ]
    }
    
    // MARK: - 日志
    
    /// 记录日志
    private func log(_ message: String) {
        if enableDebugMode {
            print("[AIService] \(message)")
        }
    }
    
    // MARK: - 物品识别功能
    
    /// 识别物品信息
    /// - Parameters:
    ///   - name: 物品名称
    ///   - model: 物品型号（可选）
    ///   - brand: 品牌（可选）
    ///   - additionalInfo: 额外信息（可选）
    /// - Returns: 物品信息
    func identifyItem(name: String, model: String? = nil, brand: String? = nil, additionalInfo: String? = nil) async throws -> ItemInfo {
        // 生成缓存键
        let params: [String: Any] = [
            "name": name,
            "model": model ?? "",
            "brand": brand ?? "",
            "additionalInfo": additionalInfo ?? ""
        ]
        let cacheKey = self.cacheKey(for: "identifyItem", params: params)
        
        // 检查缓存
        if let cachedResult: ItemInfo = getCachedResponse(for: cacheKey) {
            log("使用缓存的物品识别结果: \(name)")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("识别物品: \(name) \(model ?? "") \(brand ?? "")")
                let result = try await self.apiService.identifyItem(
                    name: name,
                    model: model,
                    brand: brand,
                    additionalInfo: additionalInfo
                )
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    /// 批量识别物品信息
    /// - Parameter items: 物品名称列表
    /// - Returns: 物品信息列表
    func batchIdentifyItems(_ items: [String]) async throws -> [ItemInfo] {
        // 生成缓存键
        let itemsString = items.joined(separator: ",")
        let params: [String: Any] = ["items": itemsString]
        let cacheKey = self.cacheKey(for: "batchIdentifyItems", params: params)
        
        // 检查缓存
        if let cachedResult: [ItemInfo] = getCachedResponse(for: cacheKey) {
            log("使用缓存的批量识别结果")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("批量识别物品: \(items.count)个")
                let result = try await self.apiService.batchIdentifyItems(items)
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    /// 从照片识别物品
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - hint: 识别提示（可选）
    /// - Returns: 物品信息
    func identifyItemFromPhoto(_ imageData: Data, hint: String? = nil) async throws -> ItemInfo {
        // 生成图片哈希作为缓存键
        let imageHash = String(imageData.hashValue)
        let params: [String: Any] = ["imageHash": imageHash, "hint": hint ?? ""]
        let cacheKey = self.cacheKey(for: "identifyItemFromPhoto", params: params)
        
        // 检查缓存
        if let cachedResult: ItemInfo = getCachedResponse(for: cacheKey) {
            log("使用缓存的照片识别结果")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("从照片识别物品 \(hint ?? "")")
                
                // 压缩图片
                guard let compressedData = self.compressImage(imageData) else {
                    throw AIServiceError.imageProcessingError
                }
                
                let result = try await self.apiService.identifyItemFromPhoto(compressedData, hint: hint)
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    /// 检查是否支持照片识别
    func supportsPhotoRecognition() -> Bool {
        return apiService.supportsPhotoRecognition()
    }
    
    /// 压缩图片
    private func compressImage(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        // 使用新的 ImagePreprocessor 进行图像预处理
        let preprocessor = ImagePreprocessor.shared
        
        // 在后台队列中执行预处理
        let semaphore = DispatchSemaphore(value: 0)
        var processedData: Data?
        
        Task {
            let preprocessingResult = await preprocessor.preprocessImage(image, options: .default)
            processedData = preprocessingResult.processedImage.jpegData(compressionQuality: 0.8)
            semaphore.signal()
        }
        
        semaphore.wait()
        return processedData
    }
    
    /// 增强图片预处理
    private func preprocessImage(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        // 使用新的 ImagePreprocessor 进行综合预处理
        let preprocessor = ImagePreprocessor.shared
        
        let semaphore = DispatchSemaphore(value: 0)
        var processedData: Data?
        
        Task {
            // 使用所有预处理选项进行最佳处理
            let preprocessingResult = await preprocessor.preprocessImage(image, options: .all)
            processedData = preprocessingResult.processedImage.jpegData(compressionQuality: 0.8)
            semaphore.signal()
        }
        
        semaphore.wait()
        return processedData
    }
    
    /// 多策略照片识别
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - strategies: 识别策略
    /// - Returns: 识别结果
    func identifyItemFromPhotoWithStrategies(
        _ imageData: Data,
        strategies: [PhotoRecognitionStrategy] = [.aiVision, .textExtraction, .colorAnalysis]
    ) async throws -> PhotoRecognitionResult {
        var results: [ItemInfo] = []
        var confidence: Double = 0.0
        var usedStrategies: [PhotoRecognitionStrategy] = []
        
        // 预处理图片
        guard let processedData = preprocessImage(imageData) else {
            throw AIServiceError.imageProcessingError
        }
        
        // 尝试不同的识别策略
        for strategy in strategies {
            do {
                let result = try await executeRecognitionStrategy(strategy, imageData: processedData)
                results.append(result)
                usedStrategies.append(strategy)
                confidence = max(confidence, result.confidence)
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                log("识别策略 \(strategy) 失败: \(error)")
                continue
            }
        }
        
        // 合并结果
        let finalResult = mergeRecognitionResults(results)
        
        return PhotoRecognitionResult(
            itemInfo: finalResult,
            confidence: confidence,
            recognitionMethod: .hybrid,
            processingTime: 0, // 这里可以添加计时
            imageMetadata: ImageMetadata.mock,
            alternatives: results.map { RecognitionCandidate(itemInfo: $0, confidence: confidence, source: "multi-strategy") }
        )
    }
    
    /// 执行特定的识别策略
    private func executeRecognitionStrategy(
        _ strategy: PhotoRecognitionStrategy,
        imageData: Data
    ) async throws -> ItemInfo {
        switch strategy {
        case .aiVision:
            return try await apiService.identifyItemFromPhoto(imageData)
            
        case .textExtraction:
            return try await recognizeItemFromText(imageData)
            
        case .colorAnalysis:
            return try await recognizeItemFromColor(imageData)
            
        case .shapeAnalysis:
            return try await recognizeItemFromShape(imageData)
        }
    }
    
    /// 从图片中的文字识别物品
    private func recognizeItemFromText(_ imageData: Data) async throws -> ItemInfo {
        // 这里可以集成 OCR 功能
        // 目前返回模拟结果
        return ItemInfo(
            name: "文字识别物品",
            category: .other,
            weight: 200.0,
            volume: 500.0,
            confidence: 0.4,
            source: "文字识别"
        )
    }
    
    /// 从颜色分析识别物品
    private func recognizeItemFromColor(_ imageData: Data) async throws -> ItemInfo {
        guard let image = UIImage(data: imageData) else {
            throw AIServiceError.imageProcessingError
        }
        
        let dominantColors = image.getDominantColors()
        
        // 基于颜色推测物品类型
        var category: ItemCategory = .other
        var name = "彩色物品"
        
        if dominantColors.contains(where: { $0.isCloseToColor(UIColor.blue) }) {
            category = .clothing
            name = "蓝色衣物"
        } else if dominantColors.contains(where: { $0.isCloseToColor(UIColor.black) }) {
            category = .electronics
            name = "黑色电子产品"
        }
        
        return ItemInfo(
            name: name,
            category: category,
            weight: 300.0,
            volume: 800.0,
            confidence: 0.3,
            source: "颜色分析"
        )
    }
    
    /// 从形状分析识别物品
    private func recognizeItemFromShape(_ imageData: Data) async throws -> ItemInfo {
        // 这里可以添加形状识别逻辑
        return ItemInfo(
            name: "形状识别物品",
            category: .other,
            weight: 250.0,
            volume: 600.0,
            confidence: 0.35,
            source: "形状分析"
        )
    }
    
    /// 合并多个识别结果
    private func mergeRecognitionResults(_ results: [ItemInfo]) -> ItemInfo {
        guard !results.isEmpty else {
            return ItemInfo.defaultItem(name: "未识别物品")
        }
        
        if results.count == 1 {
            return results[0]
        }
        
        // 选择置信度最高的结果作为主要结果
        let primaryResult = results.max { $0.confidence < $1.confidence } ?? results[0]
        
        // 合并替代品建议
        let allAlternatives = results.flatMap { $0.alternatives }
        
        return ItemInfo(
            name: primaryResult.name,
            category: primaryResult.category,
            weight: primaryResult.weight,
            volume: primaryResult.volume,
            dimensions: primaryResult.dimensions,
            confidence: primaryResult.confidence,
            alternatives: Array(Set(allAlternatives)), // 去重
            source: "多策略识别"
        )
    }
    
    // MARK: - 旅行建议功能
    
    /// 生成旅行物品清单
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 旅行天数
    ///   - season: 季节
    ///   - activities: 活动列表
    ///   - userPreferences: 用户偏好（可选）
    /// - Returns: 旅行建议
    func generateTravelChecklist(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userPreferences: UserPreferences? = nil
    ) async throws -> TravelSuggestion {
        // 生成缓存键
        let params: [String: Any] = [
            "destination": destination,
            "duration": duration,
            "season": season,
            "activities": activities.joined(separator: ",")
        ]
        let cacheKey = self.cacheKey(for: "generateTravelChecklist", params: params)
        
        // 检查缓存
        if let cachedResult: TravelSuggestion = getCachedResponse(for: cacheKey) {
            log("使用缓存的旅行建议: \(destination)")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("生成旅行建议: \(destination), \(duration)天, \(season)")
                let result = try await self.apiService.generateTravelChecklist(
                    destination: destination,
                    duration: duration,
                    season: season,
                    activities: activities,
                    userPreferences: userPreferences
                )
                
                // 缓存结果 (旅行建议缓存时间较长)
                self.cacheResponse(result, for: cacheKey, expiryHours: 72)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    // MARK: - 装箱优化功能
    
    /// 优化装箱方案
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱信息
    /// - Returns: 装箱计划
    func optimizePacking(items: [LuggageItem], luggage: Luggage) async throws -> PackingPlan {
        // 生成缓存键 (基于物品ID和行李箱ID)
        let itemIds = items.map { $0.id.uuidString }.joined(separator: ",")
        let params: [String: Any] = [
            "luggageId": luggage.id.uuidString,
            "itemIds": itemIds
        ]
        let cacheKey = self.cacheKey(for: "optimizePacking", params: params)
        
        // 检查缓存 (装箱优化缓存时间较短)
        if let cachedResult: PackingPlan = getCachedResponse(for: cacheKey) {
            log("使用缓存的装箱方案")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("优化装箱方案: \(luggage.name), \(items.count)个物品")
                let result = try await self.apiService.optimizePacking(items: items, luggage: luggage)
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey, expiryHours: 6)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    // MARK: - 智能分类功能
    
    /// 自动分类物品
    /// - Parameter item: 物品
    /// - Returns: 物品类别
    func categorizeItem(_ item: LuggageItem) async throws -> ItemCategory {
        // 生成缓存键
        let params: [String: Any] = ["name": item.name]
        let cacheKey = self.cacheKey(for: "categorizeItem", params: params)
        
        // 检查缓存
        if let cachedResult: ItemCategory = getCachedResponse(for: cacheKey) {
            log("使用缓存的物品分类: \(item.name)")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("分类物品: \(item.name)")
                let result = try await self.apiService.categorizeItem(item)
                
                // 缓存结果 (分类结果可以长期缓存)
                self.cacheResponse(result, for: cacheKey, expiryHours: 168) // 7天
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    /// 批量分类物品
    /// - Parameter items: 物品列表
    /// - Returns: 物品ID到类别的映射
    func batchCategorizeItems(_ items: [LuggageItem]) async throws -> [UUID: ItemCategory] {
        guard !items.isEmpty else {
            return [:]
        }
        
        var results: [UUID: ItemCategory] = [:]
        
        // 并行处理多个分类请求
        await withTaskGroup(of: (UUID, ItemCategory?).self) { group in
            for item in items {
                group.addTask {
                    do {
                        let category = try await self.categorizeItem(item)
                        return (item.id, category)
                    } catch where error is CancellationError {
                        // 忽略取消错误
                        return (item.id, nil)
                    } catch {
                        self.log("分类物品 \(item.name) 失败: \(error)")
                        return (item.id, nil)
                    }
                }
            }
            
            for await (itemId, category) in group {
                if let category = category {
                    results[itemId] = category
                }
            }
        }
        
        return results
    }
    
    /// 生成物品标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    func generateItemTags(for item: LuggageItem) async throws -> [String] {
        // 生成缓存键
        let params: [String: Any] = ["name": item.name, "id": item.id.uuidString]
        let cacheKey = self.cacheKey(for: "generateItemTags", params: params)
        
        // 检查缓存
        if let cachedResult: [String] = getCachedResponse(for: cacheKey) {
            log("使用缓存的物品标签: \(item.name)")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("生成物品标签: \(item.name)")
                let result = try await self.apiService.generateItemTags(for: item)
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey, expiryHours: 168) // 7天
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    /// 学习用户分类偏好
    /// - Parameters:
    ///   - item: 物品
    ///   - userCategory: 用户指定的类别
    ///   - originalCategory: 原始类别
    func learnUserCategoryPreference(item: LuggageItem, userCategory: ItemCategory, originalCategory: ItemCategory) {
        // 记录用户的分类偏好，用于改进未来的分类
        let params: [String: Any] = [
            "itemName": item.name,
            "userCategory": userCategory.rawValue,
            "originalCategory": originalCategory.rawValue
        ]
        let cacheKey = self.cacheKey(for: "userCategoryPreference", params: params)
        
        // 存储用户偏好
        let preference = [
            "itemName": item.name,
            "userCategory": userCategory.rawValue,
            "originalCategory": originalCategory.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        self.cacheResponse(preference, for: cacheKey, expiryHours: 720) // 30天
        log("学习用户分类偏好: \(item.name) 从 \(originalCategory.displayName) 到 \(userCategory.displayName)")
    }
    
    /// 获取分类准确性反馈
    /// - Returns: 分类准确性统计
    func getCategoryAccuracyStats() -> [String: Any] {
        // 这里可以实现分类准确性统计的逻辑
        // 目前返回模拟数据
        return [
            "totalClassifications": 100,
            "correctClassifications": 85,
            "accuracy": 0.85,
            "userCorrections": 15,
            "mostCorrectedCategories": [
                "electronics": 5,
                "accessories": 4,
                "clothing": 3
            ]
        ]
    }
    
    // MARK: - 个性化建议功能
    
    /// 获取个性化建议
    /// - Parameters:
    ///   - userProfile: 用户档案
    ///   - travelPlan: 旅行计划
    /// - Returns: 建议列表
    func getPersonalizedSuggestions(
        userProfile: UserProfile,
        travelPlan: TravelPlan
    ) async throws -> [SuggestedItem] {
        // 生成缓存键
        let params: [String: Any] = [
            "userId": userProfile.id.uuidString,
            "travelPlanId": travelPlan.id.uuidString,
            "destination": travelPlan.destination,
            "duration": travelPlan.duration
        ]
        let cacheKey = self.cacheKey(for: "getPersonalizedSuggestions", params: params)
        
        // 检查缓存
        if let cachedResult: [SuggestedItem] = getCachedResponse(for: cacheKey) {
            log("使用缓存的个性化建议")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("获取个性化建议: \(travelPlan.destination)")
                let result = try await self.apiService.getPersonalizedSuggestions(
                    userProfile: userProfile,
                    travelPlan: travelPlan
                )
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey, expiryHours: 24)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    // MARK: - 遗漏检查功能
    
    /// 检查遗漏物品
    /// - Parameters:
    ///   - checklist: 当前清单
    ///   - travelPlan: 旅行计划
    /// - Returns: 遗漏物品警告
    func checkMissingItems(
        checklist: [LuggageItem],
        travelPlan: TravelPlan
    ) async throws -> [MissingItemAlert] {
        // 生成缓存键
        let itemNames = checklist.map { $0.name }.joined(separator: ",")
        let params: [String: Any] = [
            "items": itemNames,
            "destination": travelPlan.destination,
            "duration": travelPlan.duration
        ]
        let cacheKey = self.cacheKey(for: "checkMissingItems", params: params)
        
        // 检查缓存
        if let cachedResult: [MissingItemAlert] = getCachedResponse(for: cacheKey) {
            log("使用缓存的遗漏检查结果")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("检查遗漏物品: \(travelPlan.destination), \(checklist.count)个物品")
                let result = try await self.apiService.checkMissingItems(
                    checklist: checklist,
                    travelPlan: travelPlan
                )
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey, expiryHours: 12)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    // MARK: - 重量预测功能
    
    /// 预测行李重量
    /// - Parameter items: 物品列表
    /// - Returns: 重量预测结果
    func predictWeight(items: [LuggageItem]) async throws -> WeightPrediction {
        // 生成缓存键
        let itemIds = items.map { $0.id.uuidString }.joined(separator: ",")
        let params: [String: Any] = ["itemIds": itemIds]
        let cacheKey = self.cacheKey(for: "predictWeight", params: params)
        
        // 检查缓存
        if let cachedResult: WeightPrediction = getCachedResponse(for: cacheKey) {
            log("使用缓存的重量预测")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("预测行李重量: \(items.count)个物品")
                let result = try await self.apiService.predictWeight(items: items)
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey, expiryHours: 6)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    // MARK: - 替代品建议功能
    
    /// 建议替代品
    /// - Parameters:
    ///   - item: 原物品
    ///   - constraints: 约束条件
    /// - Returns: 替代品列表
    func suggestAlternatives(
        for item: LuggageItem,
        constraints: PackingConstraints
    ) async throws -> [ItemInfo] {
        // 生成缓存键
        let params: [String: Any] = [
            "itemName": item.name,
            "maxWeight": constraints.maxWeight,
            "maxVolume": constraints.maxVolume
        ]
        let cacheKey = self.cacheKey(for: "suggestAlternatives", params: params)
        
        // 检查缓存
        if let cachedResult: [ItemInfo] = getCachedResponse(for: cacheKey) {
            log("使用缓存的替代品建议")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("建议��代品: \(item.name)")
                let result = try await self.apiService.suggestAlternatives(
                    for: item,
                    constraints: constraints
                )
                
                // 缓存结果
                self.cacheResponse(result, for: cacheKey, expiryHours: 48)
                return result
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
    
    // MARK: - 航空公司政策查询
    
    /// 查询航空公司行李政策
    /// - Parameter airline: 航空公司名称
    /// - Returns: 行李政策信息
    func queryAirlinePolicy(airline: String) async throws -> AirlineLuggagePolicy {
        // 生成缓存键
        let params: [String: Any] = ["airline": airline]
        let cacheKey = self.cacheKey(for: "queryAirlinePolicy", params: params)
        
        // 检查缓存 (政策可能会变化，所以缓存时间较短)
        if let cachedResult: AirlineLuggagePolicy = getCachedResponse(for: cacheKey) {
            log("使用缓存的航空公司政策: \(airline)")
            return cachedResult
        }
        
        // 通过请求队列执行
        return try await requestQueue.enqueue(key: cacheKey) {
            do {
                self.log("查询航空公司政策: \(airline)")
                
                // 这里需要实现航空公司政策查询的 API 调用
                // 目前返回模拟数据
                let policy = AirlineLuggagePolicy(
                    airline: airline,
                    carryOnWeight: 7.0,
                    carryOnDimensions: Dimensions(length: 55, width: 40, height: 20),
                    checkedWeight: 23.0,
                    checkedDimensions: Dimensions(length: 158, width: 0, height: 0),
                    restrictions: ["液体不超过100ml", "不可携带锂电池"],
                    lastUpdated: Date(),
                    source: "AI 查询"
                )
                
                // 缓存结果
                self.cacheResponse(policy, for: cacheKey, expiryHours: 24)
                return policy
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch where error is CancellationError {
                // 忽略取消错误
                throw error
            } catch {
                throw self.handleAPIError(error)
            }
        }
    }
}


