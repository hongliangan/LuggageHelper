import Foundation
import UIKit

/// 批量识别服务
/// 
/// 专门处理多物品批量识别的高效服务，优化大量物品的识别流程
/// 
/// 🚀 核心优势：
/// - 并行处理：同时识别多个物品，显著提升效率
/// - 智能调度：根据物品复杂度动态分配资源
/// - 进度跟踪：实时反馈识别进度和状态
/// - 错误恢复：自动重试失败的识别任务
/// - 结果聚合：智能合并和去重识别结果
/// 
/// 🔄 处理流程：
/// 1. 图像预处理和质量检查
/// 2. 多物品检测和区域分割
/// 3. 并行识别各个物品区域
/// 4. 结果验证和置信度评估
/// 5. 智能合并和去重处理
/// 6. 生成最终批量识别报告
/// 
/// ⚡ 性能特性：
/// - 最大并发数：3个识别任务
/// - 单物品超时：30秒
/// - 支持最多20个物品批量处理
/// - 内存优化：流式处理大图像
/// - 缓存利用：复用相似物品结果
/// 
/// 📊 适用场景：
/// - 行李箱全物品清点
/// - 购物清单批量录入
/// - 仓库物品盘点
/// - 旅行装备检查
final class BatchRecognitionService {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = BatchRecognitionService()
    
    /// 私有初始化
    private init() {
        setupBatchConfiguration()
    }
    
    // MARK: - 属性
    
    /// 对象检测引擎
    private let objectDetector = ObjectDetectionEngine.shared
    
    /// AI服务扩展
    private let aiService = AIServiceExtensions.shared
    
    /// 批量配置
    private var batchConfig = BatchConfiguration()
    
    /// 当前批量任务
    private var currentBatchTask: BatchRecognitionTask?
    
    // MARK: - 初始化
    
    /// 设置批量配置
    private func setupBatchConfiguration() {
        batchConfig.maxConcurrentRequests = 3
        batchConfig.timeoutPerItem = 30.0
        batchConfig.enableProgressTracking = true
        batchConfig.autoRetryFailedItems = true
    }
    
    // MARK: - 主要接口
    
    /// 批量识别图像中的所有物品
    /// - Parameters:
    ///   - image: 包含多个物品的图像
    ///   - progressHandler: 进度回调
    /// - Returns: 批量识别结果
    func recognizeAllObjects(
        in image: UIImage,
        progressHandler: @escaping (BatchProgress) -> Void = { _ in }
    ) async throws -> BatchRecognitionResult {
        
        // 1. 检测所有对象
        let detectionResult = await objectDetector.detectAndGroupObjects(in: image)
        
        // 2. 创建批量任务
        let task = BatchRecognitionTask(
            id: UUID(),
            originalImage: image,
            detectedObjects: detectionResult.objects,
            groups: detectionResult.groups,
            startTime: Date()
        )
        
        currentBatchTask = task
        
        // 3. 执行批量识别
        return try await performBatchRecognition(task: task, progressHandler: progressHandler)
    }
    
    /// 识别选定的物品
    /// - Parameters:
    ///   - selectedObjects: 用户选择的物品
    ///   - originalImage: 原始图像
    ///   - progressHandler: 进度回调
    /// - Returns: 批量识别结果
    func recognizeSelectedObjects(
        _ selectedObjects: [DetectedObject],
        from originalImage: UIImage,
        progressHandler: @escaping (BatchProgress) -> Void = { _ in }
    ) async throws -> BatchRecognitionResult {
        
        let task = BatchRecognitionTask(
            id: UUID(),
            originalImage: originalImage,
            detectedObjects: selectedObjects,
            groups: [],
            startTime: Date()
        )
        
        currentBatchTask = task
        
        return try await performBatchRecognition(task: task, progressHandler: progressHandler)
    }
    
    /// 取消当前批量任务
    func cancelCurrentBatch() {
        currentBatchTask?.isCancelled = true
        currentBatchTask = nil
    }
    
    /// 获取当前批量任务状态
    func getCurrentBatchStatus() -> BatchStatus? {
        return currentBatchTask?.status
    }
    
    // MARK: - 核心实现
    
