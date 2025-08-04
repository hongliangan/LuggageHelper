import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 图像预处理服务
/// 提供图像质量验证、增强和标准化功能
final class ImagePreprocessor {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = ImagePreprocessor()
    
    /// 私有初始化
    private init() {
        setupCoreImageContext()
    }
    
    // MARK: - 属性
    
    /// Core Image 上下文
    private var ciContext: CIContext!
    
    /// 图像处理配置
    private let config = ImageProcessingConfig()
    
    // MARK: - 初始化
    
    /// 设置 Core Image 上下文
    private func setupCoreImageContext() {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ]
        ciContext = CIContext(options: options)
    }
    
    // MARK: - 主要接口
    
    /// 增强图像质量
    /// - Parameter image: 原始图像
    /// - Returns: 增强后的图像
    func enhanceImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let enhancedImage = self.performImageEnhancement(image)
                continuation.resume(returning: enhancedImage)
            }
        }
    }
    
    /// 标准化图像
    /// - Parameter image: 原始图像
    /// - Returns: 标准化后的图像
    func normalizeImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let normalizedImage = self.performImageNormalization(image)
                continuation.resume(returning: normalizedImage)
            }
        }
    }
    
    /// 验证图像质量
    /// - Parameter image: 待验证的图像
    /// - Returns: 图像质量结果
    func validateImageQuality(_ image: UIImage) async -> ImageQualityResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.performImageQualityValidation(image)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 提取最佳区域
    /// - Parameter image: 原始图像
    /// - Returns: 提取的最佳区域图像
    func extractOptimalRegion(_ image: UIImage) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let extractedImage = self.performOptimalRegionExtraction(image)
                continuation.resume(returning: extractedImage)
            }
        }
    }
    
    /// 综合预处理
    /// - Parameters:
    ///   - image: 原始图像
    ///   - options: 预处理选项
    /// - Returns: 预处理结果
    func preprocessImage(_ image: UIImage, options: PreprocessingOptions = .default) async -> PreprocessingResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.performComprehensivePreprocessing(image, options: options)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 图像增强实现
    
    /// 执行图像增强
    private func performImageEnhancement(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            return image
        }
        
        var processedImage = ciImage
        
        // 1. 自动调整色调
        if let autoAdjustFilter = CIFilter(name: "CIColorControls") {
            autoAdjustFilter.setValue(processedImage, forKey: kCIInputImageKey)
            
            // 分析图像亮度
            let brightness = calculateImageBrightness(processedImage)
            let contrast = calculateImageContrast(processedImage)
            
            // 根据分析结果调整参数
            let brightnessAdjustment = calculateBrightnessAdjustment(brightness)
            let contrastAdjustment = calculateContrastAdjustment(contrast)
            
            autoAdjustFilter.setValue(brightnessAdjustment, forKey: kCIInputBrightnessKey)
            autoAdjustFilter.setValue(contrastAdjustment, forKey: kCIInputContrastKey)
            autoAdjustFilter.setValue(1.1, forKey: kCIInputSaturationKey) // 轻微增加饱和度
            
            if let outputImage = autoAdjustFilter.outputImage {
                processedImage = outputImage
            }
        }
        
        // 2. 锐化处理
        if let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)
            sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey)
            
            if let outputImage = sharpenFilter.outputImage {
                processedImage = outputImage
            }
        }
        
        // 3. 噪点减少 (使用可用的滤镜)
        if let noiseReductionFilter = CIFilter(name: "CIMedianFilter") {
            noiseReductionFilter.setValue(processedImage, forKey: kCIInputImageKey)
            
            if let outputImage = noiseReductionFilter.outputImage {
                processedImage = outputImage
            }
        }
        
        // 4. 转换回 UIImage
        guard let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// 执行图像标准化
    private func performImageNormalization(_ image: UIImage) -> UIImage {
        var processedImage = image
        
        // 1. 修正图像方向
        processedImage = processedImage.fixOrientation()
        
        // 2. 调整尺寸
        processedImage = resizeImageForProcessing(processedImage)
        
        // 3. 标准化颜色空间
        processedImage = normalizeColorSpace(processedImage)
        
        return processedImage
    }
    
    /// 执行图像质量验证
    private func performImageQualityValidation(_ image: UIImage) -> ImageQualityResult {
        var issues: [ImageQualityIssue] = []
        var suggestions: [String] = []
        var score: Double = 1.0
        
        // 1. 检查图像尺寸
        let sizeIssue = validateImageSize(image)
        if let issue = sizeIssue {
            issues.append(issue)
            score -= 0.2
            suggestions.append("请使用更高分辨率的图像")
        }
        
        // 2. 检查模糊度
        let blurScore = calculateBlurScore(image)
        if blurScore < config.minBlurScore {
            let severity = (config.minBlurScore - blurScore) / config.minBlurScore
            issues.append(.tooBlurry(severity: severity))
            score -= 0.3
            suggestions.append("图像过于模糊，请重新拍摄")
        }
        
        // 3. 检查光线条件
        let lightingIssue = validateLighting(image)
        if let issue = lightingIssue {
            issues.append(.poorLighting(type: issue))
            score -= 0.25
            suggestions.append("请在光线充足的环境中拍摄")
        }
        
        // 4. 检查背景复杂度
        let backgroundComplexity = calculateBackgroundComplexity(image)
        if backgroundComplexity > config.maxBackgroundComplexity {
            issues.append(.complexBackground)
            score -= 0.15
            suggestions.append("请使用简单背景拍摄")
        }
        
        // 5. 检查多物体情况
        let objectCount = estimateObjectCount(image)
        if objectCount > 1 {
            issues.append(.multipleObjects)
            score -= 0.1
            suggestions.append("检测到多个物体，请选择要识别的物体")
        }
        
        // 确保分数不为负数
        score = max(0.0, score)
        
        return ImageQualityResult(
            overallScore: score,
            issues: issues,
            recommendations: suggestions,
            isAcceptable: score >= config.minAcceptableScore
        )
    }
    
    /// 执行最佳区域提取
    private func performOptimalRegionExtraction(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 使用 Vision 框架检测矩形区域
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = 0.2
        request.maximumObservations = 5
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results,
                  let bestRectangle = results.first else {
                return nil
            }
            
            // 转换坐标系并裁剪
            let boundingBox = bestRectangle.boundingBox
            let cropRect = VNImageRectForNormalizedRect(
                boundingBox,
                Int(image.size.width),
                Int(image.size.height)
            )
            
            guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
                return nil
            }
            
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            
        } catch {
            print("区域提取失败: \(error)")
            return nil
        }
    }
    
    /// 执行综合预处理
    private func performComprehensivePreprocessing(_ image: UIImage, options: PreprocessingOptions) -> PreprocessingResult {
        let startTime = Date()
        var processedImage = image
        var appliedOperations: [String] = []
        var qualityScore: Double = 1.0
        
        // 1. 质量验证
        let qualityResult = performImageQualityValidation(image)
        qualityScore = qualityResult.score
        
        // 2. 根据选项执行预处理
        if options.contains(.normalize) {
            processedImage = performImageNormalization(processedImage)
            appliedOperations.append("标准化")
        }
        
        if options.contains(.enhance) && qualityResult.score < 0.8 {
            processedImage = performImageEnhancement(processedImage)
            appliedOperations.append("增强")
        }
        
        if options.contains(.extractOptimalRegion) {
            if let extractedImage = performOptimalRegionExtraction(processedImage) {
                processedImage = extractedImage
                appliedOperations.append("区域提取")
            }
        }
        
        if options.contains(.resize) {
            processedImage = resizeImageForProcessing(processedImage)
            appliedOperations.append("尺寸调整")
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return PreprocessingResult(
            originalImage: image,
            processedImage: processedImage,
            qualityScore: qualityScore,
            appliedOperations: appliedOperations,
            processingTime: processingTime,
            qualityIssues: qualityResult.issues
        )
    }
    
    // MARK: - 辅助方法
    
    /// 调整图像尺寸用于处理
    private func resizeImageForProcessing(_ image: UIImage) -> UIImage {
        let maxDimension = config.maxProcessingDimension
        let currentSize = image.size
        
        // 如果图像已经足够小，直接返回
        if max(currentSize.width, currentSize.height) <= maxDimension {
            return image
        }
        
        // 计算缩放比例
        let scale = maxDimension / max(currentSize.width, currentSize.height)
        let newSize = CGSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )
        
        // 使用高质量重采样
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// 标准化颜色空间
    private func normalizeColorSpace(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        // 确保使用 sRGB 颜色空间
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return image
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let normalizedCGImage = context.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: normalizedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// 计算图像亮度
    private func calculateImageBrightness(_ ciImage: CIImage) -> Double {
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else {
            return 0.5 // 默认中等亮度
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // 计算亮度 (使用标准亮度公式)
        let brightness = (0.299 * Double(bitmap[0]) + 0.587 * Double(bitmap[1]) + 0.114 * Double(bitmap[2])) / 255.0
        return brightness
    }
    
    /// 计算图像对比度
    private func calculateImageContrast(_ ciImage: CIImage) -> Double {
        // 简化的对比度计算
        // 实际实现中可以使用更复杂的算法
        return 1.0 // 默认对比度
    }
    
    /// 计算亮度调整值
    private func calculateBrightnessAdjustment(_ brightness: Double) -> Double {
        if brightness < 0.3 {
            return 0.2 // 增加亮度
        } else if brightness > 0.7 {
            return -0.1 // 降低亮度
        }
        return 0.0 // 不调整
    }
    
    /// 计算对比度调整值
    private func calculateContrastAdjustment(_ contrast: Double) -> Double {
        return 1.1 // 轻微增加对比度
    }
    
    /// 验证图像尺寸
    private func validateImageSize(_ image: UIImage) -> ImageQualityIssue? {
        let size = image.size
        let minSize = config.minImageSize
        
        if size.width < minSize.width || size.height < minSize.height {
            return .tooSmall(currentSize: size, minimumSize: minSize)
        }
        
        return nil
    }
    
    /// 计算模糊分数
    private func calculateBlurScore(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // 使用 Laplacian 算子检测模糊度
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter(name: "CIConvolution3X3") else {
            return 0.5 // 默认分数
        }
        
        // Laplacian 核
        let laplacianKernel = CIVector(values: [0, -1, 0, -1, 4, -1, 0, -1, 0], count: 9)
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(laplacianKernel, forKey: kCIInputWeightsKey)
        
        guard let outputImage = filter.outputImage else {
            return 0.5
        }
        
        // 计算方差作为清晰度指标
        let extentVector = CIVector(x: outputImage.extent.origin.x, y: outputImage.extent.origin.y, z: outputImage.extent.size.width, w: outputImage.extent.size.height)
        
        guard let varianceFilter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: outputImage, kCIInputExtentKey: extentVector]),
              let varianceOutput = varianceFilter.outputImage else {
            return 0.5
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(varianceOutput, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let variance = Double(bitmap[0]) / 255.0
        return min(variance * 10, 1.0) // 标准化到 0-1 范围
    }
    
    /// 验证光线条件
    private func validateLighting(_ image: UIImage) -> LightingIssue? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let brightness = calculateImageBrightness(ciImage)
        
        if brightness < 0.2 {
            return .tooLow
        } else if brightness > 0.8 {
            return .tooHigh
        } else if brightness < 0.3 || brightness > 0.7 {
            return .uneven
        }
        
        return nil
    }
    
    /// 计算背景复杂度
    private func calculateBackgroundComplexity(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // 使用边缘检测来估算复杂度
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return 0.5
        }
        
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let edgeImage = edgeFilter.outputImage else {
            return 0.5
        }
        
        // 计算边缘密度
        let extentVector = CIVector(x: edgeImage.extent.origin.x, y: edgeImage.extent.origin.y, z: edgeImage.extent.size.width, w: edgeImage.extent.size.height)
        
        guard let avgFilter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: edgeImage, kCIInputExtentKey: extentVector]),
              let avgOutput = avgFilter.outputImage else {
            return 0.5
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(avgOutput, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let edgeDensity = Double(bitmap[0]) / 255.0
        return edgeDensity
    }
    
    /// 估算物体数量
    private func estimateObjectCount(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 5.0
        request.minimumSize = 0.1
        request.maximumObservations = 10
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            return request.results?.count ?? 1
        } catch {
            return 1
        }
    }
}

