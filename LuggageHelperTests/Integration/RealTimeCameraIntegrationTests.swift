import XCTest
import AVFoundation
import Vision
@testable import LuggageHelper

/// 实时相机识别集成测试
/// 测试实时相机功能的完整流程和集成
final class RealTimeCameraIntegrationTests: XCTestCase {
    
    var cameraManager: RealTimeCameraManager!
    var objectDetector: ObjectDetectionEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        cameraManager = RealTimeCameraManager()
        objectDetector = ObjectDetectionEngine.shared
    }
    
    override func tearDownWithError() throws {
        cameraManager?.stopSession()
        cameraManager = nil
        objectDetector = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 相机权限测试
    
    /// 测试相机权限请求
    func testCameraPermissionRequest() async throws {
        // 在模拟器中跳过此测试
        guard !isRunningOnSimulator() else {
            throw XCTSkip("相机功能在模拟器中不可用")
        }
        
        await cameraManager.requestPermission()
        
        // 验证权限状态
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        XCTAssertTrue(authStatus == .authorized || authStatus == .denied || authStatus == .restricted)
    }
    
    // MARK: - 相机会话测试
    
    /// 测试相机会话启动和停止
    func testCameraSessionLifecycle() async throws {
        guard !isRunningOnSimulator() else {
            throw XCTSkip("相机功能在模拟器中不可用")
        }
        
        // 请求权限
        await cameraManager.requestPermission()
        
        guard cameraManager.hasPermission else {
            throw XCTSkip("需要相机权限才能进行测试")
        }
        
        // 启动会话
        await cameraManager.startSession()
        
        // 等待会话启动
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 验证检测状态
        XCTAssertTrue(cameraManager.isDetecting)
        
        // 停止会话
        cameraManager.stopSession()
        
        // 验证停止状态
        XCTAssertFalse(cameraManager.isDetecting)
    }
    
    // MARK: - 实时检测测试
    
    /// 测试实时物品检测功能
    func testRealTimeObjectDetection() async throws {
        guard !isRunningOnSimulator() else {
            throw XCTSkip("相机功能在模拟器中不可用")
        }
        
        // 使用测试图像代替实时相机流
        let testImage = createTestImageWithObjects()
        
        // 执行检测
        let detections = await objectDetector.detectObjects(in: testImage)
        
        // 验证检测结果
        XCTAssertGreaterThan(detections.count, 0, "应该检测到至少一个物品")
        
        // 验证检测对象的属性
        for detection in detections {
            XCTAssertGreaterThan(detection.confidence, 0.0)
            XCTAssertLessThanOrEqual(detection.confidence, 1.0)
            XCTAssertTrue(detection.boundingBox.width > 0)
            XCTAssertTrue(detection.boundingBox.height > 0)
        }
    }
    
    /// 测试检测配置更新
    func testDetectionConfigurationUpdates() async throws {
        // 测试检测间隔更新
        let originalInterval = cameraManager.detectionInterval
        cameraManager.detectionInterval = 2.0
        XCTAssertEqual(cameraManager.detectionInterval, 2.0)
        
        // 测试最小置信度更新
        cameraManager.minimumConfidence = 0.8
        XCTAssertEqual(cameraManager.minimumConfidence, 0.8)
        
        // 测试节能模式
        cameraManager.powerSavingMode = true
        XCTAssertTrue(cameraManager.powerSavingMode)
        
        // 恢复原始设置
        cameraManager.detectionInterval = originalInterval
        cameraManager.minimumConfidence = 0.5
        cameraManager.powerSavingMode = false
    }
    
    // MARK: - 图像捕获测试
    
    /// 测试照片捕获功能
    func testPhotoCaptureIntegration() async throws {
        guard !isRunningOnSimulator() else {
            throw XCTSkip("相机功能在模拟器中不可用")
        }
        
        await cameraManager.requestPermission()
        
        guard cameraManager.hasPermission else {
            throw XCTSkip("需要相机权限才能进行测试")
        }
        
        await cameraManager.startSession()
        
        // 等待相机准备就绪
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        // 捕获照片
        let capturedImage = await cameraManager.capturePhoto()
        
        // 验证捕获结果
        XCTAssertNotNil(capturedImage, "应该成功捕获照片")
        
        if let image = capturedImage {
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
        
        cameraManager.stopSession()
    }
    
    // MARK: - 物品裁剪测试
    
    /// 测试检测物品的裁剪功能
    func testDetectedObjectCropping() async throws {
        let testImage = createTestImageWithObjects()
        
        // 创建模拟检测结果
        let mockDetection = RealTimeDetection(
            id: UUID(),
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            confidence: 0.8,
            type: .rectangular,
            timestamp: Date(),
            isTracking: false
        )
        
        // 模拟当前帧
        await MainActor.run {
            // 这里需要设置cameraManager的currentFrame，但它是私有的
            // 在实际实现中，我们可能需要添加一个测试专用的方法
        }
        
        // 测试裁剪功能
        let croppedImage = await cameraManager.cropDetectedObject(mockDetection)
        
        // 在没有当前帧的情况下，应该返回nil
        XCTAssertNil(croppedImage, "没有当前帧时应该返回nil")
    }
    
    // MARK: - 性能测试
    
    /// 测试实时检测性能
    func testRealTimeDetectionPerformance() async throws {
        let testImage = createTestImageWithObjects()
        
        // 测量检测性能
        let startTime = Date()
        let iterations = 10
        
        for _ in 0..<iterations {
            _ = await objectDetector.detectObjects(in: testImage)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(iterations)
        
        // 平均检测时间应该小于1秒
        XCTAssertLessThan(averageTime, 1.0, "平均检测时间应该小于1秒")
        
        print("平均检测时间: \(String(format: "%.3f", averageTime))秒")
    }
    
    /// 测试内存使用情况
    func testMemoryUsageDuringDetection() async throws {
        let testImage = createTestImageWithObjects()
        
        // 记录初始内存使用
        let initialMemory = getMemoryUsage()
        
        // 执行多次检测
        for _ in 0..<20 {
            _ = await objectDetector.detectObjects(in: testImage)
        }
        
        // 记录最终内存使用
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // 内存增长应该控制在合理范围内（50MB）
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "内存增长应该控制在50MB以内")
        
        print("内存增长: \(memoryIncrease / 1024 / 1024)MB")
    }
    
    // MARK: - 错误处理测试
    
    /// 测试无权限情况下的错误处理
    func testErrorHandlingWithoutPermission() async throws {
        // 创建一个新的相机管理器实例，模拟无权限状态
        let restrictedCameraManager = RealTimeCameraManager()
        
        // 在没有权限的情况下尝试启动会话
        await restrictedCameraManager.startSession()
        
        // 验证检测状态
        XCTAssertFalse(restrictedCameraManager.isDetecting, "没有权限时不应该开始检测")
    }
    
    /// 测试检测过程中的错误恢复
    func testDetectionErrorRecovery() async throws {
        // 使用无效图像测试错误处理
        let invalidImage = UIImage()
        
        let detections = await objectDetector.detectObjects(in: invalidImage)
        
        // 应该返回空数组而不是崩溃
        XCTAssertEqual(detections.count, 0, "无效图像应该返回空检测结果")
    }
    
    // MARK: - 集成流程测试
    
    /// 测试完整的实时识别流程
    func testCompleteRealTimeRecognitionFlow() async throws {
        guard !isRunningOnSimulator() else {
            throw XCTSkip("相机功能在模拟器中不可用")
        }
        
        // 1. 权限请求
        await cameraManager.requestPermission()
        
        guard cameraManager.hasPermission else {
            throw XCTSkip("需要相机权限才能进行完整流程测试")
        }
        
        // 2. 启动相机会话
        await cameraManager.startSession()
        
        // 3. 等待检测开始
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        // 4. 验证检测状态
        XCTAssertTrue(cameraManager.isDetecting)
        
        // 5. 等待检测结果
        var detectionCount = 0
        let maxWaitTime = 10.0 // 最多等待10秒
        let startTime = Date()
        
        while detectionCount == 0 && Date().timeIntervalSince(startTime) < maxWaitTime {
            detectionCount = cameraManager.detectedObjects.count
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        // 6. 停止会话
        cameraManager.stopSession()
        
        // 7. 验证结果（在真实环境中可能检测到物品）
        print("检测到的物品数量: \(detectionCount)")
    }
    
    // MARK: - 辅助方法
    
    /// 检查是否在模拟器中运行
    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// 创建包含物品的测试图像
    private func createTestImageWithObjects() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 绘制背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制几个矩形物品
            UIColor.blue.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 80))
            
            UIColor.red.setFill()
            context.fill(CGRect(x: 200, y: 100, width: 120, height: 60))
            
            UIColor.green.setFill()
            context.fill(CGRect(x: 100, y: 180, width: 80, height: 90))
        }
    }
    
    /// 获取当前内存使用量
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