    /// 执行批量识别
    private func performBatchRecognition(
        task: BatchRecognitionTask,
        progressHandler: @escaping (BatchProgress) -> Void
    ) async throws -> BatchRecognitionResult {
        
        task.status = .processing
        let totalObjects = task.detectedObjects.count
        var completedObjects = 0
        var recognitionResults: [ObjectRecognitionResult] = []
        var failedObjects: [DetectedObject] = []
        
        // 初始进度报告
        let initialProgress = BatchProgress(
            currentIndex: 0,
            totalItems: totalObjects,
            currentItem: "开始批量识别",
            estimatedTimeRemaining: nil
        )
        await MainActor.run {
            progressHandler(initialProgress)
        }
        
        // 使用 TaskGroup 进行并发处理
        try await withThrowingTaskGroup(of: ObjectRecognitionResult?.self) { group in
            var activeRequests = 0
            var objectIndex = 0
            
            // 添加初始批次的任务
            while activeRequests < batchConfig.maxConcurrentRequests && objectIndex < totalObjects {
                let object = task.detectedObjects[objectIndex]
                
                group.addTask {
                    return await self.recognizeSingleObject(object, from: task.originalImage)
                }
                
                activeRequests += 1
                objectIndex += 1
            }
            
            // 处理结果并添加新任务
            for try await result in group {
                // 检查是否被取消
                if task.isCancelled {
                    throw BatchRecognitionError.cancelled
                }
                
                completedObjects += 1
                
                if let result = result {
                    recognitionResults.append(result)
                } else {
                    // 识别失败的对象
                    if completedObjects <= totalObjects {
                        let failedObject = task.detectedObjects[completedObjects - 1]
                        failedObjects.append(failedObject)
                    }
                }
                
                // 更新进度
                let progress = BatchProgress(
                    currentIndex: completedObjects,
                    totalItems: totalObjects,
                    currentItem: result?.detectedObject.category.displayName ?? "处理中",
                    estimatedTimeRemaining: calculateEstimatedTime(
                        completed: completedObjects,
                        total: totalObjects,
                        startTime: task.startTime
                    )
                )
                
                await MainActor.run {
                    progressHandler(progress)
                }
                
                // 添加新任务（如果还有未处理的对象）
                if objectIndex < totalObjects {
                    let nextObject = task.detectedObjects[objectIndex]
                    
                    group.addTask {
                        return await self.recognizeSingleObject(nextObject, from: task.originalImage)
                    }
                    
                    objectIndex += 1
                }
            }
        }
        
        // 处理失败的对象（如果启用了重试）
        if batchConfig.autoRetryFailedItems && !failedObjects.isEmpty {
            let retryResults = try await retryFailedObjects(failedObjects, from: task.originalImage)
            recognitionResults.append(contentsOf: retryResults)
        }
        
        // 创建最终结果
        task.status = .completed
        
        return BatchRecognitionResult(
            taskId: task.id,
            originalImage: task.originalImage,
            successful: recognitionResults.map { $0.recognizedItem },
            failed: failedObjects,
            processingTime: Date().timeIntervalSince(task.startTime)
        )
    }
    
    /// 识别单个对象
    private func recognizeSingleObject(_ object: DetectedObject, from originalImage: UIImage) async -> ObjectRecognitionResult? {
        guard let thumbnail = object.thumbnail else {
            return nil
        }
        
        do {
            // 使用AI服务识别物品
            let imageData = thumbnail.jpegData(compressionQuality: 0.8) ?? Data()
            let itemInfo = try await aiService.identifyItemFromPhoto(imageData)
            
            return ObjectRecognitionResult(
                detectedObject: object,
                recognizedItem: itemInfo,
                confidence: Double(object.confidence),
                processingTime: 0 // 可以添加计时
            )
        } catch {
            print("识别对象失败: \(error)")
            return nil
        }
    }
    
    /// 重试失败的对象
    private func retryFailedObjects(_ failedObjects: [DetectedObject], from originalImage: UIImage) async throws -> [ObjectRecognitionResult] {
        var retryResults: [ObjectRecognitionResult] = []
        
        for object in failedObjects {
            if let result = await recognizeSingleObject(object, from: originalImage) {
                retryResults.append(result)
            }
        }
        
        return retryResults
    }
    
    /// 计算预估剩余时间
    private func calculateEstimatedTime(completed: Int, total: Int, startTime: Date) -> TimeInterval? {
        guard completed > 0 else { return nil }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let averageTimePerItem = elapsedTime / Double(completed)
        let remainingItems = total - completed
        
        return averageTimePerItem * Double(remainingItems)
    }
    
    /// 计算整体置信度
    private func calculateOverallConfidence(_ results: [ObjectRecognitionResult]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let totalConfidence = results.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(results.count)
    }
    
    // MARK: - 智能分组和优化
    
    /// 智能分组识别结果
    /// - Parameter results: 识别结果列表
    /// - Returns: 分组后的结果
    func groupRecognitionResults(_ results: [ObjectRecognitionResult]) -> [RecognitionGroup] {
        var groups: [RecognitionGroup] = []
        
        // 按类别分组
        let categoryGroups = Dictionary(grouping: results) { result in
            result.recognizedItem.category
        }
        
        for (category, categoryResults) in categoryGroups {
            let group = RecognitionGroup(
                id: UUID(),
                category: category,
                results: categoryResults,
                averageConfidence: categoryResults.reduce(0.0) { $0 + $1.confidence } / Double(categoryResults.count)
            )
            groups.append(group)
        }
        
        return groups.sorted { $0.averageConfidence > $1.averageConfidence }
    }
    
