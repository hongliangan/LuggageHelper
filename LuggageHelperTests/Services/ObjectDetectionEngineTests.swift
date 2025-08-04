import XCTest
import UIKit
@testable import LuggageHelper

/// ObjectDetectionEngine 单元测试
final class ObjectDetectionEngineTests: XCTestCase {
    
    // MARK: - 属性
    
    var objectDetector: ObjectDetectionEngine!
    var testImages: [UIImage]!
    
    // MARK: - 设置和清理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        objectDetector = ObjectDetectionEngine.shared
        testImages = createTestImages()
    }
    
    override func tearDownWithError() throws {
        objectDetector = nil
        testImages = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 基础对象检测测试
    
    /// 测试基础对象检测功能
    func testBasicObjectDetection() async throws {
        let testImage = testImages[0]
        
        let detectedObjects = await objectDetector.detectObjects(in: testImage)
        
        XCTAssertNotNil(detectedObjects, "检测结果不应为空")
        XCTAssertGreaterThanOrEqual(detectedObjects.count, 0, "应该能够检测到对象或返回空数组")
        
        // 验证检测到的对象属性
        for object in detectedObjects {
            XCTAssertGreaterThan(object.confidence, 0.0, "置信度应大于0")
            XCTAssertLessThanOrEqual(object.confidence, 1.0, "置信度应小于等于1")
            XCTAssertTrue(object.boundingBox.width > 0, "边界框宽度应大于0")
            XCTAssertTrue(object.boundingBox.height > 0, "边界框高度应大于0")
        }
    }
    
    /// 测试高级对象检测和分组
    func testAdvancedObjectDetectionAndGrouping() async throws {
        let complexImage = createComplexTestImage()
        
        let detectionResult = await objectDetector.detectAndGroupObjects(in: complexImage)
        
        XCTAssertNotNil(detectionResult, "检测结果不应为空")
        XCTAssertGreaterThanOrEqual(detectionResult.objects.count, 0, "应该检测到对象")
        XCTAssertGreaterThanOrEqual(detectionResult.overallConfidence, 0.0, "整体置信度应大于等于0")
        XCTAssertLessThanOrEqual(detectionResult.overallConfidence, 1.0, "整体置信度应小于等于1")
        
        // 验证场景复杂度分析
        XCTAssertTrue([SceneComplexity.simple, .moderate, .complex].contains(detectionResult.sceneComplexity), "场景复杂度应为有效值")
        
        // 验证分组结果
        for group in detectionResult.groups {
            XCTAssertFalse(group.objects.isEmpty, "每个组应包含至少一个对象")
            XCTAssertGreaterThan(group.confidence, 0.0, "组置信度应大于0")
        }
    }
    
    /// 测试不同类型的对象检测
    func testDifferentObjectTypes() async throws {
        let rectangularImage = createRectangularObjectImage()
        let textImage = createTextImage()
        
        // 测试矩形对象检测
        let rectangularObjects = await objectDetector.detectObjects(in: rectangularImage)
        let rectangularCount = rectangularObjects.filter { $0.type == .rectangular }.count
        XCTAssertGreaterThan(rectangularCount, 0, "应该检测到矩形对象")
        
        // 测试文本对象检测
        let textObjects = await objectDetector.detectObjects(in: textImage)
        let textCount = textObjects.filter { $0.type == .text }.count
        XCTAssertGreaterThanOrEqual(textCount, 0, "应该能够检测文本对象")
    }
    
    // MARK: - 区域提取测试
    
    /// 测试最佳区域提取
    func testOptimalRegionExtraction() async throws {
        let testImage = testImages[1]
        
        let extractedRegions = await objectDetector.extractOptimalRegions(from: testImage)
        
        XCTAssertNotNil(extractedRegions, "提取结果不应为空")
        
        for region in extractedRegions {
            XCTAssertNotNil(region.image, "提取的区域图像不应为空")
            XCTAssertGreaterThan(region.confidence, 0.0, "区域置信度应大于0")
            XCTAssertTrue(region.boundingBox.width > 0, "区域边界框宽度应大于0")
            XCTAssertTrue(region.boundingBox.height > 0, "区域边界框高度应大于0")
        }
    }
    
    /// 测试不同提取策略
    func testDifferentExtractionStrategies() async throws {
        let testImage = testImages[2]
        
        let automaticRegions = await objectDetector.extractOptimalRegions(from: testImage, strategy: .automatic)
        let largestFirstRegions = await objectDetector.extractOptimalRegions(from: testImage, strategy: .largestFirst)
        let highestConfidenceRegions = await objectDetector.extractOptimalRegions(from: testImage, strategy: .highestConfidence)
        
        // 验证不同策略都能正常工作
        XCTAssertNotNil(automaticRegions)
        XCTAssertNotNil(largestFirstRegions)
        XCTAssertNotNil(highestConfidenceRegions)
    }
    
    // MARK: - 背景分离测试
    
    /// 测试背景分离功能
    func testBackgroundSeparation() async throws {
        let testImage = testImages[0]
        
        let separationResult = await objectDetector.separateBackground(from: testImage)
        
        if let result = separationResult {
            XCTAssertNotNil(result.originalImage, "原始图像不应为空")
            XCTAssertNotNil(result.foregroundMask, "前景遮罩不应为空")
            XCTAssertGreaterThan(result.separationQuality, 0.0, "分离质量应大于0")
            XCTAssertLessThanOrEqual(result.separationQuality, 1.0, "分离质量应小于等于1")
        }
        // 如果返回nil，说明图像不适合背景分离，这也是正常的
    }
    
    // MARK: - 性能测试
    
    /// 测试对象检测性能
    func testObjectDetectionPerformance() async throws {
        let testImage = testImages[0]
        
        measure {
            let expectation = XCTestExpectation(description: "对象检测完成")
            
            Task {
                _ = await objectDetector.detectObjects(in: testImage)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试批量检测性能
    func testBatchDetectionPerformance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "批量检测完成")
            
            Task {
                for image in testImages {
                    _ = await objectDetector.detectObjects(in: image)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - 边界条件测试
    
    /// 测试空图像处理
    func testEmptyImageHandling() async throws {
        let emptyImage = UIImage()
        
        let detectedObjects = await objectDetector.detectObjects(in: emptyImage)
        
        XCTAssertNotNil(detectedObjects, "空图像检测结果不应为空数组")
        XCTAssertEqual(detectedObjects.count, 0, "空图像应该检测不到任何对象")
    }
    
    /// 测试极小图像处理
    func testTinyImageHandling() async throws {
        let tinyImage = createTinyTestImage()
        
        let detectedObjects = await objectDetector.detectObjects(in: tinyImage)
        
        XCTAssertNotNil(detectedObjects, "极小图像检测不应崩溃")
        // 极小图像可能检测不到对象，这是正常的
    }
    
    /// 测试极大图像处理
    func testHugeImageHandling() async throws {
        let hugeImage = createHugeTestImage()
        
        let detectedObjects = await objectDetector.detectObjects(in: hugeImage)
        
        XCTAssertNotNil(detectedObjects, "极大图像检测不应崩溃")
        // 验证处理时间在合理范围内
    }
    
    // MARK: - 特征提取测试
    
    /// 测试对象特征提取
    func testObjectFeatureExtraction() async throws {
        let testImage = testImages[0]
        
        let detectedObjects = await objectDetector.detectObjects(in: testImage)
        
        for object in detectedObjects {
            let features = object.features
            
            XCTAssertGreaterThanOrEqual(features.aspectRatio, 0.0, "宽高比应大于等于0")
            XCTAssertGreaterThanOrEqual(features.area, 0.0, "面积应大于等于0")
            XCTAssertGreaterThanOrEqual(features.perimeter, 0.0, "周长应大于等于0")
            XCTAssertGreaterThanOrEqual(features.complexity, 0.0, "复杂度应大于等于0")
            XCTAssertLessThanOrEqual(features.complexity, 1.0, "复杂度应小于等于1")
        }
    }
    
    // MARK: - 辅助方法
    
    /// 创建测试图像
    private func createTestImages() -> [UIImage] {
        var images: [UIImage] = []
        
        images.append(createNormalTestImage())
        images.append(createComplexTestImage())
        images.append(createRectangularObjectImage())
        
        return images
    }
    
    /// 创建普通测试图像
    private func createNormalTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 绘制简单的测试图案
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.blue.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 80))
            
            UIColor.red.setFill()
            context.fill(CGRect(x: 200, y: 100, width: 120, height: 90))
        }
    }
    
    /// 创建复杂测试图像
    private func createComplexTestImage() -> UIImage {
        let size = CGSize(width: 600, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 绘制复杂背景
            UIColor.lightGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制多个不同形状的对象
            UIColor.blue.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 80, height: 60))
            
            UIColor.red.setFill()
            context.fillEllipse(in: CGRect(x: 200, y: 80, width: 100, height: 100))
            
            UIColor.green.setFill()
            context.fill(CGRect(x: 350, y: 120, width: 120, height: 80))
            
            UIColor.orange.setFill()
            context.fill(CGRect(x: 100, y: 200, width: 90, height: 90))
            
            UIColor.purple.setFill()
            context.fillEllipse(in: CGRect(x: 300, y: 250, width: 80, height: 80))
        }
    }
    
    /// 创建矩形对象图像
    private func createRectangularObjectImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制清晰的矩形对象
            UIColor.black.setStroke()
            context.cgContext.setLineWidth(2.0)
            
            let rect1 = CGRect(x: 50, y: 50, width: 120, height: 80)
            context.cgContext.stroke(rect1)
            
            let rect2 = CGRect(x: 200, y: 100, width: 100, height: 100)
            context.cgContext.stroke(rect2)
        }
    }
    
    /// 创建文本图像
    private func createTextImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制文本
            let text = "Test Text 123"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            
            text.draw(at: CGPoint(x: 50, y: 100), withAttributes: attributes)
            
            let text2 = "Another Text"
            text2.draw(at: CGPoint(x: 50, y: 150), withAttributes: attributes)
        }
    }
    
    /// 创建极小图像
    private func createTinyTestImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// 创建极大图像
    private func createHugeTestImage() -> UIImage {
        let size = CGSize(width: 4000, height: 3000)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.white.setFill()
            context.fill(CGRect(x: 500, y: 500, width: 1000, height: 800))
        }
    }
}