// MARK: - 配置和数据模型

/// 图像处理配置
private struct ImageProcessingConfig {
    let maxProcessingDimension: CGFloat = 1024
    let minImageSize = CGSize(width: 200, height: 200)
    let minBlurScore: Double = 0.3
    let maxBackgroundComplexity: Double = 0.7
    let minAcceptableScore: Double = 0.6
}

/// 预处理选项
struct PreprocessingOptions: OptionSet {
    let rawValue: Int
    
    static let normalize = PreprocessingOptions(rawValue: 1 << 0)
    static let enhance = PreprocessingOptions(rawValue: 1 << 1)
    static let extractOptimalRegion = PreprocessingOptions(rawValue: 1 << 2)
    static let resize = PreprocessingOptions(rawValue: 1 << 3)
    
    static let `default`: PreprocessingOptions = [.normalize, .enhance, .resize]
    static let all: PreprocessingOptions = [.normalize, .enhance, .extractOptimalRegion, .resize]
}

// ImageQualityResult 现在在 AIModels.swift 中定义

// ImageQualityIssue 现在在 AIModels.swift 中定义

// LightingIssue 现在在 AIModels.swift 中定义

/// 预处理结果
struct PreprocessingResult {
    let originalImage: UIImage
    let processedImage: UIImage
    let qualityScore: Double
    let appliedOperations: [String]
    let processingTime: TimeInterval
    let qualityIssues: [ImageQualityIssue]
}

