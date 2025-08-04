# 照片识别功能 API 文档

## 概述

本文档详细描述了 LuggageHelper 照片识别功能的 API 接口、使用方法和最佳实践。

## 核心服务接口

### PhotoRecognitionService

照片识别的主要服务接口，提供完整的图像识别功能。

```swift
/// 照片识别服务协议
protocol PhotoRecognitionServiceProtocol {
    /// 识别单个物品
    func recognizeItem(from image: UIImage, hint: String?) async throws -> PhotoRecognitionResult
    
    /// 多策略识别
    func recognizeWithMultipleStrategies(_ image: UIImage) async throws -> [RecognitionCandidate]
    
    /// 批量识别
    func recognizeBatch(_ images: [UIImage]) async throws -> [PhotoRecognitionResult]
    
    /// 实时识别
    func recognizeRealTime(from frame: CVPixelBuffer) async throws -> [DetectedObject]
    
    /// 获取缓存结果
    func getCachedResult(for imageHash: String) async -> PhotoRecognitionResult?
    
    /// 检查离线模式可用性
    func isOfflineModeAvailable() -> Bool
}
```

#### 使用示例

```swift
// 基本识别
let image = UIImage(named: "sample_item")!
do {
    let result = try await photoRecognitionService.recognizeItem(from: image, hint: "电子产品")
    print("识别结果: \(result.itemInfo.name)")
    print("置信度: \(result.confidence)")
} catch {
    print("识别失败: \(error.localizedDescription)")
}

// 多策略识别
do {
    let candidates = try await photoRecognitionService.recognizeWithMultipleStrategies(image)
    for candidate in candidates {
        print("候选项: \(candidate.itemInfo.name), 置信度: \(candidate.confidence)")
    }
} catch {
    print("识别失败: \(error)")
}
```

### ImagePreprocessor

图像预处理服务，提供图像质量验证和增强功能。

```swift
/// 图像预处理协议
protocol ImagePreprocessorProtocol {
    /// 增强图像质量
    func enhanceImage(_ image: UIImage) async -> UIImage
    
    /// 标准化图像
    func normalizeImage(_ image: UIImage) async -> UIImage
    
    /// 验证图像质量
    func validateImageQuality(_ image: UIImage) async -> ImageQualityResult
    
    /// 提取最佳区域
    func extractOptimalRegion(_ image: UIImage) async -> UIImage?
    
    /// 自动校正图像
    func correctImageOrientation(_ image: UIImage) async -> UIImage
}
```

#### 使用示例

```swift
let preprocessor = ImagePreprocessor.shared

// 图像质量验证
let qualityResult = await preprocessor.validateImageQuality(image)
if !qualityResult.isAcceptable {
    print("图像质量问题: \(qualityResult.issues)")
    
    // 自动增强
    let enhancedImage = await preprocessor.enhanceImage(image)
    // 使用增强后的图像进行识别
}

// 图像标准化
let normalizedImage = await preprocessor.normalizeImage(image)
```

### ObjectDetectionEngine

对象检测引擎，用于检测图像中的多个物品。

```swift
/// 对象检测引擎协议
protocol ObjectDetectionEngineProtocol {
    /// 检测图像中的对象
    func detectObjects(in image: UIImage) async throws -> [DetectedObject]
    
    /// 提取对象区域
    func extractObjectRegion(_ image: UIImage, boundingBox: CGRect) async -> UIImage?
    
    /// 过滤检测结果
    func filterDetections(_ detections: [DetectedObject], minConfidence: Float) -> [DetectedObject]
}
```

#### 使用示例

```swift
let detector = ObjectDetectionEngine.shared

// 检测多个对象
let detectedObjects = try await detector.detectObjects(in: image)
for object in detectedObjects {
    print("检测到对象: \(object.category?.rawValue ?? "未知"), 置信度: \(object.confidence)")
    
    // 提取对象区域
    if let objectImage = await detector.extractObjectRegion(image, boundingBox: object.boundingBox) {
        // 对单个对象进行识别
        let result = try await photoRecognitionService.recognizeItem(from: objectImage, hint: nil)
    }
}
```

### RealTimeCameraManager

实时相机管理器，提供实时识别功能。

```swift
/// 实时相机识别协议
protocol RealTimeCameraRecognitionProtocol {
    /// 开始实时识别
    func startRealTimeRecognition()
    
    /// 停止实时识别
    func stopRealTimeRecognition()
    
    /// 捕获并识别
    func captureAndRecognize() async throws -> PhotoRecognitionResult
    
    /// 检测到的对象（发布者）
    var detectedObjects: Published<[DetectedObject]> { get }
    
    /// 识别状态（发布者）
    var isRecognizing: Published<Bool> { get }
}
```

