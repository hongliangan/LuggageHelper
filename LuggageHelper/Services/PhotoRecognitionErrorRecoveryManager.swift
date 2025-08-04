import Foundation
import UIKit
import SwiftUI

// MARK: - 照片识别错误恢复管理器
@MainActor
class PhotoRecognitionErrorRecoveryManager: ObservableObject {
    static let shared = PhotoRecognitionErrorRecoveryManager()
    
    @Published var currentRecoveryAction: RecoveryAction?
    @Published var isShowingRecoveryGuidance = false
    @Published var recoveryProgress: RecoveryProgress?
    
    private let errorHandlingService = ErrorHandlingService.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {}
    
    // MARK: - 主要错误处理方法
    
    /// 处理照片识别错误并提供恢复策略
    func handlePhotoRecognitionError(_ error: PhotoRecognitionError, for image: UIImage? = nil) async -> RecoveryAction {
        let recoveryAction = await determineRecoveryAction(for: error, image: image)
        
        // 记录错误和恢复策略
        await recordErrorAndRecovery(error: error, action: recoveryAction)
        
        // 更新UI状态
        currentRecoveryAction = recoveryAction
        isShowingRecoveryGuidance = true
        
        return recoveryAction
    }
    
    /// 执行恢复操作
    func executeRecoveryAction(_ action: RecoveryAction, with image: UIImage? = nil) async throws -> RecoveryResult {
        recoveryProgress = RecoveryProgress(action: action, stage: .preparing)
        
        do {
            let result = try await performRecoveryAction(action, image: image)
            recoveryProgress = RecoveryProgress(action: action, stage: .completed)
            return result
        } catch {
            recoveryProgress = RecoveryProgress(action: action, stage: .failed, error: error)
            throw error
        }
    }
    
    // MARK: - 错误分析和恢复策略确定
    
    private func determineRecoveryAction(for error: PhotoRecognitionError, image: UIImage?) async -> RecoveryAction {
        switch error {
        case .imageQualityTooLow(let issues):
            return await handleImageQualityIssues(issues, image: image)
            
        case .noObjectsDetected:
            return .suggestManualInput(
                title: "未检测到物品",
                message: "无法在图像中识别到物品，请尝试以下方法：",
                suggestions: [
                    "将物品放在简单背景前重新拍摄",
                    "确保物品完整显示在画面中",
                    "改善拍摄光线条件",
                    "手动输入物品信息"
                ],
                alternativeActions: [.retakePhoto, .manualInput]
            )
            
        case .multipleObjectsAmbiguous:
            return .showObjectSelection(
                title: "检测到多个物品",
                message: "图像中包含多个物品，请选择要识别的物品：",
                detectedObjects: await extractDetectedObjects(from: image),
                canSelectMultiple: true
            )
            
        case .networkUnavailable:
            return await handleNetworkUnavailable()
            
        case .offlineModelNotAvailable:
            return .downloadOfflineModel(
                title: "离线模型不可用",
                message: "需要下载离线识别模型以支持无网络识别",
                modelInfo: getRequiredModelInfo(),
                estimatedSize: "50MB",
                canSkip: true
            )
            
        case .processingTimeout:
            return .optimizeAndRetry(
                title: "处理超时",
                message: "图像处理时间过长，建议优化后重试：",
                optimizations: [.compressImage, .cropToMainObject, .enhanceContrast],
                canRetryOriginal: true
            )
            
        case .insufficientLighting:
            return .enhanceImage(
                title: "光线不足",
                message: "图像光线不足，正在尝试自动增强：",
                enhancements: [.adjustBrightness(delta: 0.3), .increaseContrast, .reduceNoise],
                showPreview: true
            )
            
        case .imageTooBig(let currentSize, let maxSize):
            return .compressImage(
                title: "图像过大",
                message: "图像大小超出限制，正在压缩：",
                currentSize: currentSize,
                targetSize: maxSize,
                qualityOptions: [.high, .medium, .low]
            )
            
        case .unsupportedFormat:
            return .convertFormat(
                title: "格式不支持",
                message: "图像格式不支持，正在转换为JPEG格式",
                targetFormat: .jpeg,
                qualityLevel: 0.8
            )
            
        case .cameraPermissionDenied:
            return .requestPermission(
                title: "需要相机权限",
                message: "使用拍照识别功能需要相机权限",
                permissionType: .camera,
                settingsDeepLink: UIApplication.openSettingsURLString
            )
            
        case .recognitionServiceUnavailable:
            return await handleServiceUnavailable()
            
        case .imageProcessingFailed:
            return .suggestManualInput(
                title: "图像处理失败",
                message: "无法处理当前图像，请尝试以下方法：",
                suggestions: [
                    "重新选择图片",
                    "检查图片格式是否正确",
                    "手动输入物品信息"
                ],
                alternativeActions: [.retakePhoto, .manualInput]
            )
            
        case .noImageSelected:
            return .suggestManualInput(
                title: "未选择图片",
                message: "请先选择或拍摄图片",
                suggestions: ["选择图片", "拍摄新照片"],
                alternativeActions: [.retakePhoto]
            )
            
        case .networkError(let error):
            return .suggestManualInput(
                title: "网络错误",
                message: "网络连接出现问题：\(error.localizedDescription)",
                suggestions: ["检查网络连接", "稍后重试", "使用离线模式"],
                alternativeActions: [.retakePhoto, .manualInput]
            )
            
        case .apiError(let message):
            return .suggestManualInput(
                title: "API错误",
                message: "服务器返回错误：\(message)",
                suggestions: ["稍后重试", "手动输入物品信息"],
                alternativeActions: [.retakePhoto, .manualInput]
            )
            
        case .invalidImageFormat:
            return .convertFormat(
                title: "图像格式无效",
                message: "图像格式不正确，正在转换",
                targetFormat: .jpeg,
                qualityLevel: 0.8
            )
            
        case .tooManyObjects:
            return .showObjectSelection(
                title: "物品过多",
                message: "图像中包含过多物品，请选择要识别的物品",
                detectedObjects: await extractDetectedObjects(from: image),
                canSelectMultiple: false
            )
        }
    }
    
