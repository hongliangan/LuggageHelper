import Foundation
import CoreML
import Vision
import UIKit
import os.log

/// 离线识别服务
/// 
/// 提供基于本地 CoreML 模型的物品识别功能，支持在无网络环境下进行基础的物品分类和识别。
/// 
/// 主要功能：
/// - 本地 CoreML 模型管理和下载
/// - 常见旅行物品的离线识别
/// - 图像预处理和特征提取
/// - 识别结果置信度评估
/// - 模型版本管理和更新
final class OfflineRecognitionService: NSObject, ObservableObject {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = OfflineRecognitionService()
    
    /// 私有初始化
    private override init() {
        super.init()
        setupModelDirectory()
        loadAvailableModels()
    }
    
    // MARK: - 日志配置
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.luggagehelper.offline", category: "OfflineRecognition")
    
    // MARK: - 可观察属性
    
    /// 是否正在下载模型
    @Published var isDownloadingModel = false
    
    /// 下载进度 (0.0 - 1.0)
    @Published var downloadProgress: Double = 0.0
    
    /// 当前可用的模型
    @Published var availableModels: [OfflineModel] = []
    
    /// 错误消息
    @Published var errorMessage: String?
    
    // MARK: - 常量配置
    
    /// 模型存储目录
    private let modelDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("OfflineModels")
    }()
    
    /// 支持的物品类别
    private let supportedCategories: [ItemCategory] = [
        .clothing, .electronics, .toiletries, .documents, 
        .medicine, .accessories, .shoes, .books, .sports
    ]
    
    /// 模型配置
    private let modelConfigs: [ItemCategory: ModelConfig] = [
        .clothing: ModelConfig(
            name: "ClothingClassifier",
            version: "1.0",
            url: "https://models.luggagehelper.com/clothing_v1.mlmodel",
            size: 25 * 1024 * 1024, // 25MB
            accuracy: 0.85
        ),
        .electronics: ModelConfig(
            name: "ElectronicsClassifier", 
            version: "1.0",
            url: "https://models.luggagehelper.com/electronics_v1.mlmodel",
            size: 30 * 1024 * 1024, // 30MB
            accuracy: 0.88
        ),
        .toiletries: ModelConfig(
            name: "ToiletriesClassifier",
            version: "1.0", 
            url: "https://models.luggagehelper.com/toiletries_v1.mlmodel",
            size: 20 * 1024 * 1024, // 20MB
            accuracy: 0.82
        ),
        .accessories: ModelConfig(
            name: "AccessoriesClassifier",
            version: "1.0",
            url: "https://models.luggagehelper.com/accessories_v1.mlmodel", 
            size: 22 * 1024 * 1024, // 22MB
            accuracy: 0.80
        ),
        .shoes: ModelConfig(
            name: "ShoesClassifier",
            version: "1.0",
            url: "https://models.luggagehelper.com/shoes_v1.mlmodel",
            size: 18 * 1024 * 1024, // 18MB
            accuracy: 0.86
        )
    ]
    
    // MARK: - 私有属性
    
    /// 已加载的模型缓存
    private var loadedModels: [ItemCategory: MLModel] = [:]
    
    /// 模型下载任务
    private var downloadTasks: [ItemCategory: URLSessionDownloadTask] = [:]
    
    /// URLSession 用于下载
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - 公共方法
    
    /// 检查指定类别的模型是否可用
    /// - Parameter category: 物品类别
    /// - Returns: 是否可用
    func isModelAvailable(for category: ItemCategory) -> Bool {
        guard supportedCategories.contains(category) else { return false }
        
        let modelPath = getModelPath(for: category)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// 获取所有可用的类别
    /// - Returns: 可用类别数组
    func getAvailableCategories() -> [ItemCategory] {
        return supportedCategories.filter { isModelAvailable(for: $0) }
    }
    
    /// 下载指定类别的模型
    /// - Parameter category: 物品类别
    func downloadModel(for category: ItemCategory) async throws {
        guard supportedCategories.contains(category) else {
            throw OfflineRecognitionError.unsupportedCategory(category)
        }
        
        guard let config = modelConfigs[category] else {
            throw OfflineRecognitionError.modelConfigNotFound(category)
        }
        
        // 检查是否已经在下载
        if downloadTasks[category] != nil {
            logger.info("模型 \(config.name) 正在下载中")
            return
        }
        
        // 检查是否已经存在
        if isModelAvailable(for: category) {
            logger.info("模型 \(config.name) 已存在")
            return
        }
        
        await MainActor.run {
            isDownloadingModel = true
            downloadProgress = 0.0
            errorMessage = nil
        }
        
        do {
            try await performModelDownload(category: category, config: config)
            
            await MainActor.run {
                isDownloadingModel = false
                downloadProgress = 1.0
            }
            
            // 重新加载可用模型
            loadAvailableModels()
            
            logger.info("模型 \(config.name) 下载完成")
            
        } catch {
            await MainActor.run {
                isDownloadingModel = false
                errorMessage = error.localizedDescription
            }
            
            logger.error("模型下载失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 离线识别物品
    /// - Parameter image: 输入图像
    /// - Returns: 离线识别结果
    func recognizeOffline(_ image: UIImage) async throws -> OfflineRecognitionResult {
        logger.info("开始离线识别")
        
        // 预处理图像
        guard let processedImage = preprocessImage(image) else {
            throw OfflineRecognitionError.imageProcessingFailed
        }
        
        // 尝试使用所有可用模型进行识别
        var bestResult: OfflineRecognitionResult?
        var bestConfidence: Double = 0.0
        
        for category in getAvailableCategories() {
            do {
                let result = try await recognizeWithModel(processedImage, category: category)
                
                if result.confidence > bestConfidence {
                    bestConfidence = result.confidence
                    bestResult = result
                }
                
            } catch {
                logger.warning("使用 \(category.displayName) 模型识别失败: \(error.localizedDescription)")
                continue
            }
        }
        
        guard let result = bestResult else {
            throw OfflineRecognitionError.noModelAvailable
        }
        
        logger.info("离线识别完成，类别: \(result.category.displayName), 置信度: \(result.confidence)")
        return result
    }
    
    /// 删除指定类别的模型
    /// - Parameter category: 物品类别
    func deleteModel(for category: ItemCategory) throws {
        let modelPath = getModelPath(for: category)
        
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
            
            // 从缓存中移除
            loadedModels.removeValue(forKey: category)
            
            // 更新可用模型列表
            loadAvailableModels()
            
            logger.info("已删除模型: \(category.displayName)")
        }
    }
    
    /// 获取所有模型的总大小
    /// - Returns: 总大小（字节）
    func getTotalModelSize() -> Int64 {
        var totalSize: Int64 = 0
        
        for category in getAvailableCategories() {
            let modelPath = getModelPath(for: category)
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            } catch {
                logger.warning("无法获取模型大小: \(category.displayName)")
            }
        }
        
        return totalSize
    }
    
    /// 清理所有模型
    func clearAllModels() throws {
        for category in supportedCategories {
            try? deleteModel(for: category)
        }
        
        // 清理模型目录
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.removeItem(at: modelDirectory)
            setupModelDirectory()
        }
        
        loadedModels.removeAll()
        loadAvailableModels()
        
        logger.info("已清理所有离线模型")
    }
    
    // MARK: - 私有方法
    
    /// 设置模型目录
    private func setupModelDirectory() {
        if !FileManager.default.fileExists(atPath: modelDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
                logger.info("创建模型目录: \(self.modelDirectory.path)")
            } catch {
                logger.error("创建模型目录失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 加载可用模型列表
    private func loadAvailableModels() {
        var models: [OfflineModel] = []
        
        for category in supportedCategories {
            guard let config = modelConfigs[category] else { continue }
            
            let isAvailable = isModelAvailable(for: category)
            let modelPath = getModelPath(for: category)
            
            var fileSize: Int64 = 0
            if isAvailable {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
                    fileSize = attributes[.size] as? Int64 ?? 0
                } catch {
                    logger.warning("无法获取模型文件大小: \(category.displayName)")
                }
            }
            
            let model = OfflineModel(
                category: category,
                name: config.name,
                version: config.version,
                isAvailable: isAvailable,
                fileSize: fileSize,
                expectedAccuracy: config.accuracy,
                downloadURL: config.url
            )
            
            models.append(model)
        }
        
        DispatchQueue.main.async {
            self.availableModels = models
        }
    }
    
    /// 获取模型文件路径
    private func getModelPath(for category: ItemCategory) -> URL {
        guard let config = modelConfigs[category] else {
            return modelDirectory.appendingPathComponent("\(category.rawValue).mlmodel")
        }
        return modelDirectory.appendingPathComponent("\(config.name).mlmodel")
    }
    
    /// 执行模型下载
    private func performModelDownload(category: ItemCategory, config: ModelConfig) async throws {
        guard let url = URL(string: config.url) else {
            throw OfflineRecognitionError.invalidModelURL(config.url)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = downloadSession.downloadTask(with: url) { [weak self] tempURL, response, error in
                guard let self = self else {
                    continuation.resume(throwing: OfflineRecognitionError.downloadCancelled)
                    return
                }
                
                // 清理下载任务
                self.downloadTasks.removeValue(forKey: category)
                
                if let error = error {
                    continuation.resume(throwing: OfflineRecognitionError.downloadFailed(error))
                    return
                }
                
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: OfflineRecognitionError.downloadFailed(NSError(domain: "OfflineRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "临时文件不存在"])))
                    return
                }
                
                do {
                    let destinationURL = self.getModelPath(for: category)
                    
                    // 如果目标文件已存在，先删除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // 移动文件到目标位置
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    
                    // 验证模型文件
                    try self.validateModel(at: destinationURL)
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: OfflineRecognitionError.downloadFailed(error))
                }
            }
            
            downloadTasks[category] = task
            task.resume()
        }
    }
    
    /// 验证模型文件
    private func validateModel(at url: URL) throws {
        do {
            let _ = try MLModel(contentsOf: url)
            logger.info("模型验证成功: \(url.lastPathComponent)")
        } catch {
            // 删除无效的模型文件
            try? FileManager.default.removeItem(at: url)
            throw OfflineRecognitionError.invalidModelFile(error)
        }
    }
    
    /// 预处理图像
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        // 调整图像大小到模型期望的尺寸 (224x224)
        let targetSize = CGSize(width: 224, height: 224)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 使用指定模型进行识别
    private func recognizeWithModel(_ image: UIImage, category: ItemCategory) async throws -> OfflineRecognitionResult {
        // 加载模型
        let model = try await loadModel(for: category)
        
        // 创建 Vision 请求
        guard let cgImage = image.cgImage else {
            throw OfflineRecognitionError.imageProcessingFailed
        }
        
        let request = VNCoreMLRequest(model: try VNCoreMLModel(for: model))
        request.imageCropAndScaleOption = .centerCrop
        
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                
                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: OfflineRecognitionError.recognitionFailed)
                    return
                }
                
                // 构建识别结果
                let result = OfflineRecognitionResult(
                    category: category,
                    confidence: Double(topResult.confidence),
                    needsOnlineVerification: topResult.confidence < 0.8,
                    processingTime: 0.5,
                    modelVersion: modelConfigs[category]?.version
                )
                
                continuation.resume(returning: result)
                
            } catch {
                continuation.resume(throwing: OfflineRecognitionError.recognitionFailed)
            }
        }
    }
    
    /// 加载模型
    private func loadModel(for category: ItemCategory) async throws -> MLModel {
        // 检查缓存
        if let cachedModel = loadedModels[category] {
            return cachedModel
        }
        
        // 检查模型文件是否存在
        guard isModelAvailable(for: category) else {
            throw OfflineRecognitionError.modelNotAvailable(category)
        }
        
        let modelPath = getModelPath(for: category)
        
        do {
            let model = try MLModel(contentsOf: modelPath)
            loadedModels[category] = model
            logger.info("成功加载模型: \(category.displayName)")
            return model
        } catch {
            logger.error("加载模型失败: \(category.displayName) - \(error.localizedDescription)")
            throw OfflineRecognitionError.modelLoadFailed(category, error)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension OfflineRecognitionService: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard totalBytesExpectedToWrite > 0 else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.downloadProgress = progress
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 下载完成的处理在 performModelDownload 中进行
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("下载任务完成时出错: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.isDownloadingModel = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - 数据模型

// OfflineRecognitionResult 现在在 AIModels.swift 中定义

/// 离线模型信息
struct OfflineModel: Identifiable, Codable {
    let id = UUID()
    let category: ItemCategory
    let name: String
    let version: String
    let isAvailable: Bool
    let fileSize: Int64
    let expectedAccuracy: Double
    let downloadURL: String
    
    enum CodingKeys: String, CodingKey {
        case category, name, version, isAvailable, fileSize, expectedAccuracy, downloadURL
    }
    
    /// 格式化文件大小
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 格式化准确率
    var formattedAccuracy: String {
        return String(format: "%.1f%%", expectedAccuracy * 100)
    }
}

/// 模型配置
private struct ModelConfig {
    let name: String
    let version: String
    let url: String
    let size: Int64
    let accuracy: Double
}

/// 离线识别错误
enum OfflineRecognitionError: LocalizedError {
    case unsupportedCategory(ItemCategory)
    case modelConfigNotFound(ItemCategory)
    case modelNotAvailable(ItemCategory)
    case modelLoadFailed(ItemCategory, Error)
    case invalidModelURL(String)
    case invalidModelFile(Error)
    case downloadFailed(Error)
    case downloadCancelled
    case imageProcessingFailed
    case recognitionFailed
    case noModelAvailable
    
    var errorDescription: String? {
        switch self {
        case .unsupportedCategory(let category):
            return "不支持的物品类别: \(category.displayName)"
        case .modelConfigNotFound(let category):
            return "未找到模型配置: \(category.displayName)"
        case .modelNotAvailable(let category):
            return "模型不可用: \(category.displayName)"
        case .modelLoadFailed(let category, let error):
            return "模型加载失败 (\(category.displayName)): \(error.localizedDescription)"
        case .invalidModelURL(let url):
            return "无效的模型下载地址: \(url)"
        case .invalidModelFile(let error):
            return "无效的模型文件: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "模型下载失败: \(error.localizedDescription)"
        case .downloadCancelled:
            return "模型下载已取消"
        case .imageProcessingFailed:
            return "图像处理失败"
        case .recognitionFailed:
            return "离线识别失败"
        case .noModelAvailable:
            return "没有可用的离线模型"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unsupportedCategory:
            return "请选择支持的物品类别"
        case .modelNotAvailable:
            return "请先下载相应的离线模型"
        case .downloadFailed:
            return "请检查网络连接后重试"
        case .imageProcessingFailed:
            return "请尝试使用其他图片"
        case .noModelAvailable:
            return "请下载至少一个离线模型"
        default:
            return "请重试或联系技术支持"
        }
    }
}