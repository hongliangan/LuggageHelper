//
//  PersonalizedRecognitionOptimizer.swift
//  LuggageHelper
//
//  Created by Kiro on 2025/7/28.
//

import Foundation

/// 个性化识别优化器
@MainActor
class PersonalizedRecognitionOptimizer: ObservableObject {
    
    // MARK: - Properties
    
    private let feedbackManager: UserFeedbackManager
    private let userDefaults = UserDefaults.standard
    private let optimizationDataKey = "PersonalizedOptimizationData"
    
    // MARK: - Published Properties
    
    @Published var optimizationData: OptimizationData
    @Published var isOptimizing = false
    
    // MARK: - Initialization
    
    init(feedbackManager: UserFeedbackManager) {
        self.feedbackManager = feedbackManager
        self.optimizationData = OptimizationData()
        loadOptimizationData()
    }
    
    // MARK: - Public Methods
    
    /// 优化识别结果
    func optimizeRecognitionResult(_ originalResult: PhotoRecognitionResult, 
                                 imageHash: String) async -> PhotoRecognitionResult {
        isOptimizing = true
        defer { isOptimizing = false }
        
        var optimizedResult = originalResult
        
        // 1. 应用用户修正历史
        optimizedResult = applyUserCorrections(optimizedResult)
        
        // 2. 应用类别偏好
        optimizedResult = applyCategoryPreferences(optimizedResult)
        
        // 3. 应用相似度匹配
        optimizedResult = await applySimilarityMatching(optimizedResult, imageHash: imageHash)
        
        // 4. 调整置信度
        optimizedResult = adjustConfidenceScore(optimizedResult)
        
        // 5. 更新优化数据
        await updateOptimizationData(originalResult: originalResult, optimizedResult: optimizedResult)
        
        return optimizedResult
    }
    