    // MARK: - 具体错误处理方法
    
    private func handleImageQualityIssues(_ issues: [ImageQualityIssue], image: UIImage?) async -> RecoveryAction {
        var enhancements: [ImageEnhancement] = []
        var suggestions: [String] = []
        
        for issue in issues {
            switch issue {
            case .tooBlurry(let severity):
                enhancements.append(.sharpen(intensity: min(severity * 2, 1.0)))
                suggestions.append("图像模糊，建议重新拍摄或使用防抖功能")
                
            case .poorLighting(let type):
                switch type {
                case .tooHigh:
                    enhancements.append(.adjustBrightness(delta: -0.2))
                    suggestions.append("图像过亮，建议降低曝光或避免强光")
                case .tooLow:
                    enhancements.append(.adjustBrightness(delta: 0.3))
                    enhancements.append(.increaseContrast)
                    suggestions.append("图像过暗，建议增加光源或使用闪光灯")
                case .uneven:
                    enhancements.append(.normalizeExposure)
                    suggestions.append("光线不均匀，建议调整拍摄角度")
                }
                
            case .tooSmall(let currentSize, let minimumSize):
                suggestions.append("图像分辨率过低（\(Int(currentSize.width))x\(Int(currentSize.height))），建议使用更高分辨率拍摄（至少\(Int(minimumSize.width))x\(Int(minimumSize.height))）")
                
            case .complexBackground:
                enhancements.append(.backgroundBlur)
                suggestions.append("背景复杂，建议将物品放在简单背景前")
                
            case .multipleObjects:
                suggestions.append("检测到多个物品，建议单独拍摄每个物品")
                
            case .blurry:
                enhancements.append(.sharpen(intensity: 0.5))
                suggestions.append("图像模糊，建议重新拍摄")
                
            case .darkImage:
                enhancements.append(.adjustBrightness(delta: 0.3))
                suggestions.append("图像过暗，建议增加光源")
                
            case .overexposed:
                enhancements.append(.adjustBrightness(delta: -0.2))
                suggestions.append("图像过曝，建议降低曝光")
                
            case .lowResolution:
                suggestions.append("图像分辨率过低，建议使用更高分辨率拍摄")
                
            case .poorContrast:
                enhancements.append(.increaseContrast)
                suggestions.append("图像对比度不足，正在自动调整")
            }
        }
        
        if !enhancements.isEmpty {
            return .enhanceImage(
                title: "图像质量优化",
                message: "正在自动优化图像质量：",
                enhancements: enhancements,
                showPreview: true,
                fallbackSuggestions: suggestions
            )
        } else {
            return .suggestRetake(
                title: "图像质量问题",
                message: "检测到以下图像质量问题：",
                issues: suggestions,
                retakeGuidance: generateRetakeGuidance(for: issues)
            )
        }
    }
    
