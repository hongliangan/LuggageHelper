# 代码优化指南

## 概述

本文档提供 LuggageHelper 照片识别功能的代码优化建议和最佳实践，帮助开发者维护高质量、高性能的代码。

## 🚀 性能优化

### 1. 内存管理优化

#### 图像处理内存优化
```swift
// ✅ 推荐：使用 autoreleasepool 处理大图像
func processLargeImage(_ image: UIImage) async -> UIImage {
    return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let processedImage = self.performImageProcessing(image)
                continuation.resume(returning: processedImage)
            }
        }
    }
}

// ❌ 避免：在主线程处理大图像
func processImageOnMainThread(_ image: UIImage) -> UIImage {
    // 这会阻塞UI并可能导致内存峰值
    return performImageProcessing(image)
}
```

#### 缓存内存管理
```swift
// ✅ 推荐：实现智能缓存清理
class PhotoRecognitionCacheManager {
    private let maxMemoryUsage: Int = 100 * 1024 * 1024 // 100MB
    
    func cleanupIfNeeded() {
        let currentUsage = calculateMemoryUsage()
        if currentUsage > maxMemoryUsage {
            // 清理最少使用的缓存项
            cleanupLeastRecentlyUsed()
        }
    }
    
    private func cleanupLeastRecentlyUsed() {
        let sortedItems = cacheItems.sorted { $0.lastAccessed < $1.lastAccessed }
        let itemsToRemove = sortedItems.prefix(cacheItems.count / 4)
        itemsToRemove.forEach { removeFromCache($0.key) }
    }
}
```

### 2. 并发处理优化

#### 使用 TaskGroup 进行并行处理
```swift
// ✅ 推荐：并行处理多个图像
func processBatchImages(_ images: [UIImage]) async -> [PhotoRecognitionResult] {
    await withTaskGroup(of: PhotoRecognitionResult?.self) { group in
        for image in images {
            group.addTask {
                try? await self.recognizeItem(from: image, hint: nil)
            }
        }
        
        var results: [PhotoRecognitionResult] = []
        for await result in group {
            if let result = result {
                results.append(result)
            }
        }
        return results
    }
}

// ❌ 避免：串行处理多个图像
func processBatchImagesSerially(_ images: [UIImage]) async -> [PhotoRecognitionResult] {
    var results: [PhotoRecognitionResult] = []
    for image in images {
        if let result = try? await recognizeItem(from: image, hint: nil) {
            results.append(result)
        }
    }
    return results
}
```

#### Actor 模式保证线程安全
```swift
// ✅ 推荐：使用 Actor 保证线程安全
actor ImageProcessingQueue {
    private var pendingTasks: [ImageProcessingTask] = []
    private let maxConcurrentTasks = 3
    
    func enqueue(_ task: ImageProcessingTask) async {
        pendingTasks.append(task)
        await processNextTaskIfPossible()
    }
    
    private func processNextTaskIfPossible() async {
        guard pendingTasks.count > 0 else { return }
        // 处理任务逻辑
    }
}
```

### 3. 网络请求优化

#### 请求去重和缓存
```swift
// ✅ 推荐：实现请求去重
class AIRequestQueue {
    private var activeRequests: [String: Task<Any, Error>] = [:]
    
    func enqueue<T>(_ request: AIRequest) async throws -> T {
        let requestKey = request.cacheKey
        
        // 检查是否有相同的请求正在进行
        if let existingTask = activeRequests[requestKey] as? Task<T, Error> {
            return try await existingTask.value
        }
        
        // 创建新任务
        let task = Task<T, Error> {
            defer { activeRequests.removeValue(forKey: requestKey) }
            return try await performRequest(request)
        }
        
        activeRequests[requestKey] = task
        return try await task.value
    }
}
```

#### 智能重试机制
```swift
// ✅ 推荐：指数退避重试
func performRequestWithRetry<T>(_ request: AIRequest, maxRetries: Int = 3) async throws -> T {
    var lastError: Error?
    
    for attempt in 0..<maxRetries {
        do {
            return try await performRequest(request)
        } catch {
            lastError = error
            
            // 检查是否应该重试
            guard shouldRetry(error: error, attempt: attempt) else {
                throw error
            }
            
            // 指数退避延迟
            let delay = min(pow(2.0, Double(attempt)), 10.0)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    
    throw lastError ?? AIError.maxRetriesExceeded
}

private func shouldRetry(error: Error, attempt: Int) -> Bool {
    // 只对网络错误和服务器错误重试
    if let aiError = error as? AIError {
        switch aiError {
        case .networkError, .serverError, .timeout:
            return attempt < 2
        case .invalidResponse, .authenticationFailed:
            return false
        }
    }
    return false
}
```

## 🏗️ 架构优化

### 1. 依赖注入

