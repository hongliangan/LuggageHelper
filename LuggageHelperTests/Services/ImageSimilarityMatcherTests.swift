import XCTest
import UIKit
@testable import LuggageHelper

// MARK: - 图像相似度匹配器测试
/// 
/// 测试图像相似度匹配算法的准确性和性能
/// 
/// 🧪 测试覆盖：
/// - 感知哈希算法
/// - 相似度计算准确性
/// - 特征提取和匹配
/// - 颜色直方图比较
/// - 性能基准测试
@MainActor
class ImageSimilarityMatcherTests: XCTestCase {
    
    var similarityMatcher: ImageSimilarityMatcher!
    
    override func setUp() async throws {
        try await super.setUp()
        similarityMatcher = ImageSimilarityMatcher()
    }
    
    override func tearDown() async throws {
        similarityMatcher.clearCache()
        similarityMatcher = nil
        try await super.tearDown()
    }
    
    // MARK: - 基本相似度测试
    
    func testIdenticalImagesSimilarity() async throws {
        let image1 = createSolidColorImage(color: .red, size: CGSize(width: 100, height: 100))
        let image2 = createSolidColorImage(color: .red, size: CGSize(width: 100, height: 100))
        
        let similarity = await similarityMatcher.calculateSimilarity(between: image1, and: image2)
        
        // 相同图像的相似度应该很高
        XCTAssertGreaterThan(similarity, 0.9, "相同图像的相似度应该大于0.9")
    }
    
    func testDifferentImagesSimilarity() async throws {
        let redImage = createSolidColorImage(color: .red, size: CGSize(width: 100, height: 100))
        let blueImage = createSolidColorImage(color: .blue, size: CGSize(width: 100, height: 100))
        
        let similarity = await similarityMatcher.calculateSimilarity(between: redImage, and: blueImage)
        
        // 不同颜色图像的相似度应该较低
        XCTAssertLessThan(similarity, 0.7, "不同颜色图像的相似度应该小于0.7")
    }
    
    func testSimilarSizedImagesSimilarity() async throws {
        let image1 = createSolidColorImage(color: .green, size: CGSize(width: 100, height: 100))
        let image2 = createSolidColorImage(color: .green, size: CGSize(width: 102, height: 98))
        
        let similarity = await similarityMatcher.calculateSimilarity(between: image1, and: image2)
        
        // 相似大小的相同颜色图像应该有高相似度
        XCTAssertGreaterThan(similarity, 0.8, "相似大小的相同颜色图像相似度应该大于0.8")
    }
    
    // MARK: - 感知哈希测试
    
    func testPerceptualHashConsistency() async throws {
        let testImage = createSolidColorImage(color: .purple, size: CGSize(width: 100, height: 100))
        
        let hash1 = await similarityMatcher.generatePerceptualHash(testImage)
        let hash2 = await similarityMatcher.generatePerceptualHash(testImage)
        
        // 相同图像应该产生相同的哈希
        XCTAssertEqual(hash1, hash2, "相同图像应该产生相同的感知哈希")
        XCTAssertFalse(hash1.isEmpty, "感知哈希不应该为空")
    }
    
    func testPerceptualHashFormat() async throws {
        let testImage = createSolidColorImage(color: .orange, size: CGSize(width: 100, height: 100))
        
        let hash = await similarityMatcher.generatePerceptualHash(testImage)
        
        // 验证哈希格式
        XCTAssertFalse(hash.isEmpty, "哈希不应该为空")
        XCTAssertTrue(hash.allSatisfy { $0 == "0" || $0 == "1" }, "哈希应该只包含0和1")
        XCTAssertEqual(hash.count, 63, "哈希长度应该是63位（8x8-1）")
    }
    