    private func handleNetworkUnavailable() async -> RecoveryAction {
        let hasOfflineCapability = await checkOfflineCapability()
        
        if hasOfflineCapability {
            return .fallbackToOffline(
                title: "网络不可用",
                message: "正在切换到离线识别模式",
                offlineCapabilities: [
                    "基础物品分类",
                    "常见旅行用品识别",
                    "颜色和形状分析"
                ],
                limitations: [
                    "识别准确度可能降低",
                    "无法识别特殊或新颖物品",
                    "缺少详细属性信息"
                ]
            )
        } else {
            return .waitForNetwork(
                title: "网络连接失败",
                message: "照片识别需要网络连接，请检查网络设置",
                suggestions: [
                    "检查WiFi或移动数据连接",
                    "尝试切换网络",
                    "稍后重试"
                ],
                canDownloadOfflineModel: true
            )
        }
    }
    
    private func handleServiceUnavailable() async -> RecoveryAction {
        let alternativeServices = await getAlternativeServices()
        
        if !alternativeServices.isEmpty {
            return .switchService(
                title: "服务暂时不可用",
                message: "主要识别服务不可用，可以尝试备用服务：",
                alternatives: alternativeServices,
                estimatedAccuracy: 0.75
            )
        } else {
            return .scheduleRetry(
                title: "服务维护中",
                message: "识别服务正在维护，将在恢复后自动重试",
                retryInterval: 300, // 5分钟
                maxRetries: 3,
                canNotifyWhenReady: true
            )
        }
    }
    
    // MARK: - 恢复操作执行
    
    private func performRecoveryAction(_ action: RecoveryAction, image: UIImage?) async throws -> RecoveryResult {
        switch action {
        case .enhanceImage(_, _, let enhancements, _, _):
            guard let image = image else {
                throw PhotoRecognitionError.noObjectsDetected
            }
            let enhancedImage = try await applyImageEnhancements(image, enhancements: enhancements)
            return .imageEnhanced(enhancedImage)
            
        case .compressImage(_, _, _, let targetSize, _):
            guard let image = image else {
                throw PhotoRecognitionError.noObjectsDetected
            }
            let compressedImage = try await compressImage(image, targetSize: targetSize)
            return .imageCompressed(compressedImage)
            
        case .convertFormat(_, _, let targetFormat, let quality):
            guard let image = image else {
                throw PhotoRecognitionError.noObjectsDetected
            }
            let convertedImage = try await convertImageFormat(image, to: targetFormat, quality: quality)
            return .imageConverted(convertedImage)
            
        case .fallbackToOffline:
            return .offlineModeActivated
            
        case .downloadOfflineModel(_, _, let modelInfo, _, _):
            try await downloadOfflineModel(modelInfo)
            return .modelDownloaded
            
        case .requestPermission(_, _, let permissionType, _):
            let granted = try await requestPermission(permissionType)
            return .permissionResult(granted)
            
        default:
            return .actionCompleted
        }
    }
    
    // MARK: - 辅助方法
    
