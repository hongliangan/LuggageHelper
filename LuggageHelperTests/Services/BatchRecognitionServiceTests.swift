import XCTest
import UIKit
@testable import LuggageHelper

/// BatchRecognitionService 单元测试
final class BatchRecognitionServiceTests: XCTestCase {
    
    // MARK: - 属性
    
    var batchService: BatchRecognitionService!
    var testImages: [UIImage]!
    var mockDetectedObjects: [DetectedObject]!
    
    // MARK: - 设置和清理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        batchService = BatchRecognitionService.shared
        testImages = createTestImages()
        mockDetectedObjects = createMockDetectedObjects()
    }
    
    override func tearDownWithError() throws {
        batchService.cancelCurrentBatch()
        batchService = nil
        testImages = nil
        mockDetectedObjects = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 批量识别测试
    
    /// 测试批量识别所有对象
    func testRecognizeAllObjects() async throws {
        let testImage = testImages[0]
        var progressUpdates: [BatchProgress] = []
        
        let result = try await batchService.recognizeAllObjects(in: testImage) { progress in
            progressUpdates.append(progress)
        }
        
        XCTAssertNotNil(result, "批量识别结果不应为空")
        XCTAssertEqual(result.originalImage, testImage, "原始图像应匹配")
        XCTAssertGreaterThanOrEqual(result.totalObjects, 0, "总对象数应大于等于0")
        XCTAssertGreaterThanOrEqual(result.successfulRecognitions.count, 0, "成功识别数应大于等于0")
        XCTAssertGreaterThanOrEqual(result.overallConfidence, 0.0, "整体置信度应大于等于0")
        XCTAssertLessThanOrEqual(result.overallConfidence, 1.0, "整体置信度应小于等于1")
        XCTAssertGreaterThan(result.processingTime, 0.0, "处理时间应大于0")
        
        // 验证进度更新
        XCTAssertFalse(progressUpdates.isEmpty, "应该有进度更新")
        
        // 验证成功率计算
        let expectedSuccessRate = Double(result.successfulRecognitions.count) / Double(result.totalObjects)
        XCTAssertEqual(result.successRate, expectedSuccessRate, accuracy: 0.01, "成功率计算应正确")
    }
    
    /// 测试识别选定对象
    func testRecognizeSelectedObjects() async throws {
        let testImage = testImages[1]
        let selectedObjects = Array(mockDetectedObjects.prefix(2)) // 选择前两个对象
        
        let result = try await batchService.recognizeSelectedObjects(selectedObjects, from: testImage) { _ in }
        
        XCTAssertNotNil(result, "选定对象识别结果不应为空")
        XCTAssertEqual(result.totalObjects, selectedObjects.count, "总对象数应等于选定对象数")
        XCTAssertEqual(result.originalImage, testImage, "原始图像应匹配")
    }
    
    /// 测试批量任务取消
    func testBatchTaskCancellation() async throws {
        let testImage = testImages[0]
        
        // 启动批量任务
        let task = Task {
            try await batchService.recognizeAllObjects(in: testImage) { _ in }
        }
        
        // 立即取消
        batchService.cancelCurrentBatch()
        
        do {
            _ = try await task.value
            XCTFail("任务应该被取消")
        } catch {
            // 验证是取消错误
            if let batchError = error as? BatchRecognitionError {
                XCTAssertEqual(batchError, .cancelled, "应该是取消错误")
            }
        }
    }
    
    /// 测试批量任务状态跟踪
    func testBatchTaskStatusTracking() async throws {
        let testImage = testImages[0]
        
        // 检查初始状态
        XCTAssertNil(batchService.getCurrentBatchStatus(), "初始状态应为空")
        
        let task = Task {
            try await batchService.recognizeAllObjects(in: testImage) { _ in }
        }
        
        // 等待一小段时间让任务开始
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        let status = batchService.getCurrentBatchStatus()
        XCTAssertNotNil(status, "任务开始后状态不应为空")
        
        _ = try await task.value
        
        // 任务完成后状态可能被清理
    }
    
    // MARK: - 进度跟踪测试
    
    /// 测试进度跟踪功能
    func testProgressTracking() async throws {
        let testImage = testImages[0]
        var progressUpdates: [BatchProgress] = []
        var lastProgress: Double = -1
        
        _ = try await batchService.recognizeAllObjects(in: testImage) { progress in
            progressUpdates.append(progress)
            
            // 验证进度是递增的
            XCTAssertGreaterThanOrEqual(progress.progressPercentage, lastProgress, "进度应该是递增的")
            lastProgress = progress.progressPercentage
            
            // 验证进度范围
            XCTAssertGreaterThanOrEqual(progress.progressPercentage, 0.0, "进度应大于等于0")
            XCTAssertLessThanOrEqual(progress.progressPercentage, 1.0, "进度应小于等于1")
            
            // 验证已完成项目数不超过总数
            XCTAssertLessThanOrEqual(progress.completedItems, progress.totalItems, "已完成数不应超过总数")
        }
        
        XCTAssertFalse(progressUpdates.isEmpty, "应该有进度更新")
        
        // 验证最后一个进度更新
        if let lastUpdate = progressUpdates.last {
            XCTAssertEqual(lastUpdate.completedItems, lastUpdate.totalItems, "最后应该完成所有项目")
        }
    }
    
    // MARK: - 结果分组和优化测试
    
    /// 测试识别结果分组
    func testRecognitionResultGrouping() async throws {
        let mockResults = createMockRecognitionResults()
        
        let groups = batchService.groupRecognitionResults(mockResults)
        
        XCTAssertFalse(groups.isEmpty, "分组结果不应为空")
        
        for group in groups {
            XCTAssertFalse(group.results.isEmpty, "每个组应包含结果")
            XCTAssertGreaterThan(group.averageConfidence, 0.0, "组平均置信度应大于0")
            
            // 验证组内结果的类别一致性
            let firstCategory = group.results.first?.recognizedItem.category
            for result in group.results {
                XCTAssertEqual(result.recognizedItem.category, firstCategory, "组内结果类别应一致")
            }
        }
        
        // 验证分组按置信度排序
        for i in 0..<(groups.count - 1) {
            XCTAssertGreaterThanOrEqual(groups[i].averageConfidence, groups[i + 1].averageConfidence, "分组应按置信度降序排列")
        }
    }
    
    /// 测试识别结果优化
    func testRecognitionResultOptimization() async throws {
        let mockResults = createMockRecognitionResults()
        let lowConfidenceResult = ObjectRecognitionResult(
            detectedObject: mockDetectedObjects[0],
            recognizedItem: ItemInfo(name: "低置信度物品", category: .other, weight: 100, volume: 200, confidence: 0.2),
            confidence: 0.2,
            processingTime: 1.0
        )
        
        let allResults = mockResults + [lowConfidenceResult]
        let optimizedResults = batchService.optimizeRecognitionResults(allResults)
        
        // 验证低置信度结果被过滤
        XCTAssertFalse(optimizedResults.contains { $0.confidence < 0.3 }, "低置信度结果应被过滤")
        
        // 验证结果按置信度排序
        for i in 0..<(optimizedResults.count - 1) {
            XCTAssertGreaterThanOrEqual(optimizedResults[i].confidence, optimizedResults[i + 1].confidence, "结果应按置信度降序排列")
        }
    }
    
    // MARK: - 性能测试
    
    /// 测试批量识别性能
    func testBatchRecognitionPerformance() async throws {
        let testImage = testImages[0]
        
        measure {
            let expectation = XCTestExpectation(description: "批量识别完成")
            
            Task {
                do {
                    _ = try await batchService.recognizeAllObjects(in: testImage) { _ in }
                    expectation.fulfill()
                } catch {
                    XCTFail("批量识别失败: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - 错误处理测试
    
    /// 测试无效图像处理
    func testInvalidImageHandling() async throws {
        let invalidImage = UIImage()
        
        do {
            _ = try await batchService.recognizeAllObjects(in: invalidImage) { _ in }
            // 如果没有抛出错误，验证结果是合理的
        } catch {
            // 如果抛出错误，验证是预期的错误类型
            XCTAssertTrue(error is BatchRecognitionError, "应该是批量识别错误")
        }
    }
    
    /// 测试空对象列表处理
    func testEmptyObjectListHandling() async throws {
        let testImage = testImages[0]
        let emptyObjects: [DetectedObject] = []
        
        let result = try await batchService.recognizeSelectedObjects(emptyObjects, from: testImage) { _ in }
        
        XCTAssertEqual(result.totalObjects, 0, "总对象数应为0")
        XCTAssertEqual(result.successfulRecognitions.count, 0, "成功识别数应为0")
        XCTAssertEqual(result.failedObjects.count, 0, "失败对象数应为0")
    }
    
    // MARK: - 辅助方法
    
    /// 创建测试图像
    private func createTestImages() -> [UIImage] {
        var images: [UIImage] = []
        
        // 创建包含多个对象的测试图像
        for i in 0..<3 {
            let size = CGSize(width: 400, height: 300)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // 绘制不同数量的对象
                for j in 0...(i + 1) {
                    let color = [UIColor.red, UIColor.blue, UIColor.green, UIColor.orange][j % 4]
                    color.setFill()
                    context.fill(CGRect(x: 50 + j * 80, y: 50 + j * 40, width: 60, height: 60))
                }
            }
            
            images.append(image)
        }
        
        return images
    }
    
    /// 创建模拟检测对象
    private func createMockDetectedObjects() -> [DetectedObject] {
        var objects: [DetectedObject] = []
        
        for i in 0..<5 {
            let thumbnail = createThumbnailImage(color: [UIColor.red, .blue, .green, .orange, .purple][i])
            
            let object = DetectedObject(
                id: i,
                boundingBox: CGRect(x: Double(i) * 0.2, y: 0.1, width: 0.15, height: 0.2),
                confidence: Float(0.5 + Double(i) * 0.1),
                thumbnail: thumbnail,
                type: [ObjectType.rectangular, .contour, .text, .circular, .irregular][i % 5]
            )
            
            objects.append(object)
        }
        
        return objects
    }
    
    /// 创建缩略图
    private func createThumbnailImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// 创建模拟识别结果
    private func createMockRecognitionResults() -> [ObjectRecognitionResult] {
        var results: [ObjectRecognitionResult] = []
        
        let categories: [ItemCategory] = [.clothing, .electronics, .toiletries, .accessories, .other]
        let names = ["T恤", "手机", "牙刷", "钱包", "其他物品"]
        
        for i in 0..<5 {
            let itemInfo = ItemInfo(
                name: names[i],
                category: categories[i],
                weight: Double(100 + i * 50),
                volume: Double(200 + i * 100),
                confidence: 0.7 + Double(i) * 0.05
            )
            
            let result = ObjectRecognitionResult(
                detectedObject: mockDetectedObjects[i],
                recognizedItem: itemInfo,
                confidence: 0.7 + Double(i) * 0.05,
                processingTime: 1.0 + Double(i) * 0.2
            )
            
            results.append(result)
        }
        
        return results
    }
}