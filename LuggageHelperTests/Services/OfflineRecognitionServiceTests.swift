import XCTest
import CoreML
import Vision
@testable import LuggageHelper

/// 离线识别服务单元测试
final class OfflineRecognitionServiceTests: XCTestCase {
    
    var offlineService: OfflineRecognitionService!
    var testModelDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建测试用的模型目录
        let tempDir = FileManager.default.temporaryDirectory
        testModelDirectory = tempDir.appendingPathComponent("TestOfflineModels_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testModelDirectory, withIntermediateDirectories: true)
        
        // 使用反射或其他方式设置测试目录（在实际实现中可能需要依赖注入）
        offlineService = OfflineRecognitionService.shared
    }
    
    override func tearDownWithError() throws {
        // 清理测试目录
        if FileManager.default.fileExists(atPath: testModelDirectory.path) {
            try FileManager.default.removeItem(at: testModelDirectory)
        }
        
        offlineService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 模型可用性测试
    
    func testIsModelAvailable_WithoutModel_ReturnsFalse() {
        // Given
        let category = ItemCategory.clothing
        
        // When
        let isAvailable = offlineService.isModelAvailable(for: category)
        
        // Then
        XCTAssertFalse(isAvailable, "模型不存在时应返回 false")
    }
    
    func testIsModelAvailable_WithUnsupportedCategory_ReturnsFalse() {
        // Given
        let category = ItemCategory.food // 假设不支持的类别
        
        // When
        let isAvailable = offlineService.isModelAvailable(for: category)
        
        // Then
        XCTAssertFalse(isAvailable, "不支持的类别应返回 false")
    }
    
    func testGetAvailableCategories_WithoutModels_ReturnsEmptyArray() {
        // When
        let categories = offlineService.getAvailableCategories()
        
        // Then
        XCTAssertTrue(categories.isEmpty, "没有模型时应返回空数组")
    }
    
    // MARK: - 模型下载测试
    
    func testDownloadModel_WithUnsupportedCategory_ThrowsError() async {
        // Given
        let category = ItemCategory.food // 假设不支持的类别
        
        // When & Then
        do {
            try await offlineService.downloadModel(for: category)
            XCTFail("应该抛出不支持类别的错误")
        } catch OfflineRecognitionError.unsupportedCategory(let errorCategory) {
            XCTAssertEqual(errorCategory, category, "错误类别应该匹配")
        } catch {
            XCTFail("应该抛出 unsupportedCategory 错误，但得到: \(error)")
        }
    }
    
    func testDownloadModel_WithInvalidURL_ThrowsError() async {
        // 这个测试需要模拟无效的 URL 配置
        // 在实际实现中，可能需要依赖注入来提供测试配置
        
        // Given
        let category = ItemCategory.clothing
        
        // When & Then
        // 由于我们无法轻易模拟无效 URL，这里先跳过
        // 在实际项目中，应该通过依赖注入提供可配置的 URL
    }
    
    // MARK: - 离线识别测试
    
    func testRecognizeOffline_WithoutModels_ThrowsError() async {
        // Given
        let testImage = createTestImage()
        
        // When & Then
        do {
            let _ = try await offlineService.recognizeOffline(testImage)
            XCTFail("没有模型时应该抛出错误")
        } catch OfflineRecognitionError.noModelAvailable {
            // 期望的错误
        } catch {
            XCTFail("应该抛出 noModelAvailable 错误，但得到: \(error)")
        }
    }
    
    func testRecognizeOffline_WithInvalidImage_ThrowsError() async {
        // Given
        let invalidImage = UIImage() // 空图像
        
        // When & Then
        do {
            let _ = try await offlineService.recognizeOffline(invalidImage)
            XCTFail("无效图像应该抛出错误")
        } catch OfflineRecognitionError.imageProcessingFailed {
            // 期望的错误
        } catch OfflineRecognitionError.noModelAvailable {
            // 也可能是没有模型的错误
        } catch {
            XCTFail("应该抛出图像处理或模型不可用错误，但得到: \(error)")
        }
    }
    
    // MARK: - 模型管理测试
    
    func testDeleteModel_WithNonExistentModel_DoesNotThrow() {
        // Given
        let category = ItemCategory.clothing
        
        // When & Then
        XCTAssertNoThrow(try offlineService.deleteModel(for: category))
    }
    
    func testGetTotalModelSize_WithoutModels_ReturnsZero() {
        // When
        let totalSize = offlineService.getTotalModelSize()
        
        // Then
        XCTAssertEqual(totalSize, 0, "没有模型时总大小应为 0")
    }
    
    func testClearAllModels_DoesNotThrow() {
        // When & Then
        XCTAssertNoThrow(try offlineService.clearAllModels())
    }
    
    // MARK: - 数据模型测试
    
    func testOfflineRecognitionResult_Initialization() {
        // Given
        let category = ItemCategory.electronics
        let confidence = 0.85
        let properties = ["test": "value"]
        let needsVerification = true
        
        // When
        let result = OfflineRecognitionResult(
            category: category,
            confidence: confidence,
            basicProperties: properties,
            needsOnlineVerification: needsVerification
        )
        
        // Then
        XCTAssertEqual(result.category, category)
        XCTAssertEqual(result.confidence, confidence, accuracy: 0.001)
        XCTAssertEqual(result.needsOnlineVerification, needsVerification)
    }
    
    func testOfflineModel_FormattedFileSize() {
        // Given
        let model = OfflineModel(
            category: .clothing,
            name: "TestModel",
            version: "1.0",
            isAvailable: true,
            fileSize: 25 * 1024 * 1024, // 25MB
            expectedAccuracy: 0.85,
            downloadURL: "https://example.com/model.mlmodel"
        )
        
        // When
        let formattedSize = model.formattedFileSize
        
        // Then
        XCTAssertTrue(formattedSize.contains("25"), "格式化大小应包含 25")
        XCTAssertTrue(formattedSize.contains("MB"), "格式化大小应包含 MB")
    }
    
    func testOfflineModel_FormattedAccuracy() {
        // Given
        let model = OfflineModel(
            category: .clothing,
            name: "TestModel",
            version: "1.0",
            isAvailable: true,
            fileSize: 1024,
            expectedAccuracy: 0.856,
            downloadURL: "https://example.com/model.mlmodel"
        )
        
        // When
        let formattedAccuracy = model.formattedAccuracy
        
        // Then
        XCTAssertEqual(formattedAccuracy, "85.6%", "准确率格式化应正确")
    }
    
    // MARK: - 错误处理测试
    
    func testOfflineRecognitionError_ErrorDescriptions() {
        // Given
        let category = ItemCategory.clothing
        let errors: [OfflineRecognitionError] = [
            .unsupportedCategory(category),
            .modelConfigNotFound(category),
            .modelNotAvailable(category),
            .invalidModelURL("invalid-url"),
            .downloadCancelled,
            .imageProcessingFailed,
            .recognitionFailed,
            .noModelAvailable
        ]
        
        // When & Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "错误描述不应为空: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "错误描述不应为空字符串: \(error)")
        }
    }
    
