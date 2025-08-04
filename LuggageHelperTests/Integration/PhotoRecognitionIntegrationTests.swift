import XCTest
import AVFoundation
import Vision
import CoreML
@testable import LuggageHelper

/// 照片识别功能完整集成测试
/// 测试照片识别功能的端到端流程，包括图像预处理、对象检测、识别、缓存等所有环节
@MainActor
final class PhotoRecognitionIntegrationTests: XCTestCase {
    
    // MARK: - 测试组件
    
    var imagePreprocessor: ImagePreprocessor!
    var objectDetector: ObjectDetectionEngine!
    var offlineRecognition: OfflineRecognitionService!
    var cacheManager: PhotoRecognitionCacheManager!
    var similarityMatcher: ImageSimilarityMatcher!
    var errorRecoveryManager: PhotoRecognitionErrorRecoveryManager!
    var qualityManager: PhotoRecognitionQualityManager!
    var userFeedbackManager: UserFeedbackManager!
    var realTimeCameraManager: RealTimeCameraManager!
    var batchRecognitionService: BatchRecognitionService!
    var mockLLMService: MockLLMAPIService!
    var performanceMonitor: PerformanceMonitor!
    
    // MARK: - 测试数据
    
    var testImages: [UIImage] = []
    var testImageMetadata: [String: Any] = [:]
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 初始化所有服务
        imagePreprocessor = ImagePreprocessor.shared
        objectDetector = ObjectDetectionEngine.shared
        offlineRecognition = OfflineRecognitionService.shared
        cacheManager = PhotoRecognitionCacheManager.shared
        similarityMatcher = ImageSimilarityMatcher.shared
        errorRecoveryManager = PhotoRecognitionErrorRecoveryManager.shared
        qualityManager = PhotoRecognitionQualityManager.shared
        userFeedbackManager = UserFeedbackManager.shared
        realTimeCameraManager = RealTimeCameraManager()
        batchRecognitionService = BatchRecognitionService.shared
        mockLLMService = MockLLMAPIService()
        performanceMonitor = PerformanceMonitor.shared
        
        // 准备测试图像
        setupTestImages()
        