    /// 获取个性化建议
    func getPersonalizedSuggestions(for category: ItemCategory, 
                                  context: RecognitionContext) -> [PersonalizedSuggestion] {
        var suggestions: [PersonalizedSuggestion] = []
        
        // 基于使用频率的建议
        if let frequency = optimizationData.categoryUsageFrequency[category], frequency > 5 {
            suggestions.append(PersonalizedSuggestion(
                type: .frequentCategory,
                message: "您经常识别\(category.displayName)类物品",
                confidence: 0.8,
                actionable: false
            ))
        }
        
        // 基于时间模式的建议
        if let timePattern = getTimeBasedPattern(for: category) {
            suggestions.append(PersonalizedSuggestion(
                type: .timePattern,
                message: timePattern.suggestion,
                confidence: timePattern.confidence,
                actionable: true
            ))
        }
        
        // 基于修正历史的建议
        if let commonCorrection = getCommonCorrection(for: context.originalName) {
            suggestions.append(PersonalizedSuggestion(
                type: .commonCorrection,
                message: "根据您的历史修正，这可能是\(commonCorrection)",
                confidence: 0.9,
                actionable: true
            ))
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    /// 学习用户反馈
    func learnFromFeedback(_ feedback: UserFeedback, 
                          originalResult: PhotoRecognitionResult) async {
        // 更新类别偏好
        updateCategoryPreferences(feedback: feedback)
        
        // 更新修正模式
        updateCorrectionPatterns(feedback: feedback, originalResult: originalResult)
        
        // 更新时间模式
        updateTimePatterns(feedback: feedback)
        
        // 更新置信度调整因子
        updateConfidenceFactors(feedback: feedback, originalResult: originalResult)
        
        // 保存优化数据
        saveOptimizationData()
    }
    
    /// 重置个性化数据
    func resetPersonalizationData() {
        optimizationData = OptimizationData()
        saveOptimizationData()
    }
    
    /// 获取优化统计
    func getOptimizationStatistics() -> OptimizationStatistics {
        let totalOptimizations = optimizationData.optimizationHistory.count
        let successfulOptimizations = optimizationData.optimizationHistory.filter { $0.wasSuccessful }.count
        let averageImprovement = optimizationData.optimizationHistory.isEmpty ? 0.0 :
            optimizationData.optimizationHistory.map { $0.confidenceImprovement }.reduce(0, +) / Double(totalOptimizations)
        
        return OptimizationStatistics(
            totalOptimizations: totalOptimizations,
            successfulOptimizations: successfulOptimizations,
            successRate: totalOptimizations > 0 ? Double(successfulOptimizations) / Double(totalOptimizations) : 0.0,
            averageImprovement: averageImprovement,
            mostOptimizedCategory: getMostOptimizedCategory(),
            lastOptimization: optimizationData.optimizationHistory.last?.timestamp
        )
    }
}

// MARK: - Private Methods

private extension PersonalizedRecognitionOptimizer {
    
    /// 应用用户修正历史
    func applyUserCorrections(_ result: PhotoRecognitionResult) -> PhotoRecognitionResult {
        let originalName = result.itemInfo.name
        
        // 检查是否有常见修正
        if let correction = feedbackManager.getCommonCorrections(for: originalName) {
            var correctedResult = result
            var correctedItemInfo = result.itemInfo
            correctedItemInfo = ItemInfo(
                name: correction,
                category: correctedItemInfo.category,
                weight: correctedItemInfo.weight,
                volume: correctedItemInfo.volume,
                confidence: min(correctedItemInfo.confidence + 0.1, 1.0)
            )
            
            correctedResult = PhotoRecognitionResult(
                itemInfo: correctedItemInfo,
                confidence: min(result.confidence + 0.1, 1.0),
                recognitionMethod: .userCorrected,
                processingTime: result.processingTime,
                imageMetadata: result.imageMetadata,
                alternatives: result.alternatives
            )
            
            return correctedResult
        }
        
        return result
    }
    
    /// 应用类别偏好
    func applyCategoryPreferences(_ result: PhotoRecognitionResult) -> PhotoRecognitionResult {
        let category = result.itemInfo.category
        let frequency = optimizationData.categoryUsageFrequency[category] ?? 0
        
        // 如果用户经常使用某个类别，提高该类别的置信度
        if frequency > 10 {
            let confidenceBoost = min(0.1, Double(frequency) / 100.0)
            var boostedResult = result
            
            boostedResult = PhotoRecognitionResult(
                itemInfo: result.itemInfo,
                confidence: min(result.confidence + confidenceBoost, 1.0),
                recognitionMethod: result.recognitionMethod,
                processingTime: result.processingTime,
                imageMetadata: result.imageMetadata,
                alternatives: result.alternatives
            )
            
            return boostedResult
        }
        
        return result
    }
    
    /// 应用相似度匹配
    func applySimilarityMatching(_ result: PhotoRecognitionResult, 
                               imageHash: String) async -> PhotoRecognitionResult {
        // 查找相似的历史识别结果
        let similarResults = findSimilarHistoricalResults(imageHash: imageHash)
        
        if let bestMatch = similarResults.first, bestMatch.similarity > 0.8 {
            // 如果找到高相似度的历史结果，使用其修正信息
            if let correctedInfo = bestMatch.result.correctedInfo {
                var improvedResult = result
                
                improvedResult = PhotoRecognitionResult(
                    itemInfo: correctedInfo,
                    confidence: min(result.confidence + 0.15, 1.0),
                    recognitionMethod: result.recognitionMethod,
                    processingTime: result.processingTime,
                    imageMetadata: result.imageMetadata,
                    alternatives: result.alternatives
                )
                
                return improvedResult
            }
        }
        
        return result
    }
    
    /// 调整置信度分数
    func adjustConfidenceScore(_ result: PhotoRecognitionResult) -> PhotoRecognitionResult {
        let category = result.itemInfo.category
        let adjustmentFactor = optimizationData.confidenceAdjustmentFactors[category] ?? 1.0
        
        let adjustedConfidence = min(result.confidence * adjustmentFactor, 1.0)
        
        if abs(adjustedConfidence - result.confidence) > 0.01 {
            var adjustedResult = result
            
            adjustedResult = PhotoRecognitionResult(
                itemInfo: result.itemInfo,
                confidence: adjustedConfidence,
                recognitionMethod: result.recognitionMethod,
                processingTime: result.processingTime,
                imageMetadata: result.imageMetadata,
                alternatives: result.alternatives
            )
            
            return adjustedResult
        }
        
        return result
    }
    
    /// 更新优化数据
    func updateOptimizationData(originalResult: PhotoRecognitionResult, 
                              optimizedResult: PhotoRecognitionResult) async {
        let optimization = OptimizationRecord(
            originalConfidence: originalResult.confidence,
            optimizedConfidence: optimizedResult.confidence,
            category: originalResult.itemInfo.category,
            wasSuccessful: optimizedResult.confidence > originalResult.confidence,
            timestamp: Date()
        )
        
        optimizationData.optimizationHistory.append(optimization)
        
        // 限制历史记录数量
        if optimizationData.optimizationHistory.count > 1000 {
            optimizationData.optimizationHistory.removeFirst(100)
        }
        
        saveOptimizationData()
    }
    
    /// 获取时间模式
    func getTimeBasedPattern(for category: ItemCategory) -> TimePattern? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        // 检查是否有时间模式
        let timeKey = "\(category.rawValue)_\(hour)"
        let weekdayKey = "\(category.rawValue)_\(weekday)"
        
        if let timeFrequency = optimizationData.timePatterns[timeKey], timeFrequency > 3 {
            return TimePattern(
                suggestion: "您通常在这个时间识别\(category.displayName)类物品",
                confidence: min(0.6 + Double(timeFrequency) / 20.0, 0.9)
            )
        }
        
        if let weekdayFrequency = optimizationData.timePatterns[weekdayKey], weekdayFrequency > 5 {
            let weekdayName = calendar.weekdaySymbols[weekday - 1]
            return TimePattern(
                suggestion: "您通常在\(weekdayName)识别\(category.displayName)类物品",
                confidence: min(0.5 + Double(weekdayFrequency) / 30.0, 0.8)
            )
        }
        
        return nil
    }
    
    /// 获取常见修正
    func getCommonCorrection(for originalName: String) -> String? {
        return optimizationData.correctionPatterns[originalName]
    }
    
    /// 查找相似的历史结果
    func findSimilarHistoricalResults(imageHash: String) -> [SimilarResult] {
        // 这里应该与图像相似度匹配器集成
        // 暂时返回空数组
        return []
    }
    
    /// 更新类别偏好
    func updateCategoryPreferences(feedback: UserFeedback) {
        if let category = feedback.correctedCategory {
            optimizationData.categoryUsageFrequency[category, default: 0] += 1
        }
    }
    
    /// 更新修正模式
    func updateCorrectionPatterns(feedback: UserFeedback, originalResult: PhotoRecognitionResult) {
        if let correctedName = feedback.correctedName {
            let originalName = originalResult.itemInfo.name
            optimizationData.correctionPatterns[originalName] = correctedName
        }
    }
    
    /// 更新时间模式
    func updateTimePatterns(feedback: UserFeedback) {
        let calendar = Calendar.current
        let now = feedback.timestamp
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        if let category = feedback.correctedCategory {
            let timeKey = "\(category.rawValue)_\(hour)"
            let weekdayKey = "\(category.rawValue)_\(weekday)"
            
            optimizationData.timePatterns[timeKey, default: 0] += 1
            optimizationData.timePatterns[weekdayKey, default: 0] += 1
        }
    }
    
    /// 更新置信度调整因子
    func updateConfidenceFactors(feedback: UserFeedback, originalResult: PhotoRecognitionResult) {
        let category = originalResult.itemInfo.category
        let originalConfidence = originalResult.confidence
        
        if feedback.isCorrect && originalConfidence < 0.8 {
            // 如果识别正确但置信度较低，提高该类别的置信度因子
            let currentFactor = optimizationData.confidenceAdjustmentFactors[category] ?? 1.0
            optimizationData.confidenceAdjustmentFactors[category] = min(currentFactor + 0.05, 1.3)
        } else if !feedback.isCorrect && originalConfidence > 0.7 {
            // 如果识别错误但置信度较高，降低该类别的置信度因子
            let currentFactor = optimizationData.confidenceAdjustmentFactors[category] ?? 1.0
            optimizationData.confidenceAdjustmentFactors[category] = max(currentFactor - 0.05, 0.7)
        }
    }
    
    /// 获取最常优化的类别
    func getMostOptimizedCategory() -> ItemCategory? {
        let categoryCount = optimizationData.optimizationHistory.reduce(into: [ItemCategory: Int]()) { counts, record in
            counts[record.category, default: 0] += 1
        }
        
        return categoryCount.max { $0.value < $1.value }?.key
    }
    
    /// 加载优化数据
    func loadOptimizationData() {
        if let data = userDefaults.data(forKey: optimizationDataKey),
           let decodedData = try? JSONDecoder().decode(OptimizationData.self, from: data) {
            optimizationData = decodedData
        }
    }
    
    /// 保存优化数据
    func saveOptimizationData() {
        if let data = try? JSONEncoder().encode(optimizationData) {
            userDefaults.set(data, forKey: optimizationDataKey)
        }
    }
}

// MARK: - Supporting Models

/// 优化数据
struct OptimizationData: Codable {
    var categoryUsageFrequency: [ItemCategory: Int] = [:]
    var correctionPatterns: [String: String] = [:]
    var timePatterns: [String: Int] = [:]
    var confidenceAdjustmentFactors: [ItemCategory: Double] = [:]
    var optimizationHistory: [OptimizationRecord] = []
    var lastUpdated: Date = Date()
}

/// 优化记录
struct OptimizationRecord: Codable {
    let id = UUID()
    let originalConfidence: Double
    let optimizedConfidence: Double
    let category: ItemCategory
    let wasSuccessful: Bool
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case originalConfidence, optimizedConfidence, category, wasSuccessful, timestamp
    }
    
    var confidenceImprovement: Double {
        return optimizedConfidence - originalConfidence
    }
}

/// 个性化建议
struct PersonalizedSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let message: String
    let confidence: Double
    let actionable: Bool
    
    enum SuggestionType {
        case frequentCategory
        case timePattern
        case commonCorrection
        case similarityMatch
    }
}

/// 识别上下文
struct RecognitionContext {
    let originalName: String
    let category: ItemCategory
    let timestamp: Date
    let imageHash: String?
}

/// 时间模式
struct TimePattern {
    let suggestion: String
    let confidence: Double
}

/// 相似结果
struct SimilarResult {
    let result: PhotoRecognitionResult
    let similarity: Double
}

/// 优化统计
struct OptimizationStatistics {
    let totalOptimizations: Int
    let successfulOptimizations: Int
    let successRate: Double
    let averageImprovement: Double
    let mostOptimizedCategory: ItemCategory?
    let lastOptimization: Date?
}