//
//  UserFeedbackManagerTests.swift
//  LuggageHelperTests
//
//  Created by Kiro on 2025/7/28.
//

import XCTest
@testable import LuggageHelper

@MainActor
final class UserFeedbackManagerTests: XCTestCase {
    
    var feedbackManager: UserFeedbackManager!
    var sampleRecognitionResult: PhotoRecognitionResult!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 清除UserDefaults中的测试数据
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "UserFeedbackHistory")
        userDefaults.removeObject(forKey: "RecognitionLearningData")
        userDefaults.removeObject(forKey: "PersonalizedRecognitionPreferences")
        
        feedbackManager = UserFeedbackManager()
        
        // 创建示例识别结果
        let itemInfo = ItemInfo(
            name: "iPhone 15",
            category: .electronics,
            weight: 171.0,
            volume: 100.0,
            confidence: 0.85
        )
        
        sampleRecognitionResult = PhotoRecognitionResult(
            primaryResult: itemInfo,
            alternativeResults: [],
            confidence: 0.85,
            usedStrategies: [.aiVision],
            processingTime: 2.3
        )
    }
    
    override func tearDown() async throws {
        feedbackManager = nil
        sampleRecognitionResult = nil
        try await super.tearDown()
    }
    
    // MARK: - 反馈提交测试
    
    func testSubmitPositiveFeedback() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: true,
            rating: 5,
            comments: "识别很准确！"
        )
        
        // When
        await feedbackManager.submitFeedback(feedback)
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 1)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.isCorrect, true)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.rating, 5)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.comments, "识别很准确！")
    }
    
    func testSubmitNegativeFeedback() async throws {
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
        await feedbackManager.submitFeedback(feedback)
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 1)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.isCorrect, false)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.correctedName, "MacBook Pro")
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.correctedCategory, .electronics)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.rating, 2)
    }
    
    func testMultipleFeedbackSubmissions() async throws {
        // Given
        let feedback1 = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: true,
            rating: 4
        )
        
        let feedback2 = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: false,
            correctedName: "iPad",
            correctedCategory: .electronics,
            rating: 3
        )
        
        // When
        await feedbackManager.submitFeedback(feedback1)
        await feedbackManager.submitFeedback(feedback2)
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 2)
    }
    
    // MARK: - 学习数据创建测试
    
    func testCreateLearningData() async throws {
        // Given
        let imageHash = "test_hash_123"
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            correctedCategory: .electronics,
            rating: 3
        )
        
        // When
        await feedbackManager.createLearningData(
            imageHash: imageHash,
            originalResult: sampleRecognitionResult,
            userFeedback: feedback
        )
        
        // Then
        XCTAssertEqual(feedbackManager.learningData.count, 1)
        
        let learningData = feedbackManager.learningData.first!
        XCTAssertEqual(learningData.imageHash, imageHash)
        XCTAssertEqual(learningData.originalResult.id, sampleRecognitionResult.id)
        XCTAssertEqual(learningData.userFeedback.id, feedback.id)
        XCTAssertGreaterThan(learningData.learningWeight, 0)
    }
    
    func testLearningDataWithHighRating() async throws {
        // Given
        let imageHash = "test_hash_456"
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            correctedCategory: .electronics,
            rating: 5,
            comments: "详细的反馈"
        )
        
        // When
        await feedbackManager.createLearningData(
            imageHash: imageHash,
            originalResult: sampleRecognitionResult,
            userFeedback: feedback
        )
        
        // Then
        let learningData = feedbackManager.learningData.first!
        XCTAssertGreaterThan(learningData.learningWeight, 1.0) // 高评分应该有更高的权重
    }
    
    // MARK: - 个性化偏好测试
    
    func testUpdatePersonalizedPreferences() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            correctedCategory: .electronics,
            rating: 4
        )
        
        // When
        await feedbackManager.submitFeedback(feedback)
        
        // Then
        let frequency = feedbackManager.personalizedPreferences.categoryFrequency[.electronics]
        XCTAssertEqual(frequency, 1)
        
        let correction = feedbackManager.personalizedPreferences.commonCorrections["iPhone 15"]
        XCTAssertEqual(correction, "MacBook Pro")
    }
    
    func testMultipleCategoryUpdates() async throws {
        // Given
        let feedback1 = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: false,
            correctedCategory: .electronics,
            rating: 4
        )
        
        let feedback2 = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: false,
            correctedCategory: .electronics,
            rating: 3
        )
        
        let feedback3 = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: false,
            correctedCategory: .clothing,
            rating: 5
        )
        
        // When
        await feedbackManager.submitFeedback(feedback1)
        await feedbackManager.submitFeedback(feedback2)
        await feedbackManager.submitFeedback(feedback3)
        
        // Then
        XCTAssertEqual(feedbackManager.personalizedPreferences.categoryFrequency[.electronics], 2)
        XCTAssertEqual(feedbackManager.personalizedPreferences.categoryFrequency[.clothing], 1)
    }
    
    // MARK: - 个性化建议测试
    
    func testGetPersonalizedSuggestions() async throws {
        // Given - 先提交一些反馈来建立偏好
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
        let suggestions = feedbackManager.getPersonalizedSuggestions(for: .electronics)
        
        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.first?.contains("电子产品") == true)
    }
    
    func testGetCommonCorrections() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "MacBook Pro",
            rating: 4
        )
        
        await feedbackManager.submitFeedback(feedback)
        
        // 创建学习数据以建立修正关系
        await feedbackManager.createLearningData(
            imageHash: "test_hash",
            originalResult: sampleRecognitionResult,
            userFeedback: feedback
        )
        
        // When
        let correction = feedbackManager.getCommonCorrections(for: "iPhone 15")
        
        // Then
        XCTAssertEqual(correction, "MacBook Pro")
    }
    
    // MARK: - 反馈统计测试
    
    func testGetFeedbackStatistics() async throws {
        // Given
        let correctFeedback = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: true,
            rating: 5
        )
        
        let incorrectFeedback = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: false,
            rating: 2
        )
        
        await feedbackManager.submitFeedback(correctFeedback)
        await feedbackManager.submitFeedback(incorrectFeedback)
        
        // When
        let statistics = feedbackManager.getFeedbackStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalFeedbacks, 2)
        XCTAssertEqual(statistics.correctFeedbacks, 1)
        XCTAssertEqual(statistics.accuracyRate, 0.5, accuracy: 0.01)
        XCTAssertEqual(statistics.averageRating, 3.5, accuracy: 0.01)
    }
    
    func testEmptyFeedbackStatistics() async throws {
        // When
        let statistics = feedbackManager.getFeedbackStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalFeedbacks, 0)
        XCTAssertEqual(statistics.correctFeedbacks, 0)
        XCTAssertEqual(statistics.accuracyRate, 0.0)
        XCTAssertEqual(statistics.averageRating, 0.0)
    }
    
    // MARK: - 数据清除测试
    
    func testClearFeedbackHistory() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: true,
            rating: 5
        )
        
        await feedbackManager.submitFeedback(feedback)
        await feedbackManager.createLearningData(
            imageHash: "test_hash",
            originalResult: sampleRecognitionResult,
            userFeedback: feedback
        )
        
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 1)
        XCTAssertEqual(feedbackManager.learningData.count, 1)
        
        // When
        feedbackManager.clearFeedbackHistory()
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 0)
        XCTAssertEqual(feedbackManager.learningData.count, 0)
        XCTAssertEqual(feedbackManager.personalizedPreferences.categoryFrequency.count, 0)
    }
    
    // MARK: - 数据持久化测试
    
    func testDataPersistence() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: true,
            rating: 4,
            comments: "测试持久化"
        )
        
        await feedbackManager.submitFeedback(feedback)
        
        // When - 创建新的管理器实例（模拟应用重启）
        let newFeedbackManager = UserFeedbackManager()
        
        // Then
        XCTAssertEqual(newFeedbackManager.feedbackHistory.count, 1)
        XCTAssertEqual(newFeedbackManager.feedbackHistory.first?.comments, "测试持久化")
    }
    
    // MARK: - 性能测试
    
    func testPerformanceOfMultipleFeedbacks() async throws {
        // Given
        let feedbacks = (0..<100).map { index in
            UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: index % 2 == 0,
                rating: (index % 5) + 1
            )
        }
        
        // When
        let startTime = Date()
        
        for feedback in feedbacks {
            await feedbackManager.submitFeedback(feedback)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 100)
        XCTAssertLessThan(processingTime, 5.0) // 应该在5秒内完成
    }
    
    // MARK: - 边界条件测试
    
    func testFeedbackWithEmptyStrings() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: false,
            correctedName: "",
            rating: 3,
            comments: ""
        )
        
        // When
        await feedbackManager.submitFeedback(feedback)
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 1)
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.correctedName, "")
        XCTAssertEqual(feedbackManager.feedbackHistory.first?.comments, "")
    }
    
    func testFeedbackWithNilValues() async throws {
        // Given
        let feedback = UserFeedback(
            recognitionResultId: sampleRecognitionResult.id,
            isCorrect: true,
            correctedName: nil,
            correctedCategory: nil,
            rating: 3,
            comments: nil
        )
        
        // When
        await feedbackManager.submitFeedback(feedback)
        
        // Then
        XCTAssertEqual(feedbackManager.feedbackHistory.count, 1)
        XCTAssertNil(feedbackManager.feedbackHistory.first?.correctedName)
        XCTAssertNil(feedbackManager.feedbackHistory.first?.correctedCategory)
        XCTAssertNil(feedbackManager.feedbackHistory.first?.comments)
    }
    
    func testExtremeRatingValues() async throws {
        // Given
        let lowRatingFeedback = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: false,
            rating: 1
        )
        
        let highRatingFeedback = UserFeedback(
            recognitionResultId: UUID(),
            isCorrect: true,
            rating: 5
        )
        
        // When
        await feedbackManager.submitFeedback(lowRatingFeedback)
        await feedbackManager.submitFeedback(highRatingFeedback)
        
        // Then
        let statistics = feedbackManager.getFeedbackStatistics()
        XCTAssertEqual(statistics.averageRating, 3.0, accuracy: 0.01)
    }
}