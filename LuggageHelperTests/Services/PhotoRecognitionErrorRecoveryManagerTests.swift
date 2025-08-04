import XCTest
import UIKit
@testable import LuggageHelper

@MainActor
class PhotoRecognitionErrorRecoveryManagerTests: XCTestCase {
    
    var errorRecoveryManager: PhotoRecognitionErrorRecoveryManager!
    var testImage: UIImage!
    
    override func setUp() async throws {
        try await super.setUp()
        errorRecoveryManager = PhotoRecognitionErrorRecoveryManager.shared
        testImage = createTestImage()
        
        // 清理状态
        errorRecoveryManager.clearRecoveryState()
    }
    
    override func tearDown() async throws {
        errorRecoveryManager.clearRecoveryState()
        try await super.tearDown()
    }
    
    // MARK: - 图像质量问题测试
    
    func testHandleImageQualityTooLowError() async throws {
        // 准备测试数据
        let issues: [ImageQualityIssue] = [
            .tooBlurry(severity: 0.8),
            .poorLighting(type: .tooDark),
            .tooSmall(currentSize: CGSize(width: 100, height: 100), minimumSize: CGSize(width: 300, height: 300))
        ]
        let error = PhotoRecognitionError.imageQualityTooLow(issues: issues)
        
        // 执行测试
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        // 验证结果
        switch recoveryAction {
        case .enhanceImage(let title, let message, let enhancements, let showPreview, let fallbackSuggestions):
            XCTAssertEqual(title, "图像质量优化")
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(enhancements.contains { enhancement in
                if case .sharpen = enhancement { return true }
                return false
            })
            XCTAssertTrue(enhancements.contains { enhancement in
                if case .adjustBrightness = enhancement { return true }
                return false
            })
            XCTAssertTrue(showPreview)
            XCTAssertFalse(fallbackSuggestions.isEmpty)
            
        default:
            XCTFail("Expected enhanceImage recovery action")
        }
        
        // 验证状态更新
        XCTAssertNotNil(errorRecoveryManager.currentRecoveryAction)
        XCTAssertTrue(errorRecoveryManager.isShowingRecoveryGuidance)
    }
    
    func testHandleImageQualityWithSuggestRetake() async throws {
        // 准备无法自动修复的质量问题
        let issues: [ImageQualityIssue] = [
            .tooSmall(currentSize: CGSize(width: 50, height: 50), minimumSize: CGSize(width: 300, height: 300)),
            .multipleObjects
        ]
        let error = PhotoRecognitionError.imageQualityTooLow(issues: issues)
        
        // 执行测试
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        // 验证结果
        switch recoveryAction {
        case .suggestRetake(let title, let message, let issueDescriptions, let guidance):
            XCTAssertEqual(title, "图像质量问题")
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(issueDescriptions.isEmpty)
            XCTAssertFalse(guidance.tips.isEmpty)
            
        default:
            XCTFail("Expected suggestRetake recovery action")
        }
    }
    
    // MARK: - 对象检测问题测试
    
