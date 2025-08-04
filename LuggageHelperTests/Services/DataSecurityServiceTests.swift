import XCTest
import UIKit
@testable import LuggageHelper

// MARK: - 数据安全服务测试
/// 
/// 测试数据安全和隐私保护功能
/// 
/// 🧪 测试覆盖：
/// - 图像数据加密存储和加载
/// - 临时文件管理和自动清理
/// - 网络传输数据加密
/// - 用户数据控制和删除
/// - 安全统计和报告生成
/// 
/// 🔒 安全测试重点：
/// - 加密算法的正确性
/// - 数据完整性验证
/// - 安全删除的有效性
/// - 权限控制的严格性
@MainActor
final class DataSecurityServiceTests: XCTestCase {
    
    var securityService: DataSecurityService!
    var testImage: UIImage!
    var testIdentifier: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        securityService = DataSecurityService.shared
        
        // 创建测试图像
        testImage = createTestImage()
        testIdentifier = "test-image-\(UUID().uuidString)"
        
        // 清理之前的测试数据
        await securityService.deleteAllUserData()
    }
    
    override func tearDown() async throws {
        // 清理测试数据
        await securityService.deleteAllUserData()
        
        testImage = nil
        testIdentifier = nil
        securityService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 图像加密存储测试
    
    func testSecureImageStorage() async throws {
        // 测试图像安全存储
        let metadata = ["test": "metadata", "purpose": "unit_test"]
        
        let stored = await securityService.secureStoreImage(
            testImage,
            identifier: testIdentifier,
            metadata: metadata
        )
        
        XCTAssertTrue(stored, "图像应该成功存储")
        
        // 验证可以加载存储的图像
        let loadedImage = await securityService.secureLoadImage(identifier: testIdentifier)
        XCTAssertNotNil(loadedImage, "应该能够加载存储的图像")
        
        // 验证图像内容一致性（简单比较）
        XCTAssertEqual(testImage.size, loadedImage?.size, "加载的图像尺寸应该与原始图像一致")
    }
    
    func testSecureImageStorageWithInvalidData() async throws {
        // 测试无效图像数据的处理
        let invalidImage = UIImage() // 空图像
        
        let stored = await securityService.secureStoreImage(
            invalidImage,
            identifier: "invalid-test",
            metadata: [:]
        )
        
        // 应该处理无效数据而不崩溃
        // 具体行为取决于实现，这里假设返回false
        XCTAssertFalse(stored, "无效图像数据应该存储失败")
    }
    
    func testSecureImageDeletion() async throws {
        // 先存储图像
        let stored = await securityService.secureStoreImage(
            testImage,
            identifier: testIdentifier,
            metadata: [:]
        )
        XCTAssertTrue(stored, "图像应该成功存储")
        
        // 验证图像存在
        let loadedBefore = await securityService.secureLoadImage(identifier: testIdentifier)
        XCTAssertNotNil(loadedBefore, "删除前应该能够加载图像")
        
        // 删除图像
        await securityService.secureDeleteImage(identifier: testIdentifier)
        
        // 验证图像已被删除
        let loadedAfter = await securityService.secureLoadImage(identifier: testIdentifier)
        XCTAssertNil(loadedAfter, "删除后应该无法加载图像")
    }
    
    // MARK: - 临时文件管理测试
    
    func testTemporaryFileCreation() async throws {
        // 测试临时文件创建
        let tempFileURL = await securityService.createTemporaryImageFile(for: testImage)
        
        XCTAssertNotNil(tempFileURL, "应该成功创建临时文件")
        
        if let url = tempFileURL {
            // 验证文件存在
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "临时文件应该存在")
            
            // 验证文件内容
            let fileData = try Data(contentsOf: url)
            XCTAssertGreaterThan(fileData.count, 0, "临时文件应该包含数据")
            
            // 清理临时文件
            try FileManager.default.removeItem(at: url)
        }
    }
    
    func testTemporaryFileCleanup() async throws {
        // 创建多个临时文件
        var tempFiles: [URL] = []
        
        for i in 0..<3 {
            if let tempFile = await securityService.createTemporaryImageFile(for: testImage) {
                tempFiles.append(tempFile)
            }
        }
        
        XCTAssertEqual(tempFiles.count, 3, "应该创建3个临时文件")
        
        // 验证文件存在
        for url in tempFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "临时文件应该存在")
        }
        
        // 执行清理
        await securityService.cleanupAllTemporaryFiles()
        
        // 验证文件被清理
        for url in tempFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "临时文件应该被清理")
        }
    }
    
    // MARK: - 网络传输加密测试
    
    func testEncryptedTransmissionPacket() async throws {
        // 测试加密传输包的创建
        let encryptedPacket = await securityService.prepareEncryptedImageForTransmission(testImage)
        
        XCTAssertNotNil(encryptedPacket, "应该成功创建加密传输包")
        
        if let packet = encryptedPacket {
            XCTAssertGreaterThan(packet.encryptedData.count, 0, "加密数据应该不为空")
            XCTAssertEqual(packet.encryptionVersion, "AES-256-GCM-v1", "加密版本应该正确")
            
            // 测试解密
            let decryptedImage = await securityService.decryptImageFromTransmission(packet)
            XCTAssertNotNil(decryptedImage, "应该能够解密图像")
            
            if let decrypted = decryptedImage {
                XCTAssertEqual(testImage.size, decrypted.size, "解密后的图像尺寸应该一致")
            }
        }
    }
    
    func testEncryptionDecryptionRoundTrip() async throws {
        // 测试加密-解密往返过程
        guard let encryptedPacket = await securityService.prepareEncryptedImageForTransmission(testImage) else {
            XCTFail("无法创建加密包")
            return
        }
        
        guard let decryptedImage = await securityService.decryptImageFromTransmission(encryptedPacket) else {
            XCTFail("无法解密图像")
            return
        }
        
        // 比较原始图像和解密后图像的数据
        let originalData = testImage.jpegData(compressionQuality: 0.7) ?? Data()
        let decryptedData = decryptedImage.jpegData(compressionQuality: 0.7) ?? Data()
        
        // 由于JPEG压缩的特性，数据可能不完全相同，但应该非常接近
        let sizeDifference = abs(originalData.count - decryptedData.count)
        let maxAllowedDifference = originalData.count / 10 // 允许10%的差异
        
        XCTAssertLessThan(sizeDifference, maxAllowedDifference, "解密后的图像数据应该与原始数据接近")
    }
    
    // MARK: - 用户数据控制测试
    
    func testUserDataReport() async throws {
        // 先存储一些测试数据
        for i in 0..<3 {
            let identifier = "test-\(i)"
            let stored = await securityService.secureStoreImage(
                testImage,
                identifier: identifier,
                metadata: ["index": "\(i)"]
            )
            XCTAssertTrue(stored, "测试数据应该成功存储")
        }
        
        // 创建一些临时文件
        let tempFile1 = await securityService.createTemporaryImageFile(for: testImage)
        let tempFile2 = await securityService.createTemporaryImageFile(for: testImage)
        
        XCTAssertNotNil(tempFile1, "应该创建临时文件1")
        XCTAssertNotNil(tempFile2, "应该创建临时文件2")
        
        // 获取数据报告
        let report = await securityService.getUserDataReport()
        
        XCTAssertGreaterThan(report.secureStorageFiles.count, 0, "应该有安全存储文件")
        XCTAssertGreaterThan(report.temporaryFiles.count, 0, "应该有临时文件")
        XCTAssertGreaterThan(report.totalDataSize, 0, "总数据大小应该大于0")
        XCTAssertFalse(report.retentionPolicies.isEmpty, "应该有数据保留策略")
        
        // 清理临时文件
        if let url1 = tempFile1 { try? FileManager.default.removeItem(at: url1) }
        if let url2 = tempFile2 { try? FileManager.default.removeItem(at: url2) }
    }
    
    func testUserDataExport() async throws {
        // 存储测试数据
        let testIdentifiers = ["export-test-1", "export-test-2"]
        
        for identifier in testIdentifiers {
            let stored = await securityService.secureStoreImage(
                testImage,
                identifier: identifier,
                metadata: ["export": "test"]
            )
            XCTAssertTrue(stored, "测试数据应该成功存储")
        }
        
        // 导出数据
        let exportedData = await securityService.exportUserData()
        
        XCTAssertNotNil(exportedData, "应该成功导出数据")
        
        if let export = exportedData {
            XCTAssertGreaterThan(export.images.count, 0, "导出的数据应该包含图像")
            XCTAssertNotNil(export.dataReport, "导出的数据应该包含报告")
            XCTAssertNotNil(export.securityStatistics, "导出的数据应该包含安全统计")
            
            // 验证导出的图像数据
            for imageData in export.images {
                XCTAssertGreaterThan(imageData.imageData.count, 0, "导出的图像数据应该不为空")
                XCTAssertFalse(imageData.identifier.isEmpty, "导出的图像应该有标识符")
            }
        }
    }
    
    func testDeleteAllUserData() async throws {
        // 存储测试数据
        for i in 0..<5 {
            let identifier = "delete-test-\(i)"
            let stored = await securityService.secureStoreImage(
                testImage,
                identifier: identifier,
                metadata: ["delete": "test"]
            )
            XCTAssertTrue(stored, "测试数据应该成功存储")
        }
        
        // 验证数据存在
        let reportBefore = await securityService.getUserDataReport()
        XCTAssertGreaterThan(reportBefore.secureStorageFiles.count, 0, "删除前应该有数据")
        
        // 删除所有数据
        let deleteSuccess = await securityService.deleteAllUserData()
        XCTAssertTrue(deleteSuccess, "删除操作应该成功")
        
        // 验证数据被删除
        let reportAfter = await securityService.getUserDataReport()
        XCTAssertEqual(reportAfter.secureStorageFiles.count, 0, "删除后应该没有安全存储文件")
        XCTAssertEqual(reportAfter.temporaryFiles.count, 0, "删除后应该没有临时文件")
    }
    
    // MARK: - 安全统计测试
    
    func testSecurityStatistics() async throws {
        let initialStats = securityService.securityStatistics
        
        // 执行一些操作来更新统计
        let stored = await securityService.secureStoreImage(
            testImage,
            identifier: testIdentifier,
            metadata: [:]
        )
        XCTAssertTrue(stored, "存储操作应该成功")
        
        let loaded = await securityService.secureLoadImage(identifier: testIdentifier)
        XCTAssertNotNil(loaded, "加载操作应该成功")
        
        await securityService.secureDeleteImage(identifier: testIdentifier)
        
        // 验证统计信息更新
        let updatedStats = securityService.securityStatistics
        
        XCTAssertGreaterThan(updatedStats.totalStoreOperations, initialStats.totalStoreOperations, "存储操作计数应该增加")
        XCTAssertGreaterThan(updatedStats.totalLoadOperations, initialStats.totalLoadOperations, "加载操作计数应该增加")
        XCTAssertGreaterThan(updatedStats.totalDeleteOperations, initialStats.totalDeleteOperations, "删除操作计数应该增加")
        
        // 验证成功率计算
        XCTAssertGreaterThan(updatedStats.storeSuccessRate, 0, "存储成功率应该大于0")
        XCTAssertGreaterThan(updatedStats.loadSuccessRate, 0, "加载成功率应该大于0")
        XCTAssertGreaterThan(updatedStats.deleteSuccessRate, 0, "删除成功率应该大于0")
    }
    
    // MARK: - 性能测试
    
    func testStoragePerformance() async throws {
        let imageCount = 10
        let startTime = Date()
        
        // 批量存储图像
        for i in 0..<imageCount {
            let identifier = "perf-test-\(i)"
            let stored = await securityService.secureStoreImage(
                testImage,
                identifier: identifier,
                metadata: ["performance": "test"]
            )
            XCTAssertTrue(stored, "性能测试图像应该成功存储")
        }
        
        let storageTime = Date().timeIntervalSince(startTime)
        
        // 批量加载图像
        let loadStartTime = Date()
        
        for i in 0..<imageCount {
            let identifier = "perf-test-\(i)"
            let loaded = await securityService.secureLoadImage(identifier: identifier)
            XCTAssertNotNil(loaded, "性能测试图像应该成功加载")
        }
        
        let loadTime = Date().timeIntervalSince(loadStartTime)
        
        // 性能断言（这些值可能需要根据实际性能调整）
        XCTAssertLessThan(storageTime, 10.0, "存储\(imageCount)个图像应该在10秒内完成")
        XCTAssertLessThan(loadTime, 5.0, "加载\(imageCount)个图像应该在5秒内完成")
        
        print("存储性能: \(String(format: "%.2f", storageTime))秒")
        print("加载性能: \(String(format: "%.2f", loadTime))秒")
    }
    
    // MARK: - 边界条件测试
    
    func testLargeImageHandling() async throws {
        // 创建大图像进行测试
        let largeImage = createLargeTestImage(size: CGSize(width: 2000, height: 2000))
        let identifier = "large-image-test"
        
        let stored = await securityService.secureStoreImage(
            largeImage,
            identifier: identifier,
            metadata: [:]
        )
        
        // 大图像应该能够正常处理
        XCTAssertTrue(stored, "大图像应该能够成功存储")
        
        let loaded = await securityService.secureLoadImage(identifier: identifier)
        XCTAssertNotNil(loaded, "大图像应该能够成功加载")
        
        if let loadedImage = loaded {
            XCTAssertEqual(largeImage.size, loadedImage.size, "加载的大图像尺寸应该正确")
        }
        
        await securityService.secureDeleteImage(identifier: identifier)
    }
    
    func testConcurrentOperations() async throws {
        let operationCount = 5
        let testIdentifiers = (0..<operationCount).map { "concurrent-test-\($0)" }
        
        // 并发存储操作
        await withTaskGroup(of: Bool.self) { group in
            for identifier in testIdentifiers {
                group.addTask {
                    return await self.securityService.secureStoreImage(
                        self.testImage,
                        identifier: identifier,
                        metadata: ["concurrent": "test"]
                    )
                }
            }
            
            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
            }
            
            XCTAssertEqual(successCount, operationCount, "所有并发存储操作应该成功")
        }
        
        // 并发加载操作
        await withTaskGroup(of: UIImage?.self) { group in
            for identifier in testIdentifiers {
                group.addTask {
                    return await self.securityService.secureLoadImage(identifier: identifier)
                }
            }
            
            var loadedCount = 0
            for await image in group {
                if image != nil {
                    loadedCount += 1
                }
            }
            
            XCTAssertEqual(loadedCount, operationCount, "所有并发加载操作应该成功")
        }
        
        // 清理测试数据
        for identifier in testIdentifiers {
            await securityService.secureDeleteImage(identifier: identifier)
        }
    }
    
    // MARK: - 辅助方法
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createLargeTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // 创建渐变背景
        let context = UIGraphicsGetCurrentContext()
        let colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)
        
        context?.drawLinearGradient(
            gradient!,
            start: CGPoint.zero,
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}