// MARK: - UIImage 扩展

extension UIImage {
    /// 为 AI 识别调整尺寸
    func resizeForAI() -> UIImage {
        let preprocessor = ImagePreprocessor.shared
        let maxDimension: CGFloat = 1024
        let currentSize = self.size
        
        // 如果图像已经足够小，直接返回
        if max(currentSize.width, currentSize.height) <= maxDimension {
            return self
        }
        
        // 计算缩放比例
        let scale = maxDimension / max(currentSize.width, currentSize.height)
        let newSize = CGSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )
        
        // 使用高质量重采样
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// 增强对比度
    func enhanceContrast() -> UIImage {
        guard let ciImage = CIImage(image: self),
              let filter = CIFilter(name: "CIColorControls") else {
            return self
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey)
        
        guard let outputImage = filter.outputImage else {
            return self
        }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return self
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    /// 获取主要颜色
    func getDominantColors() -> [UIColor] {
        guard self.cgImage != nil else { return [] }
        
        // 简化实现：返回一些基本颜色用于演示
        // 实际实现中可以使用更复杂的颜色分析算法
        return [UIColor.blue, UIColor.black, UIColor.white]
    }
}

extension UIColor {
    /// 检查颜色是否接近另一个颜色
    func isCloseToColor(_ otherColor: UIColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let threshold: CGFloat = 0.3
        return abs(r1 - r2) < threshold && abs(g1 - g2) < threshold && abs(b1 - b2) < threshold
    }
}