#### 协议导向设计
```swift
// ✅ 推荐：使用协议定义接口
protocol PhotoRecognitionServiceProtocol {
    func recognizeItem(from image: UIImage, hint: String?) async throws -> PhotoRecognitionResult
}

protocol ImagePreprocessorProtocol {
    func enhanceImage(_ image: UIImage) async -> UIImage
    func validateImageQuality(_ image: UIImage) async -> ImageQualityResult
}

// 具体实现
class PhotoRecognitionService: PhotoRecognitionServiceProtocol {
    private let preprocessor: ImagePreprocessorProtocol
    private let cacheManager: CacheManagerProtocol
    
    init(preprocessor: ImagePreprocessorProtocol, cacheManager: CacheManagerProtocol) {
        self.preprocessor = preprocessor
        self.cacheManager = cacheManager
    }
}
```

#### 依赖注入容器
```swift
// ✅ 推荐：简单的依赖注入容器
class DIContainer {
    private var services: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let factory = services[key] as? () -> T else {
            fatalError("Service \(key) not registered")
        }
        return factory()
    }
}

// 使用示例
let container = DIContainer()
container.register(ImagePreprocessorProtocol.self) { ImagePreprocessor.shared }
container.register(PhotoRecognitionServiceProtocol.self) {
    PhotoRecognitionService(
        preprocessor: container.resolve(ImagePreprocessorProtocol.self),
        cacheManager: container.resolve(CacheManagerProtocol.self)
    )
}
```

### 2. 错误处理优化

#### 结构化错误处理
```swift
// ✅ 推荐：详细的错误类型定义
enum PhotoRecognitionError: LocalizedError, Equatable {
    case imageQualityTooLow(issues: [ImageQualityIssue])
    case noObjectsDetected
    case multipleObjectsAmbiguous(count: Int)
    case networkUnavailable
    case processingTimeout(duration: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .imageQualityTooLow(let issues):
            return "图像质量不符合要求：\(issues.map(\.description).joined(separator: ", "))"
        case .noObjectsDetected:
            return "未能在图像中检测到物品"
        case .multipleObjectsAmbiguous(let count):
            return "检测到\(count)个物品，请选择要识别的物品"
        case .networkUnavailable:
            return "网络连接不可用"
        case .processingTimeout(let duration):
            return "处理超时（\(String(format: "%.1f", duration))秒）"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .imageQualityTooLow:
            return "请在光线充足的环境中重新拍摄"
        case .noObjectsDetected:
            return "尝试调整拍摄角度或使用手动输入"
        case .multipleObjectsAmbiguous:
            return "点击选择要识别的特定物品"
        case .networkUnavailable:
            return "检查网络连接或使用离线模式"
        case .processingTimeout:
            return "尝试压缩图片或检查网络连接"
        }
    }
}
```

#### Result 类型使用
```swift
// ✅ 推荐：使用 Result 类型处理可能失败的操作
func recognizeItemSafely(from image: UIImage) async -> Result<PhotoRecognitionResult, PhotoRecognitionError> {
    do {
        let result = try await recognizeItem(from: image, hint: nil)
        return .success(result)
    } catch let error as PhotoRecognitionError {
        return .failure(error)
    } catch {
        return .failure(.processingTimeout(duration: 30.0))
    }
}

// 使用示例
let result = await recognizeItemSafely(from: image)
switch result {
case .success(let recognitionResult):
    // 处理成功结果
    handleSuccessfulRecognition(recognitionResult)
case .failure(let error):
    // 处理错误
    handleRecognitionError(error)
}
```

## 🧪 测试优化

### 1. 单元测试最佳实践

#### Mock 对象设计
```swift
// ✅ 推荐：灵活的 Mock 实现
class MockPhotoRecognitionService: PhotoRecognitionServiceProtocol {
    var mockResults: [PhotoRecognitionResult] = []
    var shouldFail: Bool = false
    var failureError: PhotoRecognitionError = .networkUnavailable
    var simulatedDelay: TimeInterval = 0.1
    
    func recognizeItem(from image: UIImage, hint: String?) async throws -> PhotoRecognitionResult {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        if shouldFail {
            throw failureError
        }
        
        return mockResults.first ?? PhotoRecognitionResult.mock
    }
    
    // 便利方法
    func setMockResult(_ result: PhotoRecognitionResult) {
        mockResults = [result]
        shouldFail = false
    }
    
    func setFailure(_ error: PhotoRecognitionError) {
        shouldFail = true
        failureError = error
    }
}
```

#### 测试数据生成器
```swift
// ✅ 推荐：测试数据生成器
struct TestDataGenerator {
    static func generateTestImage(size: CGSize = CGSize(width: 100, height: 100), 
                                 color: UIColor = .blue) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    static func generateMockRecognitionResult(confidence: Double = 0.9) -> PhotoRecognitionResult {
        return PhotoRecognitionResult(
            id: UUID(),
            itemInfo: ItemInfo.mock,
            confidence: confidence,
            recognitionMethod: .cloudAPI,
            processingTime: 2.5,
            imageMetadata: ImageMetadata.mock,
            alternatives: [],
            qualityScore: 0.8,
            timestamp: Date()
        )
    }
}
```

### 2. 性能测试

