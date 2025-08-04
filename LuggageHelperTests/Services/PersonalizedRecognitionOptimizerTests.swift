//
//  PersonalizedRecognitionOptimizerTests.swift
//  LuggageHelperTests
//
//  Created by Kiro on 2025/7/28.
//

import XCTest
@testable import LuggageHelper

@MainActor
final class PersonalizedRecognitionOptimizerTests: XCTestCase {
    
    var feedbackManager: UserFeedbackManager!
    var optimizer: PersonalizedRecognitionOptimizer!
    var sampleRecognitionResult: PhotoRecognitionResult!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 清除UserDefaults中的测试数据
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "UserFeedbackHistory")
        userDefaults.removeObject(forKey: "RecognitionLearningData")
        userDefaults.removeObject(forKey: "PersonalizedRecognitionPreferences")
        userDefaults.removeObject(forKey: "PersonalizedOptimizationData")
        
        feedbackManager = UserFeedbackManager()
        optimizer = PersonalizedRecognitionOptimizer(feedbackManager: feedbackManager)
        
        // 创建示例识别结果
        let itemInfo = ItemInfo(
            name: "iPhone 15",
            category: .electronics,
            weight: 171.0,
            volume: 100.0,
            confidence: 0.75
        )
        
        sampleRecognitionResult = PhotoRecognitionResult(
            primaryResult: itemInfo,
            alternativeResults: [],
            confidence: 0.75,
            usedStrategies: [.aiVision],
            processingTime: 2.3
        )
    }
    
    override func tearDown() async throws {
        feedbackManager = nil
        optimizer = nil
        sampleRecognitionResult = nil
        try await super.tearDown()
    }
    
    // MARK: - 基础优化测试
    
    func testBasicOptimization() async throws {
        // Given
        let imageHash = "test_hash_123"
        
        // When
        let optimizedResult = await optimizer.optimizeRecognitionResult(
            sampleRecognitionResult,
            imageHash: imageHash
        )
        
        // Then
        XCTAssertNotNil(optimizedResult)
        XCTAssertEqual(optimizedResult.primaryResult.name, sampleRecognitionResult.primaryResult.name)
        XCTAssertGreaterThanOrEqual(optimizedResult.confidence, sampleRecognitionResult.confidence)
    }
    
    func testOptimizationWithUserCorrections() async throws {
        // Given - 先建立用户修正历史
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            correctedCategory: .electronics,
            rating: 4
        )
        
        await feedbackManager.submitFeedback(feedback)
        await feedbackManager.createLearningData(
            imageHash: "test_hash",
            originalResult: sampleRecognitionResult,
            userFeedback: feedback
        )
        
        // When
        let optimizedResult = await optimizer.optimizeRecognitionResult(
            sampleRecognitionResult,
            imageHash: "test_hash_123"
        )
        
        // Then
        XCTAssertGreaterThan(optimizedResult.confidence, sampleRecognitionResult.confidence)
    }
    
    func testOptimizationWithCategoryPreferences() async throws {
        // Given - 建立类别偏好
        for _ in 0..<15 {
            let feedback = UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: false,
                correctedCategory: .electronics,
                rating: 4
            )
            await feedbackManager.submitFeedback(feedback)
        }
        
        // When
        let optimizedResult = await optimizer.optimizeRecognitionResult(
            sampleRecognitionResult,
            imageHash: "test_hash_123"
        )
        
        // Then
        XCTAssertGreaterThan(optimizedResult.confidence, sampleRecognitionResult.confidence)
    }
    
    // MARK: - 个性化建议测试
    
    func testGetPersonalizedSuggestions() async throws {
        // Given - 建立使用模式
        for _ in 0..<10 {
            let feedback = UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: false,
                correctedCategory: .electronics,
                rating: 4
            )
            await feedbackManager.submitFeedback(feedback)
            await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        }
        
        let context = RecognitionContext(
            originalName: "iPhone 15",
            category: .electronics,
            timestamp: Date(),
            imageHash: "test_hash"
        )
        
        // When
        let suggestions = optimizer.getPersonalizedSuggestions(for: .electronics, context: context)
        
        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.allSatisfy { $0.confidence > 0 })
    }
    
    func testSuggestionsWithCommonCorrections() async throws {
        // Given - 建立常见修正
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            rating: 4
        )
        
        await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        
        let context = RecognitionContext(
            originalName: "iPhone 15",
            category: .electronics,
            timestamp: Date(),
            imageHash: "test_hash"
        )
        
        // When
        let suggestions = optimizer.getPersonalizedSuggestions(for: .electronics, context: context)
        
        // Then
        let correctionSuggestion = suggestions.first { $0.type == .commonCorrection }
        XCTAssertNotNil(correctionSuggestion)
        XCTAssertTrue(correctionSuggestion?.message.contains("MacBook Pro") == true)
    }
    
    // MARK: - 学习功能测试
    
    func testLearnFromPositiveFeedback() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: true,
            rating: 5,
            comments: "识别正确"
        )
        
        let initialData = optimizer.optimizationData
        
        // When
        await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        
        // Then
        XCTAssertNotEqual(optimizer.optimizationData.lastUpdated, initialData.lastUpdated)
    }
    
    func testLearnFromNegativeFeedback() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            correctedCategory: .electronics,
            rating: 2,
            comments: "识别错误"
        )
        
        // When
        await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        
        // Then
        XCTAssertEqual(optimizer.optimizationData.categoryUsageFrequency[.electronics], 1)
        XCTAssertEqual(optimizer.optimizationData.correctionPatterns["iPhone 15"], "MacBook Pro")
    }
    
    func testLearnFromMultipleFeedbacks() async throws {
        // Given
        let feedbacks = [
            UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: false,
                correctedCategory: .electronics,
                rating: 4
            ),
            UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: false,
                correctedCategory: .electronics,
                rating: 3
            ),
            UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: false,
                correctedCategory: .clothing,
                rating: 5
            )
        ]
        
        // When
        for feedback in feedbacks {
            await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        }
        
        // Then
        XCTAssertEqual(optimizer.optimizationData.categoryUsageFrequency[.electronics], 2)
        XCTAssertEqual(optimizer.optimizationData.categoryUsageFrequency[.clothing], 1)
    }
    
    // MARK: - 置信度调整测试
    
    func testConfidenceAdjustmentForCorrectResults() async throws {
        // Given - 低置信度但正确的结果
        let lowConfidenceResult = PhotoRecognitionResult(
            primaryResult: sampleRecognitionResult.primaryResult,
            alternativeResults: [],
            confidence: 0.6,
            usedStrategies: [.aiVision],
            processingTime: 2.0
        )
        
        let feedback = UserFeedback(
            recognitionResultId: lowConfidenceResult.id,
            isCorrect: true,
            rating: 5
        )
        
        // When
        await optimizer.learnFromFeedback(feedback, originalResult: lowConfidenceResult)
        
        // Then
        let adjustmentFactor = optimizer.optimizationData.confidenceAdjustmentFactors[.electronics]
        XCTAssertNotNil(adjustmentFactor)
        XCTAssertGreaterThan(adjustmentFactor!, 1.0)
    }
    
    func testConfidenceAdjustmentForIncorrectResults() async throws {
        // Given - 高置信度但错误的结果
        let highConfidenceResult = PhotoRecognitionResult(
            primaryResult: sampleRecognitionResult.primaryResult,
            alternativeResults: [],
            confidence: 0.9,
            usedStrategies: [.aiVision],
            processingTime: 2.0
        )
        
        let feedback = UserFeedback(
            recognitionResultId: highConfidenceResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            rating: 2
        )
        
        // When
        await optimizer.learnFromFeedback(feedback, originalResult: highConfidenceResult)
        
        // Then
        let adjustmentFactor = optimizer.optimizationData.confidenceAdjustmentFactors[.electronics]
        XCTAssertNotNil(adjustmentFactor)
        XCTAssertLessThan(adjustmentFactor!, 1.0)
    }
    
    // MARK: - 时间模式测试
    
    func testTimePatternLearning() async throws {
        // Given - 在特定时间提交反馈
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedCategory: .electronics,
            rating: 4
        )
        
        // When
        await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        
        // Then
        let timeKey = "\(ItemCategory.electronics.rawValue)_\(hour)"
        let timePattern = optimizer.optimizationData.timePatterns[timeKey]
        XCTAssertEqual(timePattern, 1)
    }
    
    // MARK: - 统计信息测试
    
    func testOptimizationStatistics() async throws {
        // Given - 进行一些优化操作
        let imageHash = "test_hash_123"
        
        await optimizer.optimizeRecognitionResult(sampleRecognitionResult, imageHash: imageHash)
        await optimizer.optimizeRecognitionResult(sampleRecognitionResult, imageHash: imageHash)
        
        // When
        let statistics = optimizer.getOptimizationStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalOptimizations, 2)
        XCTAssertGreaterThanOrEqual(statistics.successRate, 0.0)
        XCTAssertLessThanOrEqual(statistics.successRate, 1.0)
    }
    
    func testEmptyOptimizationStatistics() async throws {
        // When
        let statistics = optimizer.getOptimizationStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalOptimizations, 0)
        XCTAssertEqual(statistics.successfulOptimizations, 0)
        XCTAssertEqual(statistics.successRate, 0.0)
        XCTAssertEqual(statistics.averageImprovement, 0.0)
        XCTAssertNil(statistics.mostOptimizedCategory)
        XCTAssertNil(statistics.lastOptimization)
    }
    
    // MARK: - 数据重置测试
    
    func testResetPersonalizationData() async throws {
        // Given - 先建立一些数据
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedCategory: .electronics,
            rating: 4
        )
        
        await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        
        XCTAssertFalse(optimizer.optimizationData.categoryUsageFrequency.isEmpty)
        
        // When
        optimizer.resetPersonalizationData()
        
        // Then
        XCTAssertTrue(optimizer.optimizationData.categoryUsageFrequency.isEmpty)
        XCTAssertTrue(optimizer.optimizationData.correctionPatterns.isEmpty)
        XCTAssertTrue(optimizer.optimizationData.timePatterns.isEmpty)
        XCTAssertTrue(optimizer.optimizationData.confidenceAdjustmentFactors.isEmpty)
        XCTAssertTrue(optimizer.optimizationData.optimizationHistory.isEmpty)
    }
    
    // MARK: - 数据持久化测试
    
    func testDataPersistence() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedCategory: .electronics,
            rating: 4
        )
        
        await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        
        // When - 创建新的优化器实例（模拟应用重启）
        let newOptimizer = PersonalizedRecognitionOptimizer(feedbackManager: feedbackManager)
        
        // Then
        XCTAssertEqual(
            newOptimizer.optimizationData.categoryUsageFrequency[.electronics],
            optimizer.optimizationData.categoryUsageFrequency[.electronics]
        )
    }
    
    // MARK: - 性能测试
    
    func testOptimizationPerformance() async throws {
        // Given
        let imageHash = "test_hash_performance"
        
        // When
        let startTime = Date()
        
        for _ in 0..<50 {
            _ = await optimizer.optimizeRecognitionResult(sampleRecognitionResult, imageHash: imageHash)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(processingTime, 10.0) // 应该在10秒内完成50次优化
    }
    
    func testLearningPerformance() async throws {
        // Given
        let feedbacks = (0..<100).map { index in
            UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: index % 2 == 0,
                correctedCategory: index % 2 == 0 ? .electronics : .clothing,
                rating: (index % 5) + 1
            )
        }
        
        // When
        let startTime = Date()
        
        for feedback in feedbacks {
            await optimizer.learnFromFeedback(feedback, originalResult: sampleRecognitionResult)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(processingTime, 5.0) // 应该在5秒内完成100次学习
    }
    
    // MARK: - 边界条件测试
    
    func testOptimizationWithMaxConfidence() async throws {
        // Given - 已经是最高置信度的结果
        let maxConfidenceResult = PhotoRecognitionResult(
            primaryResult: sampleRecognitionResult.primaryResult,
            alternativeResults: [],
            confidence: 1.0,
            usedStrategies: [.aiVision],
            processingTime: 2.0
        )
        
        // When
        let optimizedResult = await optimizer.optimizeRecognitionResult(
            maxConfidenceResult,
            imageHash: "test_hash"
        )
        
        // Then
        XCTAssertEqual(optimizedResult.confidence, 1.0) // 不应该超过1.0
    }
    
    func testOptimizationWithMinConfidence() async throws {
        // Given - 最低置信度的结果
        let minConfidenceResult = PhotoRecognitionResult(
            primaryResult: sampleRecognitionResult.primaryResult,
            alternativeResults: [],
            confidence: 0.0,
            usedStrategies: [.aiVision],
            processingTime: 2.0
        )
        
        // When
        let optimizedResult = await optimizer.optimizeRecognitionResult(
            minConfidenceResult,
            imageHash: "test_hash"
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(optimizedResult.confidence, 0.0) // 不应该小于0.0
    }
}