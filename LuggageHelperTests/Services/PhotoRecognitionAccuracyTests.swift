import XCTest
@testable import LuggageHelper

/// 照片识别准确度集成测试
/// 测试照片识别功能的准确度和置信度计算
class PhotoRecognitionAccuracyTests: XCTestCase {
    
    var llmService: LLMAPIService!
    var qualityManager: PhotoRecognitionQualityManager!
    var validator: RecognitionResultValidator!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        llmService = LLMAPIService.shared
        qualityManager = PhotoRecognitionQualityManager.shared
        validator = RecognitionResultValidator.shared
    }
    
    override func tearDownWithError() throws {
        llmService = nil
        qualityManager = nil
        validator = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 识别准确度测试
    
    /// 测试清晰照片的识别准确度
    func testClearPhotoRecognitionAccuracy() async throws {
        // Given
        let testImageData = createTestImageData(quality: .high, complexity: .simple)
        let expectedAccuracy = 0.85 // 需求：85%以上识别准确率
        
        // When
        let result = try await llmService.identifyItemFromPhoto(testImageData, hint: "电子产品")
        
        // Then
        XCTAssertGreaterThanOrEqual(result.confidence, expectedAccuracy, "清晰照片识别准确率应达到85%以上")
        XCTAssertNotEqual(result.category, .other, "应该能够正确分类，而不是归为其他类别")
        XCTAssertFalse(result.name.isEmpty, "应该能够识别出具体的物品名称")
    }
    
    /// 测试多物品照片的主要物品识别
    func testMultipleItemsPhotoRecognition() async throws {
        // Given
        let testImageData = createTestImageData(quality: .medium, complexity: .complex)
        
        // When
        let result = try await llmService.identifyItemFromPhoto(testImageData, hint: "包含多个物品")
        
        // Then
        XCTAssertGreaterThan(result.confidence, 0.6, "多物品照片应该能识别出主要物品")
        XCTAssertNotNil(result.dimensions, "应该提供主要物品的尺寸信息")
        
        // 验证是否正确区分了主要物品
        let qualityAssessment = qualityManager.assessRecognitionQuality(
            result: result,
            imageData: testImageData
        )
        
        if qualityAssessment.qualityIssues.contains(where: { $0 == .multipleObjects }) {
            XCTAssertGreaterThan(result.confidence, 0.5, "即使有多个物品，也应该有合理的置信度")
        }
    }
    
    /// 测试低置信度结果的处理
    func testLowConfidenceResultHandling() async throws {
        // Given
        let testImageData = createTestImageData(quality: .low, complexity: .complex)
        let confidenceThreshold = 0.7
        
        // When
        let result = try await llmService.identifyItemFromPhoto(testImageData)
        
        // Then
        if result.confidence < confidenceThreshold {
            // 验证系统是否提供了适当的建议
            let qualityAssessment = qualityManager.assessRecognitionQuality(
                result: result,
                imageData: testImageData
            )
            
            XCTAssertTrue(qualityAssessment.shouldRetry, "低置信度时应该建议重试")
            XCTAssertFalse(qualityAssessment.suggestions.isEmpty, "应该提供改进建议")
            
            // 验证是否有替代识别方案
            XCTAssertFalse(qualityAssessment.alternativeStrategies.isEmpty, "应该提供替代识别策略")
        }
    }
    
    /// 测试无法识别物品时的智能建议
    func testUnrecognizableItemSuggestions() async throws {
        // Given
        let testImageData = createTestImageData(quality: .veryLow, complexity: .veryComplex)
        
        // When
        let result = try await llmService.identifyItemFromPhoto(testImageData)
        
        // Then
        if result.confidence < 0.3 || result.category == .other {
            let qualityAssessment = qualityManager.assessRecognitionQuality(
                result: result,
                imageData: testImageData
            )
            
            // 验证智能建议
            let hasRetakePhotoSuggestion = qualityAssessment.suggestions.contains { 
                $0.type == .retakePhoto 
            }
            let hasManualInputSuggestion = qualityAssessment.suggestions.contains { 
                $0.type == .manualInput 
            }
            
            XCTAssertTrue(hasRetakePhotoSuggestion || hasManualInputSuggestion, 
                         "无法识别时应该提供重拍或手动输入建议")
        }
    }
    
    // MARK: - 多策略识别测试
    
    /// 测试多策略识别结果合并
    func testMultipleStrategyRecognition() async throws {
        // Given
        let testImageData = createTestImageData(quality: .medium, complexity: .medium)
        let strategies: [PhotoRecognitionStrategy] = [.aiVision, .textExtraction, .colorAnalysis]
        
        // When
        let result = try await llmService.identifyItemFromPhotoWithMultipleStrategies(
            testImageData,
            strategies: strategies
        )
        
        // Then
        XCTAssertNotNil(result, "多策略识别应该返回结果")
        XCTAssertEqual(result.source, "多策略合并识别", "应该标记为多策略合并结果")
        
        // 验证置信度是否合理提升
        let singleStrategyResult = try await llmService.identifyItemFromPhoto(testImageData)
        
        // 多策略结果的置信度通常应该更高或至少不低于单策略
        XCTAssertGreaterThanOrEqual(result.confidence, singleStrategyResult.confidence * 0.9,
                                   "多策略合并应该提供更可靠的结果")
    }
    
    /// 测试策略一致性评估
    func testStrategyConsistencyAssessment() async throws {
        // Given
        let testImageData = createTestImageData(quality: .high, complexity: .simple)
        let strategies: [PhotoRecognitionStrategy] = [.aiVision, .colorAnalysis, .shapeAnalysis]
        
        // When
        let result = try await llmService.identifyItemFromPhotoWithMultipleStrategies(
            testImageData,
            strategies: strategies
        )
        
        // Then
        // 如果策略结果一致，置信度应该较高
        if result.confidence > 0.8 {
            XCTAssertNotEqual(result.category, .other, "高置信度结果应该有明确的类别")
            XCTAssertGreaterThan(result.name.count, 2, "高置信度结果应该有具体的名称")
        }
        
        // 验证替代品建议的质量
        if !result.alternatives.isEmpty {
            for alternative in result.alternatives {
                XCTAssertLessThan(alternative.confidence, result.confidence, 
                                 "替代品的置信度应该低于主要结果")
            }
        }
    }
    
    // MARK: - 质量评估测试
    
    /// 测试识别质量评估
    func testRecognitionQualityAssessment() async throws {
        // Given
        let testCases = [
            (quality: ImageQuality.high, expectedScore: 0.8...1.0),
            (quality: ImageQuality.medium, expectedScore: 0.5...0.8),
            (quality: ImageQuality.low, expectedScore: 0.2...0.6)
        ]
        
        for testCase in testCases {
            // When
            let testImageData = createTestImageData(quality: testCase.quality, complexity: .medium)
            let result = try await llmService.identifyItemFromPhoto(testImageData)
            let qualityAssessment = qualityManager.assessRecognitionQuality(
                result: result,
                imageData: testImageData
            )
            
            // Then
            XCTAssertTrue(testCase.expectedScore.contains(qualityAssessment.overallScore),
                         "质量评分应该在预期范围内：\(testCase.quality)")
        }
    }
    
    /// 测试置信度阈值机制
    func testConfidenceThresholdMechanism() async throws {
        // Given
        let testImageData = createTestImageData(quality: .medium, complexity: .medium)
        
        // When
        let result = try await llmService.identifyItemFromPhoto(testImageData)
        let qualityAssessment = qualityManager.assessRecognitionQuality(
            result: result,
            imageData: testImageData
        )
        
        // Then
        switch qualityAssessment.confidenceLevel {
        case .excellent:
            XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
            XCTAssertFalse(qualityAssessment.shouldRetry)
            
        case .good:
            XCTAssertGreaterThanOrEqual(result.confidence, 0.8)
            XCTAssertFalse(qualityAssessment.shouldRetry)
            
        case .acceptable:
            XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
            
        case .poor:
            XCTAssertLessThan(result.confidence, 0.7)
            XCTAssertTrue(qualityAssessment.shouldRetry)
            
        case .unacceptable:
            XCTAssertLessThan(result.confidence, 0.3)
            XCTAssertTrue(qualityAssessment.shouldRetry)
        }
    }
    
    // MARK: - 结果验证测试
    
    /// 测试识别结果验证
    func testRecognitionResultValidation() async throws {
        // Given
        let testImageData = createTestImageData(quality: .medium, complexity: .simple)
        
        // When
        let result = try await llmService.identifyItemFromPhoto(testImageData)
        let validationResult = validator.validateResult(result, imageData: testImageData)
        
        // Then
        if validationResult.isValid {
            XCTAssertGreaterThan(validationResult.confidence, 0.5, "有效结果应该有合理的置信度")
            XCTAssertTrue(validationResult.validationIssues.filter { 
                $0.severity == .critical 
            }.isEmpty, "有效结果不应该有严重问题")
        } else {
            XCTAssertFalse(validationResult.validationIssues.isEmpty, "无效结果应该有明确的问题说明")
            XCTAssertFalse(validationResult.recommendations.isEmpty, "无效结果应该有改进建议")
        }
    }
    
    /// 测试结果筛选功能
    func testResultFiltering() async throws {
        // Given
        let testResults = [
            createMockItemInfo(confidence: 0.9, category: .electronics),
            createMockItemInfo(confidence: 0.6, category: .clothing),
            createMockItemInfo(confidence: 0.3, category: .other),
            createMockItemInfo(confidence: 0.8, category: .accessories)
        ]
        
        // When
        let filteredResults = validator.filterValidResults(testResults, minConfidence: 0.7)
        
        // Then
        XCTAssertEqual(filteredResults.count, 2, "应该筛选出2个高质量结果")
        XCTAssertTrue(filteredResults.allSatisfy { $0.confidence >= 0.7 }, 
                     "筛选结果应该都满足最小置信度要求")
        XCTAssertEqual(filteredResults.first?.confidence, 0.9, "结果应该按置信度降序排列")
    }
    
    // MARK: - 性能测试
    
    /// 测试识别性能
    func testRecognitionPerformance() async throws {
        // Given
        let testImageData = createTestImageData(quality: .medium, complexity: .medium)
        let maxProcessingTime: TimeInterval = 5.0 // 5秒内完成
        
        // When
        let startTime = Date()
        let result = try await llmService.identifyItemFromPhoto(testImageData)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(processingTime, maxProcessingTime, 
                         "识别处理时间应该在\(maxProcessingTime)秒内")
        XCTAssertNotNil(result, "应该在规定时间内返回结果")
    }
    
    /// 测试批量识别性能
    func testBatchRecognitionPerformance() async throws {
        // Given
        let testImages = (1...5).map { _ in 
            createTestImageData(quality: .medium, complexity: .simple) 
        }
        let maxAverageTime: TimeInterval = 3.0 // 平均3秒每张
        
        // When
        let startTime = Date()
        var results: [ItemInfo] = []
        
        for imageData in testImages {
            let result = try await llmService.identifyItemFromPhoto(imageData)
            results.append(result)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(testImages.count)
        
        // Then
        XCTAssertLessThan(averageTime, maxAverageTime, 
                         "批量识别平均时间应该在\(maxAverageTime)秒内")
        XCTAssertEqual(results.count, testImages.count, "应该处理所有图片")
    }
    
    // MARK: - 辅助方法
    
    /// 图片质量枚举
    enum ImageQuality {
        case veryLow, low, medium, high
    }
    
    /// 图片复杂度枚举
    enum ImageComplexity {
        case simple, medium, complex, veryComplex
    }
    
    /// 创建测试图片数据
    private func createTestImageData(quality: ImageQuality, complexity: ImageComplexity) -> Data {
        // 根据质量和复杂度生成不同大小的测试数据
        let baseSize: Int
        
        switch quality {
        case .veryLow:
            baseSize = 1024 // 1KB
        case .low:
            baseSize = 10 * 1024 // 10KB
        case .medium:
            baseSize = 50 * 1024 // 50KB
        case .high:
            baseSize = 200 * 1024 // 200KB
        }
        
        let complexityMultiplier: Double
        switch complexity {
        case .simple:
            complexityMultiplier = 0.5
        case .medium:
            complexityMultiplier = 1.0
        case .complex:
            complexityMultiplier = 1.5
        case .veryComplex:
            complexityMultiplier = 2.0
        }
        
        let finalSize = Int(Double(baseSize) * complexityMultiplier)
        return Data(count: finalSize)
    }
    
    /// 创建模拟物品信息
    private func createMockItemInfo(confidence: Double, category: ItemCategory) -> ItemInfo {
        return ItemInfo(
            name: "测试物品",
            category: category,
            weight: 100.0,
            volume: 100.0,
            dimensions: Dimensions(length: 10, width: 10, height: 1),
            confidence: confidence,
            source: "测试数据"
        )
    }
}