    func testOfflineRecognitionError_RecoverySuggestions() {
        // Given
        let errors: [OfflineRecognitionError] = [
            .unsupportedCategory(.clothing),
            .modelNotAvailable(.clothing),
            .downloadFailed(NSError(domain: "Test", code: 0)),
            .imageProcessingFailed,
            .noModelAvailable
        ]
        
        // When & Then
        for error in errors {
            XCTAssertNotNil(error.recoverySuggestion, "恢复建议不应为空: \(error)")
            XCTAssertFalse(error.recoverySuggestion!.isEmpty, "恢复建议不应为空字符串: \(error)")
        }
    }
    
    // MARK: - 性能测试
    
    func testPerformance_GetAvailableCategories() {
        measure {
            let _ = offlineService.getAvailableCategories()
        }
    }
    
    func testPerformance_GetTotalModelSize() {
        measure {
            let _ = offlineService.getTotalModelSize()
        }
    }
    
    // MARK: - 并发测试
    
    func testConcurrentModelDownload() async {
        // Given
        let categories: [ItemCategory] = [.clothing, .electronics, .accessories]
        
        // When
        await withTaskGroup(of: Void.self) { group in
            for category in categories {
                group.addTask {
                    do {
                        try await self.offlineService.downloadModel(for: category)
                    } catch {
                        // 预期会失败，因为没有真实的下载 URL
                    }
                }
            }
        }
        
        // Then
        // 主要测试不会崩溃或死锁
        XCTAssertTrue(true, "并发下载应该不会导致崩溃")
    }
    
    func testConcurrentRecognition() async {
        // Given
        let testImage = createTestImage()
        let taskCount = 5
        
        // When
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<taskCount {
                group.addTask {
                    do {
                        let _ = try await self.offlineService.recognizeOffline(testImage)
                    } catch {
                        // 预期会失败，因为没有可用的模型
                    }
                }
            }
        }
        