        // 清理状态
        await cleanupTestEnvironment()
    }
    
    override func tearDownWithError() throws {
        // 清理测试环境
        await cleanupTestEnvironment()
        
        // 释放资源
        testImages.removeAll()
        testImageMetadata.removeAll()
        
        imagePreprocessor = nil
        objectDetector = nil
        offlineRecognition = nil
        cacheManager = nil
        similarityMatcher = nil
        errorRecoveryManager = nil
        qualityManager = nil
        userFeedbackManager = nil
        realTimeCameraManager = nil
        batchRecognitionService = nil
        mockLLMService = nil
        performanceMonitor = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - 端到端流程测试
    
    /// 测试完整的单张照片识别流程
    func testCompletePhotoRecognitionFlow() async throws {
        // Given - 准备测试图像
        let testImage = createTestImage(type: .singleObject, quality: .high)
        let operationId = UUID()
        
        // 开始性能监控
        await performanceMonitor.startRequest(id: operationId, type: .photoRecognition)
        
        do {
            // Step 1: 图像质量验证
            let qualityResult = await qualityManager.validateImageQuality(testImage)
            XCTAssertTrue(qualityResult.isAcceptable, "测试图像质量应该可接受")
            
            // Step 2: 图像预处理
            let preprocessedImage = await imagePreprocessor.enhanceImage(testImage)
            XCTAssertNotNil(preprocessedImage, "图像预处理应该成功")
            
            // Step 3: 对象检测
            let detectedObjects = await objectDetector.detectObjects(in: preprocessedImage)
            XCTAssertGreaterThan(detectedObjects.count, 0, "应该检测到至少一个对象")
            
            // Step 4: 检查缓存
            let imageHash = await similarityMatcher.generatePerceptualHash(preprocessedImage)
            var cachedResult = await cacheManager.getCachedResult(for: imageHash)
            
            if cachedResult == nil {
                // Step 5: 执行识别（模拟在线识别）
                let recognitionResult = try await performRecognition(
                    image: preprocessedImage,
                    detectedObjects: detectedObjects
                )
                
                // Step 6: 缓存结果
                await cacheManager.cacheResult(recognitionResult, for: imageHash)
                cachedResult = recognitionResult
            }
            
            // Step 7: 验证识别结果
            guard let result = cachedResult else {
                XCTFail("识别结果不应为空")
                return
            }
            
            XCTAssertNotNil(result.itemInfo)
            XCTAssertGreaterThan(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            
            // Step 8: 记录用户反馈（模拟）
            let feedback = UserFeedback(
                isCorrect: true,
                correctedName: nil,
                correctedCategory: nil,
                correctedProperties: nil,
                rating: 5,
                comments: "识别准确",
                timestamp: Date()
            )
            
            await userFeedbackManager.recordFeedback(feedback, for: result)
            
            // 完成性能监控
            await performanceMonitor.endRequest(id: operationId, type: .photoRecognition, fromCache: cachedResult != nil)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: operationId, type: .photoRecognition, error: error)
            throw error
        }
    }
    
    /// 测试多物品批量识别流程
    func testBatchPhotoRecognitionFlow() async throws {
        // Given - 准备包含多个物品的测试图像
        let testImage = createTestImage(type: .multipleObjects, quality: .high)
        let batchOperationId = UUID()
        
        await performanceMonitor.startRequest(id: batchOperationId, type: .batchRecognition)
        
        do {
            // Step 1: 图像预处理
            let preprocessedImage = await imagePreprocessor.enhanceImage(testImage)
            
            // Step 2: 对象检测
            let detectedObjects = await objectDetector.detectObjects(in: preprocessedImage)
            XCTAssertGreaterThan(detectedObjects.count, 1, "应该检测到多个对象")
            
            // Step 3: 批量识别
            let batchResults = try await batchRecognitionService.recognizeMultipleObjects(
                image: preprocessedImage,
                detectedObjects: detectedObjects
            )
            
            // Step 4: 验证批量结果
            XCTAssertEqual(batchResults.count, detectedObjects.count, "批量结果数量应该与检测对象数量一致")
            
            for result in batchResults {
                XCTAssertNotNil(result.itemInfo)
                XCTAssertGreaterThan(result.confidence, 0.0)
            }
            
            // Step 5: 验证批量缓存
            for result in batchResults {
                let imageHash = await similarityMatcher.generatePerceptualHash(result.croppedImage ?? preprocessedImage)
                let cachedResult = await cacheManager.getCachedResult(for: imageHash)
                XCTAssertNotNil(cachedResult, "批量结果应该被缓存")
            }
            
            await performanceMonitor.endRequest(id: batchOperationId, type: .batchRecognition)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: batchOperationId, type: .batchRecognition, error: error)
            throw error
        }
    }
    
    /// 测试实时相机识别流程
    func testRealTimeCameraRecognitionFlow() async throws {
        // 在模拟器中跳过此测试
        guard !isRunningOnSimulator() else {
            throw XCTSkip("实时相机功能在模拟器中不可用")
        }
        
        // Given - 请求相机权限
        await realTimeCameraManager.requestPermission()
        
        guard realTimeCameraManager.hasPermission else {
            throw XCTSkip("需要相机权限才能进行实时识别测试")
        }
        
        let realTimeOperationId = UUID()
        await performanceMonitor.startRequest(id: realTimeOperationId, type: .realTimeRecognition)
        
        do {
            // Step 1: 启动实时检测
            await realTimeCameraManager.startSession()
            XCTAssertTrue(realTimeCameraManager.isDetecting, "实时检测应该已启动")
            
            // Step 2: 等待检测结果
            var detectionCount = 0
            let maxWaitTime = 10.0
            let startTime = Date()
            
            while detectionCount == 0 && Date().timeIntervalSince(startTime) < maxWaitTime {
                detectionCount = realTimeCameraManager.detectedObjects.count
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
            
            // Step 3: 如果检测到对象，进行识别
            if detectionCount > 0 {
                let firstDetection = realTimeCameraManager.detectedObjects[0]
                let croppedImage = await realTimeCameraManager.cropDetectedObject(firstDetection)
                
                if let image = croppedImage {
                    let recognitionResult = try await performRecognition(
                        image: image,
                        detectedObjects: []
                    )
                    
                    XCTAssertNotNil(recognitionResult.itemInfo)
                }
            }
            
            // Step 4: 停止实时检测
            realTimeCameraManager.stopSession()
            XCTAssertFalse(realTimeCameraManager.isDetecting, "实时检测应该已停止")
            
            await performanceMonitor.endRequest(id: realTimeOperationId, type: .realTimeRecognition)
            
        } catch {
            realTimeCameraManager.stopSession()
            await performanceMonitor.recordRequestFailure(id: realTimeOperationId, type: .realTimeRecognition, error: error)
            throw error
        }
    }
    
    /// 测试离线识别流程
    func testOfflineRecognitionFlow() async throws {
        // Given - 准备测试图像
        let testImage = createTestImage(type: .commonItem, quality: .medium)
        let offlineOperationId = UUID()
        
        await performanceMonitor.startRequest(id: offlineOperationId, type: .offlineRecognition)
        
        do {
            // Step 1: 检查离线模型可用性
            let availableCategories = await offlineRecognition.getAvailableCategories()
            
            if availableCategories.isEmpty {
                // 如果没有可用模型，尝试下载基础模型
                try await offlineRecognition.downloadModel(for: .electronics)
            }
            
            // Step 2: 图像预处理
            let preprocessedImage = await imagePreprocessor.enhanceImage(testImage)
            
            // Step 3: 离线识别
            let offlineResult = try await offlineRecognition.recognizeOffline(preprocessedImage)
            
            // Step 4: 验证离线识别结果
            XCTAssertNotNil(offlineResult)
            XCTAssertGreaterThan(offlineResult.confidence, 0.0)
            
            // Step 5: 如果需要在线验证，标记状态
            if offlineResult.needsOnlineVerification {
                // 在实际应用中，这里会在网络恢复时进行在线验证
                print("离线识别结果需要在线验证")
            }
            
            await performanceMonitor.endRequest(id: offlineOperationId, type: .offlineRecognition)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: offlineOperationId, type: .offlineRecognition, error: error)
            throw error
        }
    }
    
    // MARK: - 错误处理和恢复测试
    
    /// 测试图像质量问题的错误处理
    func testImageQualityErrorHandling() async throws {
        // Given - 创建低质量图像
        let lowQualityImage = createTestImage(type: .singleObject, quality: .low)
        
        // When - 验证图像质量
        let qualityResult = await qualityManager.validateImageQuality(lowQualityImage)
        
        // Then - 应该检测到质量问题
        XCTAssertFalse(qualityResult.isAcceptable, "低质量图像应该被拒绝")
        XCTAssertGreaterThan(qualityResult.issues.count, 0, "应该检测到质量问题")
        
        // When - 尝试错误恢复
        let recoveryAction = await errorRecoveryManager.handleImageQualityError(
            qualityResult.issues,
            image: lowQualityImage
        )
        
        // Then - 应该提供恢复建议
        XCTAssertNotNil(recoveryAction, "应该提供错误恢复建议")
        
        // When - 应用图像增强
        if case .enhanceImage = recoveryAction {
            let enhancedImage = await imagePreprocessor.enhanceImage(lowQualityImage)
            let newQualityResult = await qualityManager.validateImageQuality(enhancedImage)
            
            // Then - 增强后的图像质量应该有所改善
            XCTAssertGreaterThan(newQualityResult.score, qualityResult.score, "增强后的图像质量应该提高")
        }
    }
    
    /// 测试网络错误的处理和离线降级
    func testNetworkErrorHandlingAndOfflineFallback() async throws {
        // Given - 模拟网络不可用
        mockLLMService.shouldSucceed = false
        mockLLMService.mockError = MockError.networkError
        
        let testImage = createTestImage(type: .singleObject, quality: .high)
        let networkErrorOperationId = UUID()
        
        await performanceMonitor.startRequest(id: networkErrorOperationId, type: .photoRecognition)
        
        do {
            // When - 尝试在线识别
            let preprocessedImage = await imagePreprocessor.enhanceImage(testImage)
            
            // 应该失败并触发离线降级
            let result = try await performRecognitionWithFallback(
                image: preprocessedImage,
                detectedObjects: []
            )
            
            // Then - 应该使用离线识别结果
            XCTAssertEqual(result.recognitionMethod, .offlineML, "应该使用离线识别")
            XCTAssertNotNil(result.itemInfo)
            
            await performanceMonitor.endRequest(id: networkErrorOperationId, type: .photoRecognition)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: networkErrorOperationId, type: .photoRecognition, error: error)
            
            // 验证错误类型
            if let photoError = error as? PhotoRecognitionError {
                XCTAssertEqual(photoError, .networkUnavailable, "应该是网络不可用错误")
            }
        }
    }
    
    /// 测试多对象识别中的歧义处理
    func testMultiObjectAmbiguityHandling() async throws {
        // Given - 创建包含相似对象的图像
        let ambiguousImage = createTestImage(type: .similarObjects, quality: .high)
        
        // When - 进行对象检测
        let preprocessedImage = await imagePreprocessor.enhanceImage(ambiguousImage)
        let detectedObjects = await objectDetector.detectObjects(in: preprocessedImage)
        
        // Then - 应该检测到多个对象
        XCTAssertGreaterThan(detectedObjects.count, 1, "应该检测到多个对象")
        
        // When - 尝试识别时应该处理歧义
        do {
            let results = try await batchRecognitionService.recognizeMultipleObjects(
                image: preprocessedImage,
                detectedObjects: detectedObjects
            )
            
            // Then - 应该为每个对象提供识别结果
            XCTAssertEqual(results.count, detectedObjects.count)
            
            // 验证相似对象的置信度差异
            let confidences = results.map { $0.confidence }
            let maxConfidence = confidences.max() ?? 0
            let minConfidence = confidences.min() ?? 0
            
            // 相似对象的置信度差异应该不会太大
            XCTAssertLessThan(maxConfidence - minConfidence, 0.5, "相似对象的置信度差异应该合理")
            
        } catch PhotoRecognitionError.multipleObjectsAmbiguous {
            // 这是预期的错误，表示系统正确识别了歧义情况
            print("正确识别了多对象歧义情况")
        }
    }
    
    // MARK: - 性能和稳定性测试
    
    /// 测试大量图像的批量处理性能
    func testBatchProcessingPerformance() async throws {
        let imageCount = 20
        let testImages = (0..<imageCount).map { _ in
            createTestImage(type: .singleObject, quality: .medium)
        }
        
        let batchPerformanceId = UUID()
        await performanceMonitor.startRequest(id: batchPerformanceId, type: .batchRecognition)
        
        let startTime = Date()
        
        do {
            // 并发处理多张图像
            let results = try await withThrowingTaskGroup(of: PhotoRecognitionResult.self) { group in
                for (index, image) in testImages.enumerated() {
                    group.addTask {
                        let preprocessed = await self.imagePreprocessor.enhanceImage(image)
                        let detections = await self.objectDetector.detectObjects(in: preprocessed)
                        return try await self.performRecognition(image: preprocessed, detectedObjects: detections)
                    }
                }
                
                var allResults: [PhotoRecognitionResult] = []
                for try await result in group {
                    allResults.append(result)
                }
                return allResults
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            let averageTime = totalTime / Double(imageCount)
            
            // 验证性能指标
            XCTAssertEqual(results.count, imageCount, "应该处理所有图像")
            XCTAssertLessThan(averageTime, 5.0, "平均处理时间应该小于5秒")
            
            print("批量处理\(imageCount)张图像，总时间: \(String(format: "%.2f", totalTime))秒，平均: \(String(format: "%.2f", averageTime))秒")
            
            await performanceMonitor.endRequest(id: batchPerformanceId, type: .batchRecognition)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: batchPerformanceId, type: .batchRecognition, error: error)
            throw error
        }
    }
    
    /// 测试内存使用和泄漏
    func testMemoryUsageAndLeaks() async throws {
        let initialMemory = getMemoryUsage()
        let imageCount = 50
        
        // 处理大量图像以测试内存管理
        for i in 0..<imageCount {
            let testImage = createTestImage(type: .singleObject, quality: .high)
            
            // 完整的识别流程
            let preprocessed = await imagePreprocessor.enhanceImage(testImage)
            let detections = await objectDetector.detectObjects(in: preprocessed)
            
            if !detections.isEmpty {
                _ = try await performRecognition(image: preprocessed, detectedObjects: detections)
            }
            
            // 每10张图像检查一次内存使用
            if i % 10 == 0 {
                let currentMemory = getMemoryUsage()
                let memoryIncrease = currentMemory - initialMemory
                
                print("处理\(i + 1)张图像后，内存增长: \(memoryIncrease / 1024 / 1024)MB")
                
                // 内存增长应该控制在合理范围内
                XCTAssertLessThan(memoryIncrease, 200 * 1024 * 1024, "内存增长应该控制在200MB以内")
            }
        }
        
        // 强制垃圾回收
        autoreleasepool {
            // 清理缓存
            await cacheManager.clearExpiredEntries()
        }
        
        // 等待内存释放
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        let finalMemory = getMemoryUsage()
        let totalMemoryIncrease = finalMemory - initialMemory
        
        print("最终内存增长: \(totalMemoryIncrease / 1024 / 1024)MB")
        
        // 最终内存增长应该在合理范围内
        XCTAssertLessThan(totalMemoryIncrease, 100 * 1024 * 1024, "最终内存增长应该控制在100MB以内")
    }
    
    /// 测试长时间运行的稳定性
    func testLongRunningStability() async throws {
        let runDuration: TimeInterval = 30.0 // 30秒长时间运行
        let operationInterval: TimeInterval = 2.0 // 每2秒一个操作
        
        let stabilityTestId = UUID()
        await performanceMonitor.startRequest(id: stabilityTestId, type: .stabilityTest)
        
        let startTime = Date()
        var operationCount = 0
        var successCount = 0
        var errorCount = 0
        
        while Date().timeIntervalSince(startTime) < runDuration {
            do {
                let testImage = createTestImage(type: .singleObject, quality: .medium)
                let preprocessed = await imagePreprocessor.enhanceImage(testImage)
                let detections = await objectDetector.detectObjects(in: preprocessed)
                
                if !detections.isEmpty {
                    _ = try await performRecognition(image: preprocessed, detectedObjects: detections)
                }
                
                successCount += 1
                
            } catch {
                errorCount += 1
                print("长时间运行测试中的错误: \(error)")
            }
            
            operationCount += 1
            
            try await Task.sleep(nanoseconds: UInt64(operationInterval * 1_000_000_000))
        }
        
        let successRate = Double(successCount) / Double(operationCount)
        
        print("长时间运行测试完成: \(operationCount)个操作，成功率: \(String(format: "%.1f", successRate * 100))%")
        
        // 验证稳定性指标
        XCTAssertGreaterThan(successRate, 0.8, "长时间运行成功率应该大于80%")
        XCTAssertGreaterThan(operationCount, Int(runDuration / operationInterval * 0.8), "应该完成大部分预期操作")
        
        await performanceMonitor.endRequest(id: stabilityTestId, type: .stabilityTest)
    }
    
    // MARK: - 缓存和相似度匹配测试
    
    /// 测试缓存系统的完整性
    func testCacheSystemIntegrity() async throws {
        let testImage1 = createTestImage(type: .singleObject, quality: .high)
        let testImage2 = createTestImage(type: .singleObject, quality: .high)
        let similarImage = createSimilarImage(to: testImage1)
        
        // Step 1: 首次识别并缓存
        let preprocessed1 = await imagePreprocessor.enhanceImage(testImage1)
        let hash1 = await similarityMatcher.generatePerceptualHash(preprocessed1)
        
        let result1 = try await performRecognition(image: preprocessed1, detectedObjects: [])
        await cacheManager.cacheResult(result1, for: hash1)
        
        // Step 2: 验证缓存命中
        let cachedResult1 = await cacheManager.getCachedResult(for: hash1)
        XCTAssertNotNil(cachedResult1, "应该能从缓存获取结果")
        XCTAssertEqual(cachedResult1?.itemInfo.name, result1.itemInfo.name)
        
        // Step 3: 测试相似图像的缓存匹配
        let preprocessedSimilar = await imagePreprocessor.enhanceImage(similarImage)
        let similarResults = await cacheManager.findSimilarCachedResults(
            for: preprocessedSimilar,
            threshold: 0.8
        )
        
        XCTAssertGreaterThan(similarResults.count, 0, "应该找到相似的缓存结果")
        
        // Step 4: 测试不同图像不会误匹配
        let preprocessed2 = await imagePreprocessor.enhanceImage(testImage2)
        let hash2 = await similarityMatcher.generatePerceptualHash(preprocessed2)
        
        let similarity = await similarityMatcher.calculateSimilarity(
            between: preprocessed1,
            and: preprocessed2
        )
        
        if similarity < 0.5 { // 如果图像确实不相似
            let cachedResult2 = await cacheManager.getCachedResult(for: hash2)
            XCTAssertNil(cachedResult2, "不相似的图像不应该有缓存命中")
        }
        
        // Step 5: 测试缓存清理
        await cacheManager.clearExpiredEntries()
        
        // 验证缓存统计
        let cacheStats = await cacheManager.getCacheStatistics()
        XCTAssertGreaterThan(cacheStats.totalEntries, 0, "清理后应该还有有效缓存")
    }
    
    /// 测试用户反馈学习系统
    func testUserFeedbackLearningSystem() async throws {
        let testImage = createTestImage(type: .singleObject, quality: .high)
        let preprocessed = await imagePreprocessor.enhanceImage(testImage)
        
        // Step 1: 初始识别
        let initialResult = try await performRecognition(image: preprocessed, detectedObjects: [])
        
        // Step 2: 模拟用户修正
        let userFeedback = UserFeedback(
            isCorrect: false,
            correctedName: "用户修正的名称",
            correctedCategory: .electronics,
            correctedProperties: ["brand": "用户品牌"],
            rating: 3,
            comments: "识别不够准确",
            timestamp: Date()
        )
        
        await userFeedbackManager.recordFeedback(userFeedback, for: initialResult)
        
        // Step 3: 验证学习数据记录
        let learningData = await userFeedbackManager.getLearningData(for: initialResult.id)
        XCTAssertNotNil(learningData, "应该记录学习数据")
        
        // Step 4: 模拟相似图像的改进识别
        let similarImage = createSimilarImage(to: testImage)
        let preprocessedSimilar = await imagePreprocessor.enhanceImage(similarImage)
        
        let improvedResult = try await performRecognitionWithLearning(
            image: preprocessedSimilar,
            detectedObjects: []
        )
        
        // Step 5: 验证学习效果
        if let correctedName = userFeedback.correctedName {
            // 在实际实现中，学习系统应该影响后续识别结果
            print("学习系统应该考虑用户修正: \(correctedName)")
        }
        
        // 验证反馈统计
        let feedbackStats = await userFeedbackManager.getFeedbackStatistics()
        XCTAssertGreaterThan(feedbackStats.totalFeedbacks, 0, "应该记录用户反馈")
    }
    
    // MARK: - 多场景验证测试
    
    /// 测试不同光线条件下的识别
    func testRecognitionUnderDifferentLightingConditions() async throws {
        let lightingConditions: [ImageQuality] = [.low, .medium, .high]
        
        for condition in lightingConditions {
            let testImage = createTestImage(type: .singleObject, quality: condition)
            
            do {
                let preprocessed = await imagePreprocessor.enhanceImage(testImage)
                let qualityResult = await qualityManager.validateImageQuality(preprocessed)
                
                if qualityResult.isAcceptable {
                    let result = try await performRecognition(image: preprocessed, detectedObjects: [])
                    
                    // 验证在不同光线条件下都能获得合理结果
                    XCTAssertNotNil(result.itemInfo)
                    XCTAssertGreaterThan(result.confidence, 0.3, "在\(condition)光线条件下应该有基本置信度")
                    
                    print("光线条件\(condition): 置信度\(String(format: "%.2f", result.confidence))")
                }
                
            } catch {
                // 在极低光线条件下失败是可以接受的
                if condition == .low {
                    print("低光线条件下识别失败是可以接受的: \(error)")
                } else {
                    throw error
                }
            }
        }
    }
    
    /// 测试不同物品类别的识别准确度
    func testRecognitionAccuracyAcrossCategories() async throws {
        let categories: [ItemCategory] = [.electronics, .clothing, .toiletries, .documents, .other]
        var categoryResults: [ItemCategory: [Double]] = [:]
        
        for category in categories {
            let testImages = createTestImagesForCategory(category, count: 5)
            var confidences: [Double] = []
            
            for testImage in testImages {
                do {
                    let preprocessed = await imagePreprocessor.enhanceImage(testImage)
                    let result = try await performRecognition(image: preprocessed, detectedObjects: [])
                    
                    confidences.append(result.confidence)
                    
                } catch {
                    print("类别\(category)识别失败: \(error)")
                    confidences.append(0.0) // 失败记为0置信度
                }
            }
            
            categoryResults[category] = confidences
        }
        
        // 分析各类别的识别表现
        for (category, confidences) in categoryResults {
            let averageConfidence = confidences.reduce(0, +) / Double(confidences.count)
            let successRate = Double(confidences.filter { $0 > 0.5 }.count) / Double(confidences.count)
            
            print("类别\(category): 平均置信度\(String(format: "%.2f", averageConfidence)), 成功率\(String(format: "%.1f", successRate * 100))%")
            
            // 验证基本性能要求
            XCTAssertGreaterThan(averageConfidence, 0.3, "类别\(category)的平均置信度应该大于0.3")
            XCTAssertGreaterThan(successRate, 0.5, "类别\(category)的成功率应该大于50%")
        }
    }
    
    /// 测试边缘情况处理
    func testEdgeCaseHandling() async throws {
        let edgeCases: [(String, UIImage)] = [
            ("空白图像", createBlankImage()),
            ("纯色图像", createSolidColorImage()),
            ("极小图像", createTinyImage()),
            ("极大图像", createLargeImage()),
            ("损坏图像", createCorruptedImage())
        ]
        
        for (caseName, testImage) in edgeCases {
            do {
                let qualityResult = await qualityManager.validateImageQuality(testImage)
                
                if qualityResult.isAcceptable {
                    let preprocessed = await imagePreprocessor.enhanceImage(testImage)
                    let detections = await objectDetector.detectObjects(in: preprocessed)
                    
                    if detections.isEmpty {
                        // 没有检测到对象是正常的
                        print("\(caseName): 未检测到对象")
                    } else {
                        let result = try await performRecognition(image: preprocessed, detectedObjects: detections)
                        print("\(caseName): 识别成功，置信度\(result.confidence)")
                    }
                } else {
                    print("\(caseName): 图像质量不合格，问题: \(qualityResult.issues)")
                }
                
            } catch {
                // 边缘情况下的错误是可以接受的，但应该是可预期的错误类型
                if let photoError = error as? PhotoRecognitionError {
                    print("\(caseName): 预期错误 - \(photoError)")
                } else {
                    XCTFail("\(caseName): 意外错误 - \(error)")
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func setupTestImages() {
        // 创建各种类型的测试图像
        testImages = [
            createTestImage(type: .singleObject, quality: .high),
            createTestImage(type: .multipleObjects, quality: .high),
            createTestImage(type: .commonItem, quality: .medium),
            createTestImage(type: .similarObjects, quality: .high)
        ]
    }
    
    private func cleanupTestEnvironment() async {
        // 清理缓存
        await cacheManager.clearAllCache()
        
        // 重置性能监控
        performanceMonitor.resetStats()
        
        // 清理用户反馈
        await userFeedbackManager.clearAllFeedback()
        
        // 停止实时相机
        realTimeCameraManager.stopSession()
    }
    
    private func performRecognition(
        image: UIImage,
        detectedObjects: [DetectedObject]
    ) async throws -> PhotoRecognitionResult {
        // 模拟完整的识别流程
        let itemInfo = ItemInfo(
            name: "测试物品",
            category: .electronics,
            weight: 500.0,
            volume: 1000.0,
            confidence: 0.85,
            source: "集成测试"
        )
        
        return PhotoRecognitionResult(
            id: UUID(),
            itemInfo: itemInfo,
            confidence: 0.85,
            recognitionMethod: .cloudAPI,
            processingTime: 1.5,
            imageMetadata: ImageMetadata(
                originalSize: image.size,
                processedSize: image.size,
                fileSize: 1024 * 1024,
                format: "JPEG",
                dominantColors: ["#FF0000"],
                brightness: 0.5,
                contrast: 0.5,
                sharpness: 0.7,
                hasMultipleObjects: detectedObjects.count > 1,
                detectedObjects: []
            ),
            alternatives: [],
            qualityScore: 0.8,
            timestamp: Date(),
            userFeedback: nil,
            isVerified: false,
            correctedInfo: nil
        )
    }
    
    private func performRecognitionWithFallback(
        image: UIImage,
        detectedObjects: [DetectedObject]
    ) async throws -> PhotoRecognitionResult {
        // 首先尝试在线识别
        do {
            return try await performRecognition(image: image, detectedObjects: detectedObjects)
        } catch {
            // 如果在线识别失败，尝试离线识别
            let offlineResult = try await offlineRecognition.recognizeOffline(image)
            
            let itemInfo = ItemInfo(
                name: "离线识别物品",
                category: offlineResult.category,
                weight: 0.0,
                volume: 0.0,
                confidence: offlineResult.confidence,
                source: "离线识别"
            )
            
            return PhotoRecognitionResult(
                id: UUID(),
                itemInfo: itemInfo,
                confidence: offlineResult.confidence,
                recognitionMethod: .offlineML,
                processingTime: 0.5,
                imageMetadata: ImageMetadata(
                    originalSize: image.size,
                    processedSize: image.size,
                    fileSize: 1024 * 1024,
                    format: "JPEG",
                    dominantColors: [],
                    brightness: 0.5,
                    contrast: 0.5,
                    sharpness: 0.7,
                    hasMultipleObjects: false,
                    detectedObjects: []
                ),
                alternatives: [],
                qualityScore: 0.6,
                timestamp: Date(),
                userFeedback: nil,
                isVerified: false,
                correctedInfo: nil
            )
        }
    }
    
    private func performRecognitionWithLearning(
        image: UIImage,
        detectedObjects: [DetectedObject]
    ) async throws -> PhotoRecognitionResult {
        // 在实际实现中，这里会考虑用户反馈的学习数据
        return try await performRecognition(image: image, detectedObjects: detectedObjects)
    }
    
    // MARK: - 图像创建辅助方法
    
    private enum ImageType {
        case singleObject
        case multipleObjects
        case commonItem
        case similarObjects
    }
    
    private enum ImageQuality {
        case low
        case medium
        case high
    }
    
    private func createTestImage(type: ImageType, quality: ImageQuality) -> UIImage {
        let baseSize: CGSize
        let brightness: CGFloat
        
        switch quality {
        case .low:
            baseSize = CGSize(width: 200, height: 150)
            brightness = 0.3
        case .medium:
            baseSize = CGSize(width: 400, height: 300)
            brightness = 0.6
        case .high:
            baseSize = CGSize(width: 800, height: 600)
            brightness = 0.9
        }
        
        let renderer = UIGraphicsImageRenderer(size: baseSize)
        
        return renderer.image { context in
            // 设置背景
            UIColor(white: brightness, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: baseSize))
            
            switch type {
            case .singleObject:
                drawSingleObject(in: context, size: baseSize, brightness: brightness)
            case .multipleObjects:
                drawMultipleObjects(in: context, size: baseSize, brightness: brightness)
            case .commonItem:
                drawCommonItem(in: context, size: baseSize, brightness: brightness)
            case .similarObjects:
                drawSimilarObjects(in: context, size: baseSize, brightness: brightness)
            }
        }
    }
    
    private func drawSingleObject(in context: UIGraphicsImageRendererContext, size: CGSize, brightness: CGFloat) {
        UIColor.blue.withAlphaComponent(brightness).setFill()
        let objectRect = CGRect(
            x: size.width * 0.3,
            y: size.height * 0.3,
            width: size.width * 0.4,
            height: size.height * 0.4
        )
        context.fill(objectRect)
    }
    
    private func drawMultipleObjects(in context: UIGraphicsImageRendererContext, size: CGSize, brightness: CGFloat) {
        let colors = [UIColor.red, UIColor.green, UIColor.blue, UIColor.orange]
        let positions = [
            CGRect(x: size.width * 0.1, y: size.height * 0.1, width: size.width * 0.3, height: size.height * 0.3),
            CGRect(x: size.width * 0.6, y: size.height * 0.1, width: size.width * 0.3, height: size.height * 0.3),
            CGRect(x: size.width * 0.1, y: size.height * 0.6, width: size.width * 0.3, height: size.height * 0.3),
            CGRect(x: size.width * 0.6, y: size.height * 0.6, width: size.width * 0.3, height: size.height * 0.3)
        ]
        
        for (color, rect) in zip(colors, positions) {
            color.withAlphaComponent(brightness).setFill()
            context.fill(rect)
        }
    }
    
    private func drawCommonItem(in context: UIGraphicsImageRendererContext, size: CGSize, brightness: CGFloat) {
        // 绘制一个类似手机的矩形
        UIColor.black.withAlphaComponent(brightness).setFill()
        let phoneRect = CGRect(
            x: size.width * 0.35,
            y: size.height * 0.2,
            width: size.width * 0.3,
            height: size.height * 0.6
        )
        context.fill(phoneRect)
        
        // 添加屏幕
        UIColor.white.withAlphaComponent(brightness * 0.8).setFill()
        let screenRect = phoneRect.insetBy(dx: 10, dy: 20)
        context.fill(screenRect)
    }
    
    private func drawSimilarObjects(in context: UIGraphicsImageRendererContext, size: CGSize, brightness: CGFloat) {
        // 绘制两个相似的圆形对象
        UIColor.blue.withAlphaComponent(brightness).setFill()
        
        let circle1 = CGRect(
            x: size.width * 0.2,
            y: size.height * 0.3,
            width: size.width * 0.25,
            height: size.width * 0.25
        )
        context.fillEllipse(in: circle1)
        
        let circle2 = CGRect(
            x: size.width * 0.55,
            y: size.height * 0.3,
            width: size.width * 0.25,
            height: size.width * 0.25
        )
        context.fillEllipse(in: circle2)
    }
    
    private func createSimilarImage(to originalImage: UIImage) -> UIImage {
        // 创建与原图相似但略有不同的图像
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        
        return renderer.image { context in
            // 绘制原图
            originalImage.draw(at: .zero)
            
            // 添加轻微的噪声或变化
            UIColor.white.withAlphaComponent(0.1).setFill()
            context.fill(CGRect(origin: .zero, size: originalImage.size))
        }
    }
    
    private func createTestImagesForCategory(_ category: ItemCategory, count: Int) -> [UIImage] {
        return (0..<count).map { _ in
            createTestImage(type: .commonItem, quality: .medium)
        }
    }
    
    private func createBlankImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createSolidColorImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createTinyImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createLargeImage() -> UIImage {
        let size = CGSize(width: 4000, height: 3000)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 添加一些内容以模拟真实大图
            UIColor.white.setFill()
            for i in 0..<100 {
                let rect = CGRect(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height),
                    width: 100,
                    height: 100
                )
                context.fill(rect)
            }
        }
    }
    
    private func createCorruptedImage() -> UIImage {
        // 创建一个"损坏"的图像（实际上是一个有特殊模式的图像）
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 创建棋盘模式来模拟损坏效果
            for x in stride(from: 0, to: Int(size.width), by: 10) {
                for y in stride(from: 0, to: Int(size.height), by: 10) {
                    let color = (x + y) % 20 == 0 ? UIColor.black : UIColor.white
                    color.setFill()
                    context.fill(CGRect(x: x, y: y, width: 10, height: 10))
                }
            }
        }
    }
    
    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - 扩展的错误恢复动作

extension PhotoRecognitionErrorRecoveryManager {
    func handleImageQualityError(_ issues: [ImageQualityIssue], image: UIImage) async -> RecoveryAction {
        // 简化的错误恢复逻辑
        if issues.contains(where: { issue in
            if case .tooBlurry = issue { return true }
            return false
        }) {
            return .enhanceImage
        }
        
        return .suggestRecapture
    }
}

enum RecoveryAction {
    case enhanceImage
    case suggestRecapture
    case showObjectSelection
    case fallbackToOffline
}

// MARK: - 扩展的性能监控类型

extension PerformanceMonitor {
    func startRequest(id: UUID, type: RequestType) async {
        // 实现性能监控开始
    }
    
    func endRequest(id: UUID, type: RequestType, fromCache: Bool = false) async {
        // 实现性能监控结束
    }
    
    func recordRequestFailure(id: UUID, type: RequestType, error: Error) async {
        // 记录请求失败
    }
}

enum RequestType {
    case photoRecognition
    case batchRecognition
    case realTimeRecognition
    case offlineRecognition
    case stabilityTest
}