#### 基准测试实现
```swift
// ✅ 推荐：性能基准测试
class PhotoRecognitionPerformanceTests: XCTestCase {
    func testRecognitionPerformance() async throws {
        let testImages = TestDataGenerator.generateTestImages(count: 10)
        let service = PhotoRecognitionService.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for image in testImages {
            _ = try await service.recognizeItem(from: image, hint: nil)
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = totalTime / Double(testImages.count)
        
        // 断言平均识别时间小于5秒
        XCTAssertLessThan(averageTime, 5.0, "平均识别时间应小于5秒")
        
        // 记录性能指标
        print("平均识别时间: \(String(format: "%.2f", averageTime))秒")
    }
    
    func testMemoryUsage() async throws {
        let initialMemory = getMemoryUsage()
        
        // 处理大量图像
        for _ in 0..<50 {
            let image = TestDataGenerator.generateLargeTestImage()
            _ = try await PhotoRecognitionService.shared.recognizeItem(from: image, hint: nil)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // 内存增长应控制在100MB以内
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "内存增长应控制在100MB以内")
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
```

## 📊 监控和调试

### 1. 性能监控

#### 自定义性能监控器
```swift
// ✅ 推荐：详细的性能监控
class PerformanceMonitor {
    private var metrics: [String: PerformanceMetric] = [:]
    
    func startMeasuring(_ operation: String) -> PerformanceMeasurement {
        return PerformanceMeasurement(operation: operation, startTime: CFAbsoluteTimeGetCurrent())
    }
    
    func recordMeasurement(_ measurement: PerformanceMeasurement) {
        let duration = CFAbsoluteTimeGetCurrent() - measurement.startTime
        
        if var metric = metrics[measurement.operation] {
            metric.addMeasurement(duration)
            metrics[measurement.operation] = metric
        } else {
            metrics[measurement.operation] = PerformanceMetric(operation: measurement.operation, duration: duration)
        }
    }
    
    func generateReport() -> PerformanceReport {
        return PerformanceReport(metrics: Array(metrics.values))
    }
}

struct PerformanceMeasurement {
    let operation: String
    let startTime: CFAbsoluteTime
}

struct PerformanceMetric {
    let operation: String
    private(set) var totalDuration: TimeInterval
    private(set) var count: Int
    private(set) var minDuration: TimeInterval
    private(set) var maxDuration: TimeInterval
    
    init(operation: String, duration: TimeInterval) {
        self.operation = operation
        self.totalDuration = duration
        self.count = 1
        self.minDuration = duration
        self.maxDuration = duration
    }
    
    var averageDuration: TimeInterval {
        return totalDuration / Double(count)
    }
    
    mutating func addMeasurement(_ duration: TimeInterval) {
        totalDuration += duration
        count += 1
        minDuration = min(minDuration, duration)
        maxDuration = max(maxDuration, duration)
    }
}
```

### 2. 日志系统

#### 结构化日志记录
```swift
// ✅ 推荐：结构化日志系统
import os.log

extension Logger {
    static let photoRecognition = Logger(subsystem: "com.luggagehelper.photorecognition", category: "recognition")
    static let imageProcessing = Logger(subsystem: "com.luggagehelper.imageprocessing", category: "processing")
    static let caching = Logger(subsystem: "com.luggagehelper.caching", category: "cache")
}

// 使用示例
func recognizeItem(from image: UIImage, hint: String?) async throws -> PhotoRecognitionResult {
    Logger.photoRecognition.info("开始识别物品，提示: \(hint ?? "无")")
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    do {
        let result = try await performRecognition(image, hint: hint)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        Logger.photoRecognition.info("识别成功，耗时: \(String(format: "%.2f", duration))秒，置信度: \(result.confidence)")
        
        return result
    } catch {
        Logger.photoRecognition.error("识别失败: \(error.localizedDescription)")
        throw error
    }
}
```

## 🔧 代码质量工具

### 1. SwiftLint 配置

创建 `.swiftlint.yml` 配置文件：
```yaml
# SwiftLint 配置
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - explicit_init
  - first_where
  - sorted_first_last
  - unneeded_parentheses_in_closure_argument

line_length:
  warning: 120
  error: 150

function_body_length:
  warning: 50
  error: 100

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 1000

identifier_name:
  min_length:
    warning: 2
    error: 1
  max_length:
    warning: 40
    error: 50
```

### 2. 代码审查清单

#### 性能审查清单
- [ ] 是否避免了主线程阻塞操作？
- [ ] 是否正确使用了 `async/await`？
- [ ] 是否实现了适当的缓存策略？
- [ ] 是否有内存泄漏风险？
- [ ] 是否优化了网络请求？

#### 代码质量清单
- [ ] 是否遵循了 SOLID 原则？
- [ ] 是否有适当的错误处理？
- [ ] 是否有充分的单元测试？
- [ ] 是否有清晰的文档注释？
- [ ] 是否遵循了项目编码规范？

#### 安全审查清单
- [ ] 是否正确处理了用户数据？
- [ ] 是否有适当的输入验证？
- [ ] 是否安全存储了敏感信息？
- [ ] 是否正确处理了权限请求？
- [ ] 是否有数据泄漏风险？

---

遵循这些优化建议和最佳实践，可以确保 LuggageHelper 照片识别功能的代码质量、性能和可维护性。定期进行代码审查和性能测试，持续改进代码质量。