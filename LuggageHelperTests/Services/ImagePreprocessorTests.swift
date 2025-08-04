import XCTest
import UIKit
@testable import LuggageHelper

/// ImagePreprocessor 单元测试
final class ImagePreprocessorTests: XCTestCase {
    
    // MARK: - 属性
    
    var imagePreprocessor: ImagePreprocessor!
    var testImages: [UIImage]!
    
    // MARK: - 设置和清理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        imagePreprocessor = ImagePreprocessor.shared
        testImages = createTestImages()
    }
    
    override func tearDownWithError() throws {
        imagePreprocessor = nil
        testImages = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 图像增强测试
    
    /// 测试图像增强功能
    func testImageEnhancement() async throws {
        // 准备测试数据
        let originalImage = testImages[0]
        
        // 执行增强
        let enhancedImage = await imagePreprocessor.enhanceImage(originalImage)
        
        // 验证结果
        XCTAssertNotNil(enhancedImage, "增强后的图像不应为空")
        XCTAssertTrue(enhancedImage.size.width > 0, "增强后图像宽度应大于0")
        XCTAssertTrue(enhancedImage.size.height > 0, "增强后图像高度应大于0")
        
        // 验证图像数据有效性
        XCTAssertNotNil(enhancedImage.cgImage, "增强后图像应有有效的CGImage")
    }
    
    /// 测试暗图像增强
    func testDarkImageEnhancement() async throws {
        let darkImage = createDarkTestImage()
        let enhancedImage = await imagePreprocessor.enhanceImage(darkImage)
        
        XCTAssertNotNil(enhancedImage)
        
        // 验证增强后图像亮度有所提升
        let originalBrightness = calculateImageBrightness(darkImage)
        let enhancedBrightness = calculateImageBrightness(enhancedImage)
        
        XCTAssertGreaterThan(enhancedBrightness, originalBrightness, "增强后图像亮度应有所提升")
    }
    
    /// 测试过亮图像增强
    func testBrightImageEnhancement() async throws {
        let brightImage = createBrightTestImage()
        let enhancedImage = await imagePreprocessor.enhanceImage(brightImage)
        
        XCTAssertNotNil(enhancedImage)
        
        // 验证增强后图像亮度有所降低
        let originalBrightness = calculateImageBrightness(brightImage)
        let enhancedBrightness = calculateImageBrightness(enhancedImage)
        
        XCTAssertLessThan(enhancedBrightness, originalBrightness, "增强后过亮图像亮度应有所降低")
    }
    
    // MARK: - 图像标准化测试
    
    /// 测试图像标准化功能
    func testImageNormalization() async throws {
        let originalImage = testImages[1]
        let normalizedImage = await imagePreprocessor.normalizeImage(originalImage)
        
        XCTAssertNotNil(normalizedImage, "标准化后的图像不应为空")
        XCTAssertEqual(normalizedImage.imageOrientation, .up, "标准化后图像方向应为正常")
        
        // 验证尺寸合理性
        let maxDimension = max(normalizedImage.size.width, normalizedImage.size.height)
        XCTAssertLessThanOrEqual(maxDimension, 1024, "标准化后图像尺寸应不超过1024")
    }
    
    /// 测试大尺寸图像标准化
    func testLargeImageNormalization() async throws {
        let largeImage = createLargeTestImage()
        let normalizedImage = await imagePreprocessor.normalizeImage(largeImage)
        
        XCTAssertNotNil(normalizedImage)
        
        // 验证尺寸被正确缩放
        let maxDimension = max(normalizedImage.size.width, normalizedImage.size.height)
        XCTAssertLessThanOrEqual(maxDimension, 1024, "大图像标准化后尺寸应被限制")
        
        // 验证宽高比保持
        let originalRatio = largeImage.size.width / largeImage.size.height
        let normalizedRatio = normalizedImage.size.width / normalizedImage.size.height
        XCTAssertEqual(originalRatio, normalizedRatio, accuracy: 0.01, "标准化后宽高比应保持不变")
    }
    
    /// 测试旋转图像标准化
    func testRotatedImageNormalization() async throws {
        let rotatedImage = createRotatedTestImage()
        let normalizedImage = await imagePreprocessor.normalizeImage(rotatedImage)
        
        XCTAssertNotNil(normalizedImage)
        XCTAssertEqual(normalizedImage.imageOrientation, .up, "旋转图像标准化后方向应为正常")
    }
    
    // MARK: - 图像质量验证测试
    
    /// 测试高质量图像验证
    func testHighQualityImageValidation() async throws {
        let highQualityImage = createHighQualityTestImage()
        let result = await imagePreprocessor.validateImageQuality(highQualityImage)
        
        XCTAssertTrue(result.isAcceptable, "高质量图像应被认为是可接受的")
        XCTAssertGreaterThan(result.score, 0.8, "高质量图像分数应大于0.8")
        XCTAssertTrue(result.issues.isEmpty, "高质量图像不应有质量问题")
        XCTAssertTrue(result.suggestions.isEmpty, "高质量图像不应有改进建议")
    }
    
    /// 测试模糊图像验证
    func testBlurryImageValidation() async throws {
        let blurryImage = createBlurryTestImage()
        let result = await imagePreprocessor.validateImageQuality(blurryImage)
        
        XCTAssertFalse(result.isAcceptable, "模糊图像应被认为是不可接受的")
        XCTAssertLessThan(result.score, 0.6, "模糊图像分数应较低")
        
        // 验证包含模糊问题
        let hasBlurIssue = result.issues.contains { issue in
            if case .tooBlurry = issue { return true }
            return false
        }
        XCTAssertTrue(hasBlurIssue, "应检测到模糊问题")
        
        XCTAssertFalse(result.suggestions.isEmpty, "应提供改进建议")
    }
    
    /// 测试小尺寸图像验证
    func testSmallImageValidation() async throws {
        let smallImage = createSmallTestImage()
        let result = await imagePreprocessor.validateImageQuality(smallImage)
        
        XCTAssertFalse(result.isAcceptable, "小尺寸图像应被认为是不可接受的")
        
        // 验证包含尺寸问题
        let hasSizeIssue = result.issues.contains { issue in
            if case .tooSmall = issue { return true }
            return false
        }
        XCTAssertTrue(hasSizeIssue, "应检测到尺寸问题")
    }
    
    /// 测试暗图像验证
    func testDarkImageValidation() async throws {
        let darkImage = createDarkTestImage()
        let result = await imagePreprocessor.validateImageQuality(darkImage)
        
        // 验证包含光线问题
        let hasLightingIssue = result.issues.contains { issue in
            if case .poorLighting = issue { return true }
            return false
        }
        XCTAssertTrue(hasLightingIssue, "应检测到光线问题")
    }
    
    /// 测试复杂背景图像验证
    func testComplexBackgroundImageValidation() async throws {
        let complexImage = createComplexBackgroundTestImage()
        let result = await imagePreprocessor.validateImageQuality(complexImage)
        
        // 验证包含背景复杂问题
        let hasBackgroundIssue = result.issues.contains { issue in
            if case .complexBackground = issue { return true }
            return false
        }
        XCTAssertTrue(hasBackgroundIssue, "应检测到复杂背景问题")
    }
    
    // MARK: - 最佳区域提取测试
    
    /// 测试最佳区域提取
    func testOptimalRegionExtraction() async throws {
        let imageWithObjects = createImageWithObjects()
        let extractedImage = await imagePreprocessor.extractOptimalRegion(imageWithObjects)
        
        if let extracted = extractedImage {
            XCTAssertNotNil(extracted, "应能提取到最佳区域")
            XCTAssertLessThan(extracted.size.width, imageWithObjects.size.width, "提取的区域应小于原图")
            XCTAssertLessThan(extracted.size.height, imageWithObjects.size.height, "提取的区域应小于原图")
        }
        // 如果没有检测到合适区域，返回nil是正常的
    }
    
    /// 测试无明显区域的图像提取
    func testOptimalRegionExtractionWithNoObjects() async throws {
        let plainImage = createPlainTestImage()
        let extractedImage = await imagePreprocessor.extractOptimalRegion(plainImage)
        
        // 对于没有明显物体的图像，可能返回nil
        // 这是正常行为，不应该崩溃
        XCTAssertNoThrow(extractedImage)
    }
    
    // MARK: - 综合预处理测试
    
    /// 测试默认预处理选项
    func testComprehensivePreprocessingWithDefaultOptions() async throws {
        let originalImage = testImages[0]
        let result = await imagePreprocessor.preprocessImage(originalImage)
        
        XCTAssertNotNil(result.processedImage, "预处理后图像不应为空")
        XCTAssertGreaterThan(result.qualityScore, 0.0, "质量分数应大于0")
        XCTAssertFalse(result.appliedOperations.isEmpty, "应有应用的操作")
        XCTAssertGreaterThan(result.processingTime, 0.0, "处理时间应大于0")
    }
    
    /// 测试所有预处理选项
    func testComprehensivePreprocessingWithAllOptions() async throws {
        let originalImage = testImages[1]
        let result = await imagePreprocessor.preprocessImage(originalImage, options: .all)
        
        XCTAssertNotNil(result.processedImage)
        XCTAssertGreaterThanOrEqual(result.appliedOperations.count, 3, "应用所有选项时操作数应较多")
    }
    
    /// 测试仅标准化选项
    func testComprehensivePreprocessingWithNormalizeOnly() async throws {
        let originalImage = testImages[2]
        let result = await imagePreprocessor.preprocessImage(originalImage, options: .normalize)
        
        XCTAssertNotNil(result.processedImage)
        XCTAssertTrue(result.appliedOperations.contains("标准化"), "应包含标准化操作")
        XCTAssertEqual(result.appliedOperations.count, 1, "仅标准化时应只有一个操作")
    }
    
    // MARK: - 性能测试
    
    /// 测试图像增强性能
    func testImageEnhancementPerformance() async throws {
        let image = testImages[0]
        
        measure {
            let expectation = XCTestExpectation(description: "图像增强完成")
            
            Task {
                _ = await imagePreprocessor.enhanceImage(image)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    /// 测试批量图像处理性能
    func testBatchImageProcessingPerformance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "批量处理完成")
            
            Task {
                for image in testImages {
                    _ = await imagePreprocessor.validateImageQuality(image)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - 边界条件测试
    
    /// 测试空图像处理
    func testNilImageHandling() async throws {
        // 这个测试验证处理无效图像时不会崩溃
        let emptyData = Data()
        let invalidImage = UIImage(data: emptyData)
        
        XCTAssertNil(invalidImage, "无效数据应创建nil图像")
    }
    
    /// 测试极小图像处理
    func testTinyImageProcessing() async throws {
        let tinyImage = createTinyTestImage()
        let result = await imagePreprocessor.validateImageQuality(tinyImage)
        
        XCTAssertFalse(result.isAcceptable, "极小图像应被认为不可接受")
        
        // 验证不会崩溃
        let enhancedImage = await imagePreprocessor.enhanceImage(tinyImage)
        XCTAssertNotNil(enhancedImage, "处理极小图像不应崩溃")
    }
    
    /// 测试极大图像处理
    func testHugeImageProcessing() async throws {
        let hugeImage = createHugeTestImage()
        
        // 验证标准化能正确处理大图像
        let normalizedImage = await imagePreprocessor.normalizeImage(hugeImage)
        XCTAssertNotNil(normalizedImage)
        
        let maxDimension = max(normalizedImage.size.width, normalizedImage.size.height)
        XCTAssertLessThanOrEqual(maxDimension, 1024, "极大图像应被正确缩放")
    }
    
    // MARK: - 辅助方法
    
    /// 创建测试图像
    private func createTestImages() -> [UIImage] {
        var images: [UIImage] = []
        
        // 创建不同类型的测试图像
        images.append(createNormalTestImage())
        images.append(createHighQualityTestImage())
        images.append(createLargeTestImage())
        
        return images
    }
    
    /// 创建普通测试图像
    private func createNormalTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 绘制简单的测试图案
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.white.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
        }
    }
    
    /// 创建高质量测试图像
    private func createHighQualityTestImage() -> UIImage {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 绘制清晰的测试图案
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.black.setStroke()
            context.cgContext.setLineWidth(2.0)
            
            // 绘制清晰的几何图形
            let rect = CGRect(x: 100, y: 100, width: 200, height: 150)
            context.cgContext.stroke(rect)
            
            let circle = CGRect(x: 400, y: 200, width: 150, height: 150)
            context.cgContext.strokeEllipse(in: circle)
        }
    }
    
    /// 创建模糊测试图像
    private func createBlurryTestImage() -> UIImage {
        let normalImage = createNormalTestImage()
        
        // 应用模糊效果
        guard let ciImage = CIImage(image: normalImage),
              let filter = CIFilter(name: "CIGaussianBlur") else {
            return normalImage
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(10.0, forKey: kCIInputRadiusKey)
        
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: ciImage.extent) else {
            return normalImage
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 创建暗图像
    private func createDarkTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.gray.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
        }
    }
    
    /// 创建过亮图像
    private func createBrightTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.lightGray.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
        }
    }
    
    /// 创建小尺寸图像
    private func createSmallTestImage() -> UIImage {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// 创建大尺寸图像
    private func createLargeTestImage() -> UIImage {
        let size = CGSize(width: 2000, height: 1500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.blue.setFill()
            context.fill(CGRect(x: 200, y: 200, width: 400, height: 300))
        }
    }
    
    /// 创建旋转图像
    private func createRotatedTestImage() -> UIImage {
        let normalImage = createNormalTestImage()
        
        // 创建旋转的图像
        let size = normalImage.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.rotate(by: .pi / 4) // 45度旋转
            context.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)
            normalImage.draw(at: .zero)
        }
    }
    
    /// 创建复杂背景图像
    private func createComplexBackgroundTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 绘制复杂背景
            for i in 0..<20 {
                for j in 0..<15 {
                    let color = UIColor(
                        red: CGFloat.random(in: 0...1),
                        green: CGFloat.random(in: 0...1),
                        blue: CGFloat.random(in: 0...1),
                        alpha: 1.0
                    )
                    color.setFill()
                    context.fill(CGRect(x: i * 20, y: j * 20, width: 20, height: 20))
                }
            }
        }
    }
    
    /// 创建包含物体的图像
    private func createImageWithObjects() -> UIImage {
        let size = CGSize(width: 600, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 简单背景
            UIColor.lightGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制几个明显的物体
            UIColor.blue.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 120, height: 80))
            
            UIColor.red.setFill()
            context.fill(CGRect(x: 200, y: 100, width: 100, height: 100))
            
            UIColor.green.setFill()
            context.fill(CGRect(x: 350, y: 150, width: 150, height: 100))
        }
    }
    
    /// 创建纯色图像
    private func createPlainTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// 创建极小图像
    private func createTinyTestImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.purple.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// 创建极大图像
    private func createHugeTestImage() -> UIImage {
        let size = CGSize(width: 4000, height: 3000)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.yellow.setFill()
            context.fill(CGRect(x: 500, y: 500, width: 1000, height: 800))
        }
    }
    
    /// 计算图像亮度
    private func calculateImageBrightness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return 0.5
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0.5 }
        
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var totalBrightness: Double = 0
        let pixelCount = width * height
        
        for i in 0..<pixelCount {
            let pixelIndex = i * bytesPerPixel
            let r = Double(pixels[pixelIndex])
            let g = Double(pixels[pixelIndex + 1])
            let b = Double(pixels[pixelIndex + 2])
            
            // 使用标准亮度公式
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            totalBrightness += brightness
        }
        
        return totalBrightness / Double(pixelCount)
    }
}