    func testPerceptualHashDifference() async throws {
        let redImage = createSolidColorImage(color: .red, size: CGSize(width: 100, height: 100))
        let blueImage = createSolidColorImage(color: .blue, size: CGSize(width: 100, height: 100))
        
        let redHash = await similarityMatcher.generatePerceptualHash(redImage)
        let blueHash = await similarityMatcher.generatePerceptualHash(blueImage)
        
        // 不同图像应该产生不同的哈希
        XCTAssertNotEqual(redHash, blueHash, "不同图像应该产生不同的感知哈希")
    }
    
    // MARK: - 相似图像查找测试
    
    func testFindSimilarImages() async throws {
        let targetImage = createSolidColorImage(color: .cyan, size: CGSize(width: 100, height: 100))
        
        // 创建缓存图像数组
        let cachedImages = [
            createCachedImage(color: .cyan, size: CGSize(width: 100, height: 100), hash: "hash1"),
            createCachedImage(color: .cyan, size: CGSize(width: 105, height: 95), hash: "hash2"),
            createCachedImage(color: .red, size: CGSize(width: 100, height: 100), hash: "hash3"),
            createCachedImage(color: .blue, size: CGSize(width: 100, height: 100), hash: "hash4")
        ]
        
        let similarImages = await similarityMatcher.findSimilarImages(
            to: targetImage,
            in: cachedImages,
            threshold: 0.7
        )
        
        // 应该找到相似的图像
        XCTAssertGreaterThan(similarImages.count, 0, "应该找到相似的图像")
        
        // 验证相似度排序
        for i in 0..<(similarImages.count - 1) {
            XCTAssertGreaterThanOrEqual(
                similarImages[i].similarity,
                similarImages[i + 1].similarity,
                "相似图像应该按相似度降序排列"
            )
        }
        
        // 验证相似度阈值
        for similarImage in similarImages {
            XCTAssertGreaterThanOrEqual(
                similarImage.similarity,
                0.7,
                "所有返回的图像相似度都应该大于等于阈值"
            )
        }
    }
    
    func testFindSimilarImagesWithHighThreshold() async throws {
        let targetImage = createSolidColorImage(color: .yellow, size: CGSize(width: 100, height: 100))
        
        let cachedImages = [
            createCachedImage(color: .yellow, size: CGSize(width: 100, height: 100), hash: "hash1"),
            createCachedImage(color: .orange, size: CGSize(width: 100, height: 100), hash: "hash2"),
            createCachedImage(color: .red, size: CGSize(width: 100, height: 100), hash: "hash3")
        ]
        
        let similarImages = await similarityMatcher.findSimilarImages(
            to: targetImage,
            in: cachedImages,
            threshold: 0.95
        )
        
        // 高阈值应该返回更少的结果
        XCTAssertLessThanOrEqual(similarImages.count, 1, "高阈值应该返回更少的相似图像")
        
        if !similarImages.isEmpty {
            XCTAssertGreaterThanOrEqual(similarImages[0].similarity, 0.95, "返回的图像相似度应该满足高阈值")
        }
    }
    
    // MARK: - 缓存测试
    
    func testCacheEffectiveness() async throws {
        let testImage = createSolidColorImage(color: .magenta, size: CGSize(width: 100, height: 100))
        
        // 第一次计算（应该缓存结果）
        let startTime1 = Date()
        let hash1 = await similarityMatcher.generatePerceptualHash(testImage)
        let time1 = Date().timeIntervalSince(startTime1)
        
        // 第二次计算（应该使用缓存）
        let startTime2 = Date()
        let hash2 = await similarityMatcher.generatePerceptualHash(testImage)
        let time2 = Date().timeIntervalSince(startTime2)
        
        // 验证缓存效果
        XCTAssertEqual(hash1, hash2, "缓存的哈希应该相同")
        XCTAssertLessThan(time2, time1, "缓存的计算应该更快")
    }
    