#### 使用示例

```swift
@StateObject private var cameraManager = RealTimeCameraManager()

// 在 SwiftUI 视图中使用
var body: some View {
    VStack {
        CameraPreviewView(manager: cameraManager)
            .overlay(
                // 显示检测框
                ForEach(cameraManager.detectedObjects) { object in
                    DetectionBoxView(object: object)
                        .onTapGesture {
                            Task {
                                let result = try await cameraManager.captureAndRecognize()
                                // 处理识别结果
                            }
                        }
                }
            )
        
        Button("开始识别") {
            cameraManager.startRealTimeRecognition()
        }
    }
}
```

## 数据模型

### PhotoRecognitionResult

照片识别结果的完整数据模型。

```swift
/// 照片识别结果
struct PhotoRecognitionResult: Codable, Identifiable {
    let id: UUID
    let itemInfo: ItemInfo
    let confidence: Double
    let recognitionMethod: RecognitionMethod
    let processingTime: TimeInterval
    let imageMetadata: ImageMetadata
    let alternatives: [RecognitionCandidate]
    let qualityScore: Double
    let timestamp: Date
    
    // 用户反馈
    var userFeedback: UserFeedback?
    var isVerified: Bool
    var correctedInfo: ItemInfo?
}

/// 识别方法
enum RecognitionMethod: String, Codable {
    case cloudAPI = "cloud_api"
    case offlineML = "offline_ml"
    case hybrid = "hybrid"
    case cached = "cached"
    case userCorrected = "user_corrected"
}
```

### ImageQualityResult

图像质量评估结果。

```swift
/// 图像质量结果
struct ImageQualityResult {
    let score: Double // 0.0 - 1.0
    let issues: [ImageQualityIssue]
    let suggestions: [String]
    let isAcceptable: Bool
}

/// 图像质量问题
enum ImageQualityIssue {
    case tooBlurry(severity: Double)
    case poorLighting(type: LightingIssue)
    case tooSmall(currentSize: CGSize, minimumSize: CGSize)
    case complexBackground
    case multipleObjects
    
    var description: String {
        switch self {
        case .tooBlurry(let severity):
            return "图像模糊，严重程度: \(severity)"
        case .poorLighting(let type):
            return "光线问题: \(type)"
        case .tooSmall(let current, let minimum):
            return "图像尺寸过小: \(current) < \(minimum)"
        case .complexBackground:
            return "背景过于复杂"
        case .multipleObjects:
            return "检测到多个物品"
        }
    }
}
```

### DetectedObject

检测到的对象信息。

```swift
/// 检测到的对象
struct DetectedObject: Identifiable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float
    let category: ObjectCategory?
    let isTracking: Bool
    let trackingHistory: [CGRect]
    
    /// 对象面积
    var area: Double {
        return Double(boundingBox.width * boundingBox.height)
    }
    
    /// 是否为主要对象
    var isPrimaryObject: Bool {
        return confidence > 0.8 && area > 0.1
    }
}
```

## 缓存系统 API

### PhotoRecognitionCacheManager

照片识别专用缓存管理器。

```swift
/// 照片识别缓存管理器
@MainActor
class PhotoRecognitionCacheManager: ObservableObject {
    /// 获取缓存结果
    func getCachedResult(for image: UIImage) async -> PhotoRecognitionResult?
    
    /// 缓存相似结果
    func cacheSimilarResult(for image: UIImage, result: PhotoRecognitionResult)
    
    /// 查找相似缓存结果
    func findSimilarCachedResults(for image: UIImage, threshold: Double) async -> [PhotoRecognitionResult]
    
    /// 清理过期缓存
    func cleanupExpiredCache()
    
    /// 获取缓存统计
    func getCacheStatistics() -> CacheStatistics
}
```

#### 使用示例

```swift
let cacheManager = PhotoRecognitionCacheManager.shared

// 检查缓存
if let cachedResult = await cacheManager.getCachedResult(for: image) {
    print("缓存命中: \(cachedResult.itemInfo.name)")
    return cachedResult
}

// 查找相似结果
let similarResults = await cacheManager.findSimilarCachedResults(for: image, threshold: 0.8)
if !similarResults.isEmpty {
    print("找到 \(similarResults.count) 个相似结果")
}

// 缓存新结果
let newResult = try await recognitionService.recognizeItem(from: image, hint: nil)
await cacheManager.cacheSimilarResult(for: image, result: newResult)
```

## 错误处理

### PhotoRecognitionError

照片识别专用错误类型。