// MARK: - Mock Classes

/// 模拟相机管理器（用于无相机环境的测试）
class MockRealTimeCameraManager: RealTimeCameraManager {
    
    var mockDetections: [RealTimeDetection] = []
    var mockHasPermission = true
    var mockCapturedImage: UIImage?
    
    override func requestPermission() async {
        await MainActor.run {
            self.hasPermission = mockHasPermission
        }
    }
    
    override func startSession() async {
        await MainActor.run {
            self.isDetecting = mockHasPermission
        }
        
        // 模拟检测结果
        if mockHasPermission {
            await MainActor.run {
                self.detectedObjects = mockDetections
            }
        }
    }
    
    override func capturePhoto() async -> UIImage? {
        return mockCapturedImage
    }
    
    override func cropDetectedObject(_ detection: RealTimeDetection) async -> UIImage? {
        // 返回一个简单的测试图像
        return createSimpleTestImage()
    }
    
    private func createSimpleTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 测试用例扩展

extension RealTimeCameraIntegrationTests {
    
    /// 测试使用模拟管理器的功能
    func testWithMockCameraManager() async throws {
        let mockManager = MockRealTimeCameraManager()
        
        // 设置模拟数据
        mockManager.mockDetections = [
            RealTimeDetection(
                id: UUID(),
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3),
                confidence: 0.8,
                type: .rectangular,
                timestamp: Date(),
                isTracking: false
            ),
            RealTimeDetection(
                id: UUID(),
                boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.4, height: 0.2),
                confidence: 0.9,
                type: .rectangular,
                timestamp: Date(),
                isTracking: false
            )
        ]
        
        mockManager.mockCapturedImage = createTestImageWithObjects()
        
        // 测试权限请求
        await mockManager.requestPermission()
        XCTAssertTrue(mockManager.hasPermission)
        
        // 测试会话启动
        await mockManager.startSession()
        XCTAssertTrue(mockManager.isDetecting)
        XCTAssertEqual(mockManager.detectedObjects.count, 2)
        
        // 测试照片捕获
        let capturedImage = await mockManager.capturePhoto()
        XCTAssertNotNil(capturedImage)
        
        // 测试物品裁剪
        if let firstDetection = mockManager.detectedObjects.first {
            let croppedImage = await mockManager.cropDetectedObject(firstDetection)
            XCTAssertNotNil(croppedImage)
        }
    }
}