    func testCacheClear() async throws {
        let testImage = createSolidColorImage(color: .brown, size: CGSize(width: 100, height: 100))
        
        // 计算哈希以填充缓存
        _ = await similarityMatcher.generatePerceptualHash(testImage)
        
        // 清理缓存
        similarityMatcher.clearCache()
        
        // 再次计算应该重新计算而不是使用缓存
        let hash = await similarityMatcher.generatePerceptualHash(testImage)
        XCTAssertFalse(hash.isEmpty, "清理缓存后仍应该能够计算哈希")
    }
    
    // MARK: - 边界情况测试
    
    func testEmptyImageHandling() async throws {
        let emptyImage = UIImage()
        let normalImage = createSolidColorImage(color: .gray, size: CGSize(width: 100, height: 100))
        
        let similarity = await similarityMatcher.calculateSimilarity(between: emptyImage, and: normalImage)
        
        // 空图像的相似度应该很低
        XCTAssertLessThan(similarity, 0.1, "空图像与正常图像的相似度应该很低")
    }
    
    func testVerySmallImageHandling() async throws {
        let smallImage1 = createSolidColorImage(color: .red, size: CGSize(width: 1, height: 1))
        let smallImage2 = createSolidColorImage(color: .red, size: CGSize(width: 1, height: 1))
        
        let similarity = await similarityMatcher.calculateSimilarity(between: smallImage1, and: smallImage2)
        
        // 即使是很小的图像也应该能够计算相似度
        XCTAssertGreaterThanOrEqual(similarity, 0.0, "相似度应该是有效值")
        XCTAssertLessThanOrEqual(similarity, 1.0, "相似度应该不超过1.0")
    }
    
    func testVeryLargeImageHandling() async throws {
        let largeImage1 = createSolidColorImage(color: .green, size: CGSize(width: 1000, height: 1000))
        let largeImage2 = createSolidColorImage(color: .green, size: CGSize(width: 1000, height: 1000))
        
        let startTime = Date()
        let similarity = await similarityMatcher.calculateSimilarity(between: largeImage1, and: largeImage2)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // 大图像处理应该在合理时间内完成
        XCTAssertLessThan(processingTime, 2.0, "大图像处理应该在2秒内完成")
        XCTAssertGreaterThan(similarity, 0.9, "相同的大图像应该有高相似度")
    }
    
    // MARK: - 性能测试
    
    func testSimilarityCalculationPerformance() async throws {
        let image1 = createSolidColorImage(color: .red, size: CGSize(width: 200, height: 200))
        let image2 = createSolidColorImage(color: .blue, size: CGSize(width: 200, height: 200))
        
        // 测量性能
        let startTime = Date()
        let similarity = await similarityMatcher.calculateSimilarity(between: image1, and: image2)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // 验证性能要求
        XCTAssertLessThan(processingTime, 0.5, "相似度计算应该在500ms内完成")
        XCTAssertGreaterThanOrEqual(similarity, 0.0, "相似度应该是有效值")
        XCTAssertLessThanOrEqual(similarity, 1.0, "相似度应该不超过1.0")
    }
    