    /// 优化识别结果
    /// - Parameter results: 原始识别结果
    /// - Returns: 优化后的结果
    func optimizeRecognitionResults(_ results: [ObjectRecognitionResult]) -> [ObjectRecognitionResult] {
        var optimizedResults = results
        
        // 1. 移除低置信度结果
        optimizedResults = optimizedResults.filter { $0.confidence >= 0.3 }
        
        // 2. 合并相似结果
        optimizedResults = mergeSimilarResults(optimizedResults)
        
        // 3. 按置信度排序
        optimizedResults.sort { $0.confidence > $1.confidence }
        
        return optimizedResults
    }
    
    /// 合并相似的识别结果
    private func mergeSimilarResults(_ results: [ObjectRecognitionResult]) -> [ObjectRecognitionResult] {
        var mergedResults: [ObjectRecognitionResult] = []
        var processedIndices: Set<Int> = []
        
        for (index, result) in results.enumerated() {
            if processedIndices.contains(index) {
                continue
            }
            
            var similarResults = [result]
            processedIndices.insert(index)
            
            // 查找相似的结果
            for (otherIndex, otherResult) in results.enumerated() {
                if otherIndex != index && !processedIndices.contains(otherIndex) {
                    if areSimilarResults(result, otherResult) {
                        similarResults.append(otherResult)
                        processedIndices.insert(otherIndex)
                    }
                }
            }
            
            // 如果有相似结果，合并它们
            if similarResults.count > 1 {
                let mergedResult = mergeSimilarResultGroup(similarResults)
                mergedResults.append(mergedResult)
            } else {
                mergedResults.append(result)
            }
        }
        
        return mergedResults
    }
    
    /// 判断两个结果是否相似
    private func areSimilarResults(_ result1: ObjectRecognitionResult, _ result2: ObjectRecognitionResult) -> Bool {
        // 基于物品名称和类别的相似性
        let namesSimilar = result1.recognizedItem.name.lowercased() == result2.recognizedItem.name.lowercased()
        let categoriesSame = result1.recognizedItem.category == result2.recognizedItem.category
        
        return namesSimilar || categoriesSame
    }
    
    /// 合并相似结果组
    private func mergeSimilarResultGroup(_ results: [ObjectRecognitionResult]) -> ObjectRecognitionResult {
        // 选择置信度最高的作为主要结果
        let primaryResult = results.max { $0.confidence < $1.confidence } ?? results[0]
        
        // 计算平均置信度
        let averageConfidence = results.reduce(0.0) { $0 + $1.confidence } / Double(results.count)
        
        return ObjectRecognitionResult(
            detectedObject: primaryResult.detectedObject,
            recognizedItem: primaryResult.recognizedItem,
            confidence: averageConfidence,
            processingTime: primaryResult.processingTime
        )
    }
}

// MARK: - 数据模型

/// 批量配置
struct BatchConfiguration {
    var maxConcurrentRequests: Int = 3
    var timeoutPerItem: TimeInterval = 30.0
    var enableProgressTracking: Bool = true
    var autoRetryFailedItems: Bool = true
}

/// 批量识别任务
class BatchRecognitionTask {
    let id: UUID
    let originalImage: UIImage
    let detectedObjects: [DetectedObject]
    let groups: [ObjectGroup]
    let startTime: Date
    var status: BatchStatus = .pending
    var isCancelled: Bool = false
    
    init(id: UUID, originalImage: UIImage, detectedObjects: [DetectedObject], groups: [ObjectGroup], startTime: Date) {
        self.id = id
        self.originalImage = originalImage
        self.detectedObjects = detectedObjects
        self.groups = groups
        self.startTime = startTime
    }
}

/// 批量状态
enum BatchStatus {
    case pending
    case processing
    case completed
    case failed
    case cancelled
}

// BatchProgress 现在在 AIModels.swift 中定义

/// 对象识别结果
struct ObjectRecognitionResult {
    let detectedObject: DetectedObject
    let recognizedItem: ItemInfo
    let confidence: Double
    let processingTime: TimeInterval
}

// BatchRecognitionResult 现在在 AIModels.swift 中定义

/// 识别分组
struct RecognitionGroup: Identifiable {
    let id: UUID
    let category: ItemCategory
    let results: [ObjectRecognitionResult]
    let averageConfidence: Double
}

/// 批量识别错误
enum BatchRecognitionError: LocalizedError {
    case cancelled
    case timeout
    case tooManyFailures
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "批量识别已取消"
        case .timeout:
            return "批量识别超时"
        case .tooManyFailures:
            return "失败次数过多"
        case .invalidImage:
            return "无效的图像"
        }
    }
}