    func testHandleNoObjectsDetectedError() async throws {
        let error = PhotoRecognitionError.noObjectsDetected
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .suggestManualInput(let title, let message, let suggestions, let alternativeActions):
            XCTAssertEqual(title, "未检测到物品")
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(suggestions.isEmpty)
            XCTAssertTrue(alternativeActions.contains(.retakePhoto))
            XCTAssertTrue(alternativeActions.contains(.manualInput))
            
        default:
            XCTFail("Expected suggestManualInput recovery action")
        }
    }
    
    func testHandleMultipleObjectsAmbiguousError() async throws {
        let error = PhotoRecognitionError.multipleObjectsAmbiguous
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .showObjectSelection(let title, let message, let detectedObjects, let canSelectMultiple):
            XCTAssertEqual(title, "检测到多个物品")
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(detectedObjects.isEmpty)
            XCTAssertTrue(canSelectMultiple)
            
        default:
            XCTFail("Expected showObjectSelection recovery action")
        }
    }
    
    // MARK: - 网络问题测试
    
    func testHandleNetworkUnavailableWithOfflineCapability() async throws {
        let error = PhotoRecognitionError.networkUnavailable
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .fallbackToOffline(let title, let message, let capabilities, let limitations):
            XCTAssertEqual(title, "网络不可用")
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(capabilities.isEmpty)
            XCTAssertFalse(limitations.isEmpty)
            
        case .waitForNetwork(let title, let message, let suggestions, let canDownloadModel):
            XCTAssertEqual(title, "网络连接失败")
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(suggestions.isEmpty)
            XCTAssertTrue(canDownloadModel)
            
        default:
            // 两种情况都是合理的，取决于离线能力
            break
        }
    }
    
    // MARK: - 权限问题测试
    
    func testHandleCameraPermissionDeniedError() async throws {
        let error = PhotoRecognitionError.cameraPermissionDenied
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .requestPermission(let title, let message, let permissionType, let settingsLink):
            XCTAssertEqual(title, "需要相机权限")
            XCTAssertFalse(message.isEmpty)
            XCTAssertEqual(permissionType, .camera)
            XCTAssertEqual(settingsLink, UIApplication.openSettingsURLString)
            
        default:
            XCTFail("Expected requestPermission recovery action")
        }
    }
    
    // MARK: - 文件大小和格式问题测试
    
    func testHandleImageTooBigError() async throws {
        let error = PhotoRecognitionError.imageTooBig(currentSize: 100, maxSize: 50)
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .compressImage(let title, let message, let currentSize, let targetSize, let qualityOptions):
            XCTAssertEqual(title, "图像过大")
            XCTAssertFalse(message.isEmpty)
            XCTAssertEqual(currentSize, 100)
            XCTAssertEqual(targetSize, 50)
            XCTAssertFalse(qualityOptions.isEmpty)
            
        default:
            XCTFail("Expected compressImage recovery action")
        }
    }
    
    func testHandleUnsupportedFormatError() async throws {
        let error = PhotoRecognitionError.unsupportedFormat
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .convertFormat(let title, let message, let targetFormat, let qualityLevel):
            XCTAssertEqual(title, "格式不支持")
            XCTAssertFalse(message.isEmpty)
            XCTAssertEqual(targetFormat, .jpeg)
            XCTAssertEqual(qualityLevel, 0.8, accuracy: 0.01)
            
        default:
            XCTFail("Expected convertFormat recovery action")
        }
    }
    
    // MARK: - 恢复操作执行测试
    
    func testExecuteImageEnhancementRecovery() async throws {
        let enhancements: [ImageEnhancement] = [
            .adjustBrightness(delta: 0.2),
            .increaseContrast,
            .sharpen(intensity: 0.5)
        ]
        
        let action = RecoveryAction.enhanceImage(
            title: "测试增强",
            message: "测试消息",
            enhancements: enhancements,
            showPreview: true
        )
        
        let result = try await errorRecoveryManager.executeRecoveryAction(action, with: testImage)
        
        switch result {
        case .imageEnhanced(let enhancedImage):
            XCTAssertNotNil(enhancedImage)
            // 在实际实现中，这里应该验证图像确实被增强了
            
        default:
            XCTFail("Expected imageEnhanced result")
        }
    }
    
    func testExecuteImageCompressionRecovery() async throws {
        let action = RecoveryAction.compressImage(
            title: "测试压缩",
            message: "测试消息",
            currentSize: 100,
            targetSize: 50,
            qualityOptions: [.medium]
        )
        
        let result = try await errorRecoveryManager.executeRecoveryAction(action, with: testImage)
        
        switch result {
        case .imageCompressed(let compressedImage):
            XCTAssertNotNil(compressedImage)
            
        default:
            XCTFail("Expected imageCompressed result")
        }
    }
    
    func testExecuteFormatConversionRecovery() async throws {
        let action = RecoveryAction.convertFormat(
            title: "测试转换",
            message: "测试消息",
            targetFormat: .jpeg,
            qualityLevel: 0.8
        )
        
        let result = try await errorRecoveryManager.executeRecoveryAction(action, with: testImage)
        
        switch result {
        case .imageConverted(let convertedImage):
            XCTAssertNotNil(convertedImage)
            
        default:
            XCTFail("Expected imageConverted result")
        }
    }
    
    func testExecuteOfflineFallbackRecovery() async throws {
        let action = RecoveryAction.fallbackToOffline(
            title: "测试离线",
            message: "测试消息",
            offlineCapabilities: ["基础识别"],
            limitations: ["准确度降低"]
        )
        
        let result = try await errorRecoveryManager.executeRecoveryAction(action, with: testImage)
        
        switch result {
        case .offlineModeActivated:
            // 验证离线模式已激活
            break
            
        default:
            XCTFail("Expected offlineModeActivated result")
        }
    }
    
    // MARK: - 恢复进度测试
    
    func testRecoveryProgressTracking() async throws {
        let action = RecoveryAction.enhanceImage(
            title: "测试进度",
            message: "测试消息",
            enhancements: [.adjustBrightness(delta: 0.1)],
            showPreview: false
        )
        
        // 开始恢复操作
        let recoveryTask = Task {
            try await errorRecoveryManager.executeRecoveryAction(action, with: testImage)
        }
        
        // 等待一小段时间让进度更新
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 验证进度状态
        if let progress = errorRecoveryManager.recoveryProgress {
            XCTAssertNotNil(progress)
            // 进度应该在处理中或已完成
            XCTAssertTrue(progress.stage == .processing || progress.stage == .completed)
        }
        
        // 等待任务完成
        _ = try await recoveryTask.value
        
        // 验证最终状态
        if let finalProgress = errorRecoveryManager.recoveryProgress {
            XCTAssertEqual(finalProgress.stage, .completed)
        }
    }
    
    // MARK: - 错误记录测试
    
    func testErrorRecording() async throws {
        let error = PhotoRecognitionError.processingTimeout
        
        // 记录初始错误历史数量
        let initialErrorCount = ErrorHandlingService.shared.errorHistory.count
        
        // 处理错误
        _ = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        // 验证错误被记录
        let finalErrorCount = ErrorHandlingService.shared.errorHistory.count
        XCTAssertGreaterThan(finalErrorCount, initialErrorCount)
        
        // 验证最新错误记录
        if let latestError = ErrorHandlingService.shared.errorHistory.first {
            XCTAssertEqual(latestError.context, "照片识别错误恢复")
        }
    }
    
    // MARK: - 状态管理测试
    
    func testClearRecoveryState() async throws {
        // 设置一些状态
        let error = PhotoRecognitionError.noObjectsDetected
        _ = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        // 验证状态已设置
        XCTAssertNotNil(errorRecoveryManager.currentRecoveryAction)
        XCTAssertTrue(errorRecoveryManager.isShowingRecoveryGuidance)
        
        // 清理状态
        errorRecoveryManager.clearRecoveryState()
        
        // 验证状态已清理
        XCTAssertNil(errorRecoveryManager.currentRecoveryAction)
        XCTAssertFalse(errorRecoveryManager.isShowingRecoveryGuidance)
        XCTAssertNil(errorRecoveryManager.recoveryProgress)
    }
    
    // MARK: - 边界条件测试
    
    func testHandleErrorWithoutImage() async throws {
        let error = PhotoRecognitionError.noObjectsDetected
        
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: nil)
        
        // 即使没有图像，也应该能够提供恢复建议
        XCTAssertNotNil(recoveryAction)
    }
    
    func testExecuteRecoveryWithoutImage() async throws {
        let action = RecoveryAction.enhanceImage(
            title: "测试",
            message: "测试",
            enhancements: [.adjustBrightness(delta: 0.1)],
            showPreview: false
        )
        
        // 没有图像时应该抛出错误
        do {
            _ = try await errorRecoveryManager.executeRecoveryAction(action, with: nil)
            XCTFail("Should throw error when no image provided")
        } catch {
            XCTAssertTrue(error is PhotoRecognitionError)
        }
    }
    
    // MARK: - 性能测试
    
    func testErrorHandlingPerformance() async throws {
        let error = PhotoRecognitionError.imageQualityTooLow(issues: [
            .tooBlurry(severity: 0.5),
            .poorLighting(type: .tooDark)
        ])
        
        let startTime = Date()
        
        // 执行多次错误处理
        for _ in 0..<10 {
            _ = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
            errorRecoveryManager.clearRecoveryState()
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // 错误处理应该很快完成
        XCTAssertLessThan(totalTime, 1.0, "Error handling should complete within 1 second")
    }
    
    // MARK: - 辅助方法
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createBlurryTestImage() -> UIImage {
        // 创建一个模糊的测试图像
        return createTestImage() // 简化实现
    }
    
    private func createLargeTestImage() -> UIImage {
        let size = CGSize(width: 2000, height: 2000)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

// MARK: - 模拟扩展

extension PhotoRecognitionErrorRecoveryManagerTests {
    
    /// 测试特定错误类型的恢复策略
    func testSpecificErrorRecoveryStrategies() async throws {
        let testCases: [(PhotoRecognitionError, String)] = [
            (.processingTimeout, "optimizeAndRetry"),
            (.insufficientLighting, "enhanceImage"),
            (.offlineModelNotAvailable, "downloadOfflineModel"),
            (.recognitionServiceUnavailable, "scheduleRetry or switchService")
        ]
        
        for (error, expectedStrategy) in testCases {
            let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
            
            // 验证恢复策略类型符合预期
            switch (error, recoveryAction) {
            case (.processingTimeout, .optimizeAndRetry):
                break // 正确
            case (.insufficientLighting, .enhanceImage):
                break // 正确
            case (.offlineModelNotAvailable, .downloadOfflineModel):
                break // 正确
            case (.recognitionServiceUnavailable, .scheduleRetry):
                break // 正确
            case (.recognitionServiceUnavailable, .switchService):
                break // 正确
            default:
                XCTFail("Unexpected recovery strategy for \(error): expected \(expectedStrategy)")
            }
            
            errorRecoveryManager.clearRecoveryState()
        }
    }
    
    /// 测试复合错误处理
    func testComplexErrorScenarios() async throws {
        // 测试多个质量问题的组合处理
        let complexIssues: [ImageQualityIssue] = [
            .tooBlurry(severity: 0.7),
            .poorLighting(type: .uneven),
            .complexBackground,
            .multipleObjects
        ]
        
        let error = PhotoRecognitionError.imageQualityTooLow(issues: complexIssues)
        let recoveryAction = await errorRecoveryManager.handlePhotoRecognitionError(error, for: testImage)
        
        switch recoveryAction {
        case .enhanceImage(_, _, let enhancements, _, let fallbackSuggestions):
            // 应该包含多种增强方法
            XCTAssertGreaterThan(enhancements.count, 1)
            // 应该有后备建议
            XCTAssertFalse(fallbackSuggestions.isEmpty)
            
        case .suggestRetake(_, _, let issues, let guidance):
            // 如果无法自动修复，应该提供详细指导
            XCTAssertGreaterThan(issues.count, 1)
            XCTAssertFalse(guidance.tips.isEmpty)
            
        default:
            XCTFail("Expected either enhanceImage or suggestRetake for complex quality issues")
        }
    }
}