    func testBatchSimilarityCalculationPerformance() async throws {
        let targetImage = createSolidColorImage(color: .purple, size: CGSize(width: 100, height: 100))
        
        // 创建多个测试图像
        var testImages: [UIImage] = []
        for i in 0..<10 {
            let hue = CGFloat(i) / 10.0
            let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            testImages.append(createSolidColorImage(color: color, size: CGSize(width: 100, height: 100)))
        }
        
        // 批量计算相似度
        let startTime = Date()
        var similarities: [Double] = []
        
        for testImage in testImages {
            let similarity = await similarityMatcher.calculateSimilarity(between: targetImage, and: testImage)
            similarities.append(similarity)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(testImages.count)
        
        // 验证批量处理性能
        XCTAssertLessThan(averageTime, 0.2, "平均相似度计算时间应该小于200ms")
        XCTAssertEqual(similarities.count, testImages.count, "应该计算所有图像的相似度")
    }
    
    // MARK: - 算法准确性测试
    
    func testGradientImagesSimilarity() async throws {
        let gradient1 = createGradientImage(
            from: .red,
            to: .blue,
            size: CGSize(width: 100, height: 100),
            direction: .horizontal
        )
        let gradient2 = createGradientImage(
            from: .red,
            to: .blue,
            size: CGSize(width: 100, height: 100),
            direction: .horizontal
        )
        let gradient3 = createGradientImage(
            from: .red,
            to: .blue,
            size: CGSize(width: 100, height: 100),
            direction: .vertical
        )
        
        let similarity12 = await similarityMatcher.calculateSimilarity(between: gradient1, and: gradient2)
        let similarity13 = await similarityMatcher.calculateSimilarity(between: gradient1, and: gradient3)
        
        // 相同方向的渐变应该更相似
        XCTAssertGreaterThan(similarity12, similarity13, "相同方向的渐变应该更相似")
        XCTAssertGreaterThan(similarity12, 0.7, "相同渐变的相似度应该较高")
    }
    
    func testPatternImagesSimilarity() async throws {
        let checkerboard1 = createCheckerboardImage(size: CGSize(width: 100, height: 100), squareSize: 10)
        let checkerboard2 = createCheckerboardImage(size: CGSize(width: 100, height: 100), squareSize: 10)
        let checkerboard3 = createCheckerboardImage(size: CGSize(width: 100, height: 100), squareSize: 20)
        
        let similarity12 = await similarityMatcher.calculateSimilarity(between: checkerboard1, and: checkerboard2)
        let similarity13 = await similarityMatcher.calculateSimilarity(between: checkerboard1, and: checkerboard3)
        
        // 相同模式的图像应该更相似
        XCTAssertGreaterThan(similarity12, similarity13, "相同模式的图像应该更相似")
        XCTAssertGreaterThan(similarity12, 0.8, "相同棋盘模式的相似度应该很高")
    }
    
    // MARK: - 辅助方法
    
    private func createSolidColorImage(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createCachedImage(color: UIColor, size: CGSize, hash: String) -> CachedImage {
        let image = createSolidColorImage(color: color, size: size)
        let metadata = ImageMetadata(
            width: Int(size.width),
            height: Int(size.height),
            fileSize: 1024,
            format: "JPEG",
            dominantColors: ["#FF0000"],
            brightness: 0.5,
            contrast: 0.5,
            hasText: false,
            estimatedObjects: 1
        )
        
        return CachedImage(
            image: image,
            hash: hash,
            metadata: metadata,
            timestamp: Date()
        )
    }
    
    private func createGradientImage(from startColor: UIColor, to endColor: UIColor, size: CGSize, direction: GradientDirection) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [startColor.cgColor, endColor.cgColor]
        let locations: [CGFloat] = [0.0, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
            return UIImage()
        }
        
        let startPoint: CGPoint
        let endPoint: CGPoint
        
        switch direction {
        case .horizontal:
            startPoint = CGPoint(x: 0, y: size.height / 2)
            endPoint = CGPoint(x: size.width, y: size.height / 2)
        case .vertical:
            startPoint = CGPoint(x: size.width / 2, y: 0)
            endPoint = CGPoint(x: size.width / 2, y: size.height)
        }
        
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createCheckerboardImage(size: CGSize, squareSize: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        
        let rows = Int(size.height / squareSize)
        let cols = Int(size.width / squareSize)
        
        for row in 0..<rows {
            for col in 0..<cols {
                let isBlack = (row + col) % 2 == 0
                let color = isBlack ? UIColor.black : UIColor.white
                
                context.setFillColor(color.cgColor)
                let rect = CGRect(
                    x: CGFloat(col) * squareSize,
                    y: CGFloat(row) * squareSize,
                    width: squareSize,
                    height: squareSize
                )
                context.fill(rect)
            }
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private enum GradientDirection {
        case horizontal
        case vertical
    }
}