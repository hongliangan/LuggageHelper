//
//  UserFeedbackManager.swift
//  LuggageHelper
//
//  Created by Kiro on 2025/7/28.
//

import Foundation
import SwiftUI

// MARK: - 用户反馈数据模型
// UserFeedback 结构体已在 AIModels.swift 中定义

/// 识别学习数据
struct RecognitionLearningData: Codable, Identifiable {
    let id: UUID
    let imageHash: String
    let originalResult: PhotoRecognitionResult
    let userFeedback: UserFeedback
    let improvementSuggestions: [String]
    let learningWeight: Double
    let timestamp: Date
    
    init(imageHash: String, originalResult: PhotoRecognitionResult, 
         userFeedback: UserFeedback, improvementSuggestions: [String] = [], 
         learningWeight: Double = 1.0) {
        self.id = UUID()
        self.imageHash = imageHash
        self.originalResult = originalResult
        self.userFeedback = userFeedback
        self.improvementSuggestions = improvementSuggestions
        self.learningWeight = learningWeight
        self.timestamp = Date()
    }
}

/// 个性化识别偏好
struct PersonalizedRecognitionPreference: Codable {
    var categoryFrequency: [ItemCategory: Int]
    var commonCorrections: [String: String]
    var preferredTerms: [String: String]
    var lastUpdated: Date
    
    init() {
        self.categoryFrequency = [:]
        self.commonCorrections = [:]
        self.preferredTerms = [:]
        self.lastUpdated = Date()
    }
}

// MARK: - 用户反馈管理器

/// 用户反馈和学习优化管理器
@MainActor
class UserFeedbackManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var feedbackHistory: [UserFeedback] = []
    @Published var learningData: [RecognitionLearningData] = []
    @Published var personalizedPreferences: PersonalizedRecognitionPreference
    @Published var isProcessingFeedback = false
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let feedbackStorageKey = "UserFeedbackHistory"
    private let learningDataStorageKey = "RecognitionLearningData"
    private let preferencesStorageKey = "PersonalizedRecognitionPreferences"
    
    // MARK: - Initialization
    
    init() {
        self.personalizedPreferences = PersonalizedRecognitionPreference()
        loadStoredData()
    }
    
    // MARK: - Public Methods
    
    /// 提交用户反馈
    func submitFeedback(_ feedback: UserFeedback) async {
        isProcessingFeedback = true
        defer { isProcessingFeedback = false }
        
        // 添加到反馈历史
        feedbackHistory.append(feedback)
        
        // 更新个性化偏好
        await updatePersonalizedPreferences(from: feedback)
        
        // 保存数据
        saveData()
        
        print("用户反馈已提交: \(feedback.id)")
    }
    
    /// 创建学习数据
    func createLearningData(imageHash: String, originalResult: PhotoRecognitionResult, 
                          userFeedback: UserFeedback) async {
        let suggestions = await generateImprovementSuggestions(
            originalResult: originalResult, 
            userFeedback: userFeedback
        )
        
        let learningWeight = calculateLearningWeight(userFeedback: userFeedback)
        
        let learningData = RecognitionLearningData(
            imageHash: imageHash,
            originalResult: originalResult,
            userFeedback: userFeedback,
            improvementSuggestions: suggestions,
            learningWeight: learningWeight
        )
        
        self.learningData.append(learningData)
        saveData()
        
        print("学习数据已创建: \(learningData.id)")
    }
    
    /// 获取个性化识别建议
    func getPersonalizedSuggestions(for category: ItemCategory) -> [String] {
        let frequency = personalizedPreferences.categoryFrequency[category] ?? 0
        
        // 基于频率生成建议
        if frequency > 10 {
            return ["基于您的使用习惯，这可能是\(category.displayName)类物品"]
        } else if frequency > 5 {
            return ["您经常识别\(category.displayName)类物品"]
        }
        
        return []
    }
    
    /// 获取用户常用修正
    func getCommonCorrections(for originalName: String) -> String? {
        return personalizedPreferences.commonCorrections[originalName]
    }
    
    /// 清除反馈历史
    func clearFeedbackHistory() {
        feedbackHistory.removeAll()
        learningData.removeAll()
        personalizedPreferences = PersonalizedRecognitionPreference()
        saveData()
    }
    
    /// 获取反馈统计
    func getFeedbackStatistics() -> FeedbackStatistics {
        let totalFeedbacks = feedbackHistory.count
        let correctFeedbacks = feedbackHistory.filter { $0.isCorrect }.count
        let averageRating = feedbackHistory.isEmpty ? 0.0 : 
            Double(feedbackHistory.map { $0.rating }.reduce(0, +)) / Double(totalFeedbacks)
        
        return FeedbackStatistics(
            totalFeedbacks: totalFeedbacks,
            correctFeedbacks: correctFeedbacks,
            accuracyRate: totalFeedbacks > 0 ? Double(correctFeedbacks) / Double(totalFeedbacks) : 0.0,
            averageRating: averageRating
        )
    }
}