    private func extractDetectedObjects(from image: UIImage?) async -> [DetectedObjectInfo] {
        guard image != nil else { return [] }
        
        // 这里应该调用对象检测服务
        // 暂时返回模拟数据
        return [
            DetectedObjectInfo(
                id: UUID(),
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4),
                confidence: 0.85,
                category: "电子设备",
                description: "可能是手机或平板电脑"
            ),
            DetectedObjectInfo(
                id: UUID(),
                boundingBox: CGRect(x: 0.5, y: 0.2, width: 0.3, height: 0.5),
                confidence: 0.72,
                category: "服装",
                description: "可能是衣物或配饰"
            )
        ]
    }
    
    private func generateRetakeGuidance(for issues: [ImageQualityIssue]) -> RetakeGuidance {
        var tips: [String] = []
        var cameraSettings: [String] = []
        
        for issue in issues {
            switch issue {
            case .tooBlurry:
                tips.append("保持手机稳定，可以使用三脚架或靠在稳定表面上")
                cameraSettings.append("启用防抖功能")
                
            case .poorLighting(.tooHigh):
                tips.append("避免直射阳光，寻找柔和光线环境")
                cameraSettings.append("降低曝光补偿")
                
            case .poorLighting(.tooLow):
                tips.append("增加光源或使用闪光灯")
                cameraSettings.append("提高ISO或使用夜间模式")
                
            case .poorLighting(.uneven):
                tips.append("调整拍摄角度，避免阴影遮挡")
                
            case .tooSmall:
                tips.append("靠近物品拍摄，确保物品占据画面主要部分")
                
            case .complexBackground:
                tips.append("将物品放在简单、单色背景前")
                
            case .multipleObjects:
                tips.append("单独拍摄每个物品，或确保主要物品突出")
                
            case .blurry:
                tips.append("保持手机稳定，避免手抖")
                cameraSettings.append("使用防抖功能")
                
            case .darkImage:
                tips.append("增加光源或使用闪光灯")
                cameraSettings.append("提高亮度")
                
            case .overexposed:
                tips.append("避免强光直射")
                cameraSettings.append("降低曝光")
                
            case .lowResolution:
                tips.append("使用更高分辨率设置")
                cameraSettings.append("选择最高画质模式")
                
            case .poorContrast:
                tips.append("改善光线条件")
                cameraSettings.append("调整对比度设置")
            }
        }
        
        return RetakeGuidance(
            tips: tips,
            cameraSettings: cameraSettings,
            idealConditions: [
                "充足但柔和的光线",
                "简单的背景",
                "物品清晰可见",
                "稳定的拍摄环境"
            ]
        )
    }
    
    private func checkOfflineCapability() async -> Bool {
        // 检查是否有可用的离线模型
        // 检查是否有可用的离线模型 - 简化实现
        return true
    }
    
    private func getRequiredModelInfo() -> OfflineModelInfo {
        return OfflineModelInfo(
            name: "基础物品识别模型",
            version: "1.0",
            categories: ["电子设备", "服装", "日用品", "旅行用品"],
            accuracy: 0.78,
            size: 52428800 // 50MB
        )
    }
    
    private func getAlternativeServices() async -> [AlternativeService] {
        return [
            AlternativeService(
                name: "备用识别服务",
                description: "基于本地模型的识别服务",
                accuracy: 0.75,
                isAvailable: true
            )
        ]
    }
    
    // MARK: - 图像处理方法
    
    private func applyImageEnhancements(_ image: UIImage, enhancements: [ImageEnhancement]) async throws -> UIImage {
        var processedImage = image
        
        for enhancement in enhancements {
            switch enhancement {
            case .adjustBrightness(let delta):
                processedImage = try await adjustBrightness(processedImage, delta: delta)
            case .increaseContrast:
                processedImage = try await increaseContrast(processedImage)
            case .sharpen(let intensity):
                processedImage = try await sharpenImage(processedImage, intensity: intensity)
            case .normalizeExposure:
                processedImage = try await normalizeExposure(processedImage)
            case .backgroundBlur:
                processedImage = try await blurBackground(processedImage)
            case .reduceNoise:
                processedImage = try await reduceNoise(processedImage)
            }
        }
        
        return processedImage
    }
    
    private func adjustBrightness(_ image: UIImage, delta: Double) async throws -> UIImage {
        // 实现亮度调整
        return image // 暂时返回原图
    }
    
    private func increaseContrast(_ image: UIImage) async throws -> UIImage {
        // 实现对比度增强
        return image // 暂时返回原图
    }
    
    private func sharpenImage(_ image: UIImage, intensity: Double) async throws -> UIImage {
        // 实现图像锐化
        return image // 暂时返回原图
    }
    
    private func normalizeExposure(_ image: UIImage) async throws -> UIImage {
        // 实现曝光标准化
        return image // 暂时返回原图
    }
    
    private func blurBackground(_ image: UIImage) async throws -> UIImage {
        // 实现背景模糊
        return image // 暂时返回原图
    }
    
    private func reduceNoise(_ image: UIImage) async throws -> UIImage {
        // 实现噪声减少
        return image // 暂时返回原图
    }
    
    private func compressImage(_ image: UIImage, targetSize: Int) async throws -> UIImage {
        // 实现图像压缩
        return image // 暂时返回原图
    }
    
    private func convertImageFormat(_ image: UIImage, to format: ImageFormat, quality: Double) async throws -> UIImage {
        // 实现格式转换
        return image // 暂时返回原图
    }
    
    // MARK: - 权限和模型管理
    
    private func requestPermission(_ type: PermissionType) async throws -> Bool {
        // 实现权限请求
        return true // 暂时返回成功
    }
    
    private func downloadOfflineModel(_ modelInfo: OfflineModelInfo) async throws {
        // 实现模型下载
    }
    
    // MARK: - 错误记录
    
    private func recordErrorAndRecovery(error: PhotoRecognitionError, action: RecoveryAction) async {
        _ = PhotoRecognitionErrorRecord(
            error: error,
            recoveryAction: action,
            timestamp: Date(),
            context: "PhotoRecognitionErrorRecovery"
        )
        
        // 记录到错误处理服务
        errorHandlingService.handleError(error, context: "照片识别错误恢复", showToUser: false)
    }
    
    // MARK: - 清理方法
    
    func clearRecoveryState() {
        currentRecoveryAction = nil
        isShowingRecoveryGuidance = false
        recoveryProgress = nil
    }
}