```swift
/// 照片识别错误
enum PhotoRecognitionError: LocalizedError {
    case imageQualityTooLow(issues: [ImageQualityIssue])
    case noObjectsDetected
    case multipleObjectsAmbiguous
    case networkUnavailable
    case offlineModelNotAvailable
    case processingTimeout
    case insufficientLighting
    case imageTooBig(currentSize: Int, maxSize: Int)
    case unsupportedFormat
    case cameraPermissionDenied
    case recognitionServiceUnavailable
    
    var errorDescription: String? {
        // 详细的错误描述
    }
    
    var recoverySuggestion: String? {
        // 恢复建议
    }
}
```

### 错误恢复管理器

```swift
/// 错误恢复管理器
class PhotoRecognitionErrorRecoveryManager {
    /// 处理错误并提供恢复方案
    func handleError(_ error: PhotoRecognitionError, for image: UIImage) async -> RecoveryAction
    
    /// 自动恢复尝试
    func attemptAutoRecovery(_ error: PhotoRecognitionError, image: UIImage) async -> PhotoRecognitionResult?
}

/// 恢复操作
enum RecoveryAction {
    case enhanceSharpness
    case adjustBrightness
    case suggestRecapture
    case enableObjectDetection
    case showObjectSelection
    case fallbackToOffline
    case suggestManualInput
    case showErrorWithRetry
    case combineActions([RecoveryAction])
}
```

## 性能优化

### 最佳实践

1. **图像预处理**
   ```swift
   // 在识别前进行质量检查
   let qualityResult = await imagePreprocessor.validateImageQuality(image)
   if !qualityResult.isAcceptable {
       let enhancedImage = await imagePreprocessor.enhanceImage(image)
       // 使用增强后的图像
   }
   ```

2. **缓存利用**
   ```swift
   // 优先检查缓存
   if let cachedResult = await cacheManager.getCachedResult(for: image) {
       return cachedResult
   }
   
   // 检查相似图像缓存
   let similarResults = await cacheManager.findSimilarCachedResults(for: image, threshold: 0.8)
   if let bestMatch = similarResults.first {
       return bestMatch
   }
   ```

3. **并发处理**
   ```swift
   // 并行处理多个图像
   let results = await withTaskGroup(of: PhotoRecognitionResult?.self) { group in
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
   ```

4. **内存管理**
   ```swift
   // 及时释放大图像
   autoreleasepool {
       let processedImage = processLargeImage(image)
       // 处理完成后自动释放
   }
   ```

## 配置和设置

### 性能配置

```swift
/// 照片识别配置
struct PhotoRecognitionConfig {
    // 图像处理配置
    let maxImageSize: CGSize = CGSize(width: 1024, height: 1024)
    let imageCompressionQuality: CGFloat = 0.8
    let minConfidenceThreshold: Double = 0.6
    
    // 缓存配置
    let maxMemoryCacheSize: Int = 50
    let maxDiskCacheSize: Int = 100 * 1024 * 1024 // 100MB
    let cacheExpiryTime: TimeInterval = 7 * 24 * 60 * 60 // 7天
    
    // 性能配置
    let maxConcurrentRequests: Int = 3
    let requestTimeout: TimeInterval = 30.0
    let enableParallelProcessing: Bool = true
}
```

### 调试和监控

```swift
/// 性能监控
class PhotoRecognitionPerformanceMonitor {
    /// 记录识别时间
    func recordRecognitionTime(_ duration: TimeInterval, method: RecognitionMethod)
    
    /// 记录缓存命中率
    func recordCacheHit(_ hit: Bool)
    
    /// 生成性能报告
    func generatePerformanceReport() -> PerformanceReport
}
```

## 测试支持

### Mock 服务

```swift
/// Mock 照片识别服务
class MockPhotoRecognitionService: PhotoRecognitionServiceProtocol {
    var mockResults: [PhotoRecognitionResult] = []
    var shouldFail: Bool = false
    var simulatedDelay: TimeInterval = 0.5
    
    func recognizeItem(from image: UIImage, hint: String?) async throws -> PhotoRecognitionResult {
        if shouldFail {
            throw PhotoRecognitionError.recognitionServiceUnavailable
        }
        
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        return mockResults.first ?? PhotoRecognitionResult.mock
    }
}
```

### 测试工具

```swift
/// 测试图像生成器
class TestImageGenerator {
    /// 生成测试图像
    static func generateTestImage(size: CGSize, color: UIColor) -> UIImage
    
    /// 生成模糊图像
    static func generateBlurryImage(_ image: UIImage, radius: CGFloat) -> UIImage
    
    /// 生成多物品图像
    static func generateMultiObjectImage() -> UIImage
}
```

---

这个 API 文档提供了照片识别功能的完整接口说明和使用指南，帮助开发者更好地理解和使用这些功能。