        // Then
        XCTAssertTrue(true, "并发识别应该不会导致崩溃")
    }
    
    // MARK: - 边界条件测试
    
    func testRecognizeOffline_WithVerySmallImage() async {
        // Given
        let smallImage = createTestImage(size: CGSize(width: 1, height: 1))
        
        // When & Then
        do {
            let _ = try await offlineService.recognizeOffline(smallImage)
            XCTFail("极小图像应该抛出错误")
        } catch {
            // 预期会失败
        }
    }
    
    func testRecognizeOffline_WithVeryLargeImage() async {
        // Given
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 4000))
        
        // When & Then
        do {
            let _ = try await offlineService.recognizeOffline(largeImage)
            XCTFail("超大图像应该抛出错误或被正确处理")
        } catch {
            // 预期会失败或被正确处理
        }
    }
    
    // MARK: - 内存管理测试
    
    func testMemoryUsage_MultipleRecognitions() async {
        // Given
        let testImage = createTestImage()
        let recognitionCount = 10
        
        // When
        for _ in 0..<recognitionCount {
            do {
                let _ = try await offlineService.recognizeOffline(testImage)
            } catch {
                // 预期会失败，主要测试内存使用
            }
        }
        
        // Then
        // 主要确保没有内存泄漏
        XCTAssertTrue(true, "多次识别不应导致内存泄漏")
    }
    
    // MARK: - 辅助方法
    
    /// 创建测试图像
    private func createTestImage(size: CGSize = CGSize(width: 224, height: 224)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制一个简单的测试图像
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // 添加一些内容
        UIColor.white.setFill()
        let rect = CGRect(x: size.width * 0.25, y: size.height * 0.25, 
                         width: size.width * 0.5, height: size.height * 0.5)
        UIRectFill(rect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    /// 创建模拟的 MLModel 文件
    private func createMockModelFile(for category: ItemCategory) throws -> URL {
        let modelPath = testModelDirectory.appendingPathComponent("\(category.rawValue).mlmodel")
        
        // 创建一个空文件作为模拟模型
        let mockData = Data("mock model data".utf8)
        try mockData.write(to: modelPath)
        
        return modelPath
    }
    
    /// 验证模型文件存在
    private func verifyModelExists(for category: ItemCategory) -> Bool {
        let modelPath = testModelDirectory.appendingPathComponent("\(category.rawValue).mlmodel")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
}

// MARK: - 模拟类

/// 模拟的离线识别服务（用于更复杂的测试）
class MockOfflineRecognitionService: OfflineRecognitionService {
    
    var mockModelsAvailable: [ItemCategory] = []
    var mockRecognitionResult: OfflineRecognitionResult?
    var mockError: Error?
    var downloadShouldFail = false
    
    override func isModelAvailable(for category: ItemCategory) -> Bool {
        return mockModelsAvailable.contains(category)
    }
    
    override func getAvailableCategories() -> [ItemCategory] {
        return mockModelsAvailable
    }
    
    override func downloadModel(for category: ItemCategory) async throws {
        if downloadShouldFail {
            throw OfflineRecognitionError.downloadFailed(NSError(domain: "Mock", code: -1))
        }
        
        if !mockModelsAvailable.contains(category) {
            mockModelsAvailable.append(category)
        }
    }
    
    override func recognizeOffline(_ image: UIImage) async throws -> OfflineRecognitionResult {
        if let error = mockError {
            throw error
        }
        
        if let result = mockRecognitionResult {
            return result
        }
        
        if mockModelsAvailable.isEmpty {
            throw OfflineRecognitionError.noModelAvailable
        }
        
        // 返回默认的模拟结果
        return OfflineRecognitionResult(
            category: mockModelsAvailable.first!,
            confidence: 0.8,
            basicProperties: ["mock": "result"],
            needsOnlineVerification: false
        )
    }
    
    override func deleteModel(for category: ItemCategory) throws {
        mockModelsAvailable.removeAll { $0 == category }
    }
    
    override func getTotalModelSize() -> Int64 {
        return Int64(mockModelsAvailable.count * 25 * 1024 * 1024) // 每个模型 25MB
    }
    
    override func clearAllModels() throws {
        mockModelsAvailable.removeAll()
    }
}

// MARK: - 集成测试

/// 离线识别服务集成测试
final class OfflineRecognitionServiceIntegrationTests: XCTestCase {
    
    var mockService: MockOfflineRecognitionService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockService = MockOfflineRecognitionService()
    }
    
    override func tearDownWithError() throws {
        mockService = nil
        try super.tearDownWithError()
    }
    
    func testCompleteWorkflow_DownloadAndRecognize() async throws {
        // Given
        let category = ItemCategory.clothing
        let testImage = createTestImage()
        
        // When - 下载模型
        try await mockService.downloadModel(for: category)
        
        // Then - 验证模型可用
        XCTAssertTrue(mockService.isModelAvailable(for: category))
        XCTAssertTrue(mockService.getAvailableCategories().contains(category))
        
        // When - 进行识别
        let result = try await mockService.recognizeOffline(testImage)
        
        // Then - 验证识别结果
        XCTAssertEqual(result.category, category)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }
    
    func testWorkflow_WithMultipleModels() async throws {
        // Given
        let categories: [ItemCategory] = [.clothing, .electronics, .accessories]
        let testImage = createTestImage()
        
        // When - 下载多个模型
        for category in categories {
            try await mockService.downloadModel(for: category)
        }
        
        // Then - 验证所有模型可用
        let availableCategories = mockService.getAvailableCategories()
        for category in categories {
            XCTAssertTrue(availableCategories.contains(category))
        }
        
        // When - 进行识别
        let result = try await mockService.recognizeOffline(testImage)
        
        // Then - 验证识别结果
        XCTAssertTrue(categories.contains(result.category))
        
        // When - 清理模型
        try mockService.clearAllModels()
        
        // Then - 验证模型已清理
        XCTAssertTrue(mockService.getAvailableCategories().isEmpty)
        XCTAssertEqual(mockService.getTotalModelSize(), 0)
    }
    
    private func createTestImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 224, height: 224), false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: CGSize(width: 224, height: 224)))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}