// MARK: - 数据模型

// PhotoRecognitionError 现在在 AIModels.swift 中定义

// 使用 ImagePreprocessor 中已定义的 ImageQualityIssue 和 LightingIssue

/// 恢复操作类型
enum RecoveryAction {
    case enhanceImage(title: String, message: String, enhancements: [ImageEnhancement], showPreview: Bool, fallbackSuggestions: [String] = [])
    case compressImage(title: String, message: String, currentSize: Int, targetSize: Int, qualityOptions: [CompressionQuality])
    case convertFormat(title: String, message: String, targetFormat: ImageFormat, qualityLevel: Double)
    case suggestRetake(title: String, message: String, issues: [String], retakeGuidance: RetakeGuidance)
    case suggestManualInput(title: String, message: String, suggestions: [String], alternativeActions: [AlternativeAction])
    case showObjectSelection(title: String, message: String, detectedObjects: [DetectedObjectInfo], canSelectMultiple: Bool)
    case fallbackToOffline(title: String, message: String, offlineCapabilities: [String], limitations: [String])
    case waitForNetwork(title: String, message: String, suggestions: [String], canDownloadOfflineModel: Bool)
    case downloadOfflineModel(title: String, message: String, modelInfo: OfflineModelInfo, estimatedSize: String, canSkip: Bool)
    case optimizeAndRetry(title: String, message: String, optimizations: [OptimizationType], canRetryOriginal: Bool)
    case requestPermission(title: String, message: String, permissionType: PermissionType, settingsDeepLink: String)
    case switchService(title: String, message: String, alternatives: [AlternativeService], estimatedAccuracy: Double)
    case scheduleRetry(title: String, message: String, retryInterval: TimeInterval, maxRetries: Int, canNotifyWhenReady: Bool)
}

/// 图像增强类型
enum ImageEnhancement {
    case adjustBrightness(delta: Double)
    case increaseContrast
    case sharpen(intensity: Double)
    case normalizeExposure
    case backgroundBlur
    case reduceNoise
}

/// 压缩质量选项
enum CompressionQuality: String, CaseIterable {
    case high = "高质量"
    case medium = "中等质量"
    case low = "低质量"
    
    var compressionRatio: Double {
        switch self {
        case .high: return 0.8
        case .medium: return 0.6
        case .low: return 0.4
        }
    }
}

/// 图像格式
enum ImageFormat {
    case jpeg
    case png
    case heic
}

/// 重拍指导
struct RetakeGuidance {
    let tips: [String]
    let cameraSettings: [String]
    let idealConditions: [String]
}

/// 检测到的对象信息
struct DetectedObjectInfo: Identifiable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Double
    let category: String
    let description: String
}

/// 替代操作
enum AlternativeAction {
    case retakePhoto
    case manualInput
    case skipRecognition
    case useOfflineMode
    
    var displayName: String {
        switch self {
        case .retakePhoto:
            return "重新拍照"
        case .manualInput:
            return "手动输入"
        case .skipRecognition:
            return "跳过识别"
        case .useOfflineMode:
            return "使用离线模式"
        }
    }
}

/// 权限类型
enum PermissionType {
    case camera
    case photoLibrary
    case microphone
}

/// 离线模型信息
struct OfflineModelInfo {
    let name: String
    let version: String
    let categories: [String]
    let accuracy: Double
    let size: Int64
}

/// 替代服务
struct AlternativeService {
    let name: String
    let description: String
    let accuracy: Double
    let isAvailable: Bool
}

/// 优化类型
enum OptimizationType {
    case compressImage
    case cropToMainObject
    case enhanceContrast
    case reduceResolution
}

// RecoveryResult 现在在 AIModels.swift 中定义

/// 恢复进度
struct RecoveryProgress {
    let action: RecoveryAction
    let stage: RecoveryStage
    let progress: Double
    let error: Error?
    
    init(action: RecoveryAction, stage: RecoveryStage, progress: Double = 0.0, error: Error? = nil) {
        self.action = action
        self.stage = stage
        self.progress = progress
        self.error = error
    }
}

/// 恢复阶段
enum RecoveryStage {
    case preparing
    case processing
    case completed
    case failed
}

/// 照片识别错误记录
struct PhotoRecognitionErrorRecord {
    let error: PhotoRecognitionError
    let recoveryAction: RecoveryAction
    let timestamp: Date
    let context: String
}