// MARK: - Private Methods

private extension UserFeedbackManager {
    
    /// 更新个性化偏好
    func updatePersonalizedPreferences(from feedback: UserFeedback) async {
        var newPreferences = personalizedPreferences
        
        // 更新类别频率
        if let category = feedback.correctedCategory {
            newPreferences.categoryFrequency[category, default: 0] += 1
        }
        
        // 更新常用修正
        if let correctedName = feedback.correctedName,
           let originalResult = learningData.first(where: { $0.userFeedback.id == feedback.id })?.originalResult {
            newPreferences.commonCorrections[originalResult.itemInfo.name] = correctedName
        }
        
        // 更新偏好术语
        if let correctedName = feedback.correctedName {
            newPreferences.preferredTerms[correctedName] = correctedName
        }
        
        personalizedPreferences = PersonalizedRecognitionPreference(
            categoryFrequency: newPreferences.categoryFrequency,
            commonCorrections: newPreferences.commonCorrections,
            preferredTerms: newPreferences.preferredTerms,
            lastUpdated: Date()
        )
    }
    
    /// 生成改进建议
    func generateImprovementSuggestions(originalResult: PhotoRecognitionResult, 
                                      userFeedback: UserFeedback) async -> [String] {
        var suggestions: [String] = []
        
        if !userFeedback.isCorrect {
            if let correctedName = userFeedback.correctedName {
                suggestions.append("用户将'\(originalResult.itemInfo.name)'修正为'\(correctedName)'")
            }
            
            if let correctedCategory = userFeedback.correctedCategory {
                suggestions.append("用户将类别修正为'\(correctedCategory.displayName)'")
            }
            
            if originalResult.confidence < 0.7 {
                suggestions.append("低置信度结果需要改进识别算法")
            }
        }
        
        if userFeedback.rating < 3 {
            suggestions.append("用户满意度较低，需要优化识别体验")
        }
        
        return suggestions
    }
    
    /// 计算学习权重
    func calculateLearningWeight(userFeedback: UserFeedback) -> Double {
        var weight = 1.0
        
        // 基于评分调整权重
        weight *= Double(userFeedback.rating) / 3.0
        
        // 如果有详细修正，增加权重
        if userFeedback.correctedName != nil || userFeedback.correctedCategory != nil {
            weight *= 1.5
        }
        
        // 如果有评论，增加权重
        if userFeedback.comments != nil && !userFeedback.comments!.isEmpty {
            weight *= 1.2
        }
        
        return min(weight, 3.0) // 最大权重为3.0
    }
    
    /// 加载存储的数据
    func loadStoredData() {
        // 加载反馈历史
        if let feedbackData = userDefaults.data(forKey: feedbackStorageKey),
           let decodedFeedback = try? JSONDecoder().decode([UserFeedback].self, from: feedbackData) {
            feedbackHistory = decodedFeedback
        }
        
        // 加载学习数据
        if let learningDataData = userDefaults.data(forKey: learningDataStorageKey),
           let decodedLearningData = try? JSONDecoder().decode([RecognitionLearningData].self, from: learningDataData) {
            learningData = decodedLearningData
        }
        
        // 加载个性化偏好
        if let preferencesData = userDefaults.data(forKey: preferencesStorageKey),
           let decodedPreferences = try? JSONDecoder().decode(PersonalizedRecognitionPreference.self, from: preferencesData) {
            personalizedPreferences = decodedPreferences
        }
    }
    
    /// 保存数据
    func saveData() {
        // 保存反馈历史
        if let feedbackData = try? JSONEncoder().encode(feedbackHistory) {
            userDefaults.set(feedbackData, forKey: feedbackStorageKey)
        }
        
        // 保存学习数据
        if let learningDataData = try? JSONEncoder().encode(learningData) {
            userDefaults.set(learningDataData, forKey: learningDataStorageKey)
        }
        
        // 保存个性化偏好
        if let preferencesData = try? JSONEncoder().encode(personalizedPreferences) {
            userDefaults.set(preferencesData, forKey: preferencesStorageKey)
        }
    }
}

// MARK: - 支持结构

/// 反馈统计信息
struct FeedbackStatistics {
    let totalFeedbacks: Int
    let correctFeedbacks: Int
    let accuracyRate: Double
    let averageRating: Double
}

// MARK: - 扩展现有模型

extension PersonalizedRecognitionPreference {
    init(categoryFrequency: [ItemCategory: Int], commonCorrections: [String: String], preferredTerms: [String: String], lastUpdated: Date) {
        self.categoryFrequency = categoryFrequency
        self.commonCorrections = commonCorrections
        self.preferredTerms = preferredTerms
        self.lastUpdated = lastUpdated
    }
}