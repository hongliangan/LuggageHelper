import Foundation
import UIKit

/// 照片识别质量管理器
/// 负责评估识别结果的质量和置信度，提供改进建议
class PhotoRecognitionQualityManager {
    
    // MARK: - 单例
    
    static let shared = PhotoRecognitionQualityManager()
    
    private init() {}
    
    // MARK: - 配置常量
    
    /// 置信度阈值配置
    struct ConfidenceThresholds {
        static let excellent: Double = 0.9      // 优秀
        static let good: Double = 0.8           // 良好
        static let acceptable: Double = 0.7     // 可接受
        static let poor: Double = 0.5           // 较差
        static let unacceptable: Double = 0.3   // 不可接受
    }
    
    /// 质量评估结果
    struct QualityAssessment {
        let overallScore: Double        // 总体评分 0.0-1.0
        let confidenceLevel: ConfidenceLevel
        let qualityIssues: [QualityIssue]
        let suggestions: [ImprovementSuggestion]
        let shouldRetry: Bool
        let alternativeStrategies: [PhotoRecognitionStrategy]
    }
    
    /// 置信度等级
    enum ConfidenceLevel: String, CaseIterable {
        case excellent = "excellent"
        case good = "good"
        case acceptable = "acceptable"
        case poor = "poor"
        case unacceptable = "unacceptable"
        
        var displayName: String {
            switch self {
            case .excellent: return "优秀"
            case .good: return "良好"
            case .acceptable: return "可接受"
            case .poor: return "较差"
            case .unacceptable: return "不可接受"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .acceptable: return "orange"
            case .poor: return "red"
            case .unacceptable: return "purple"
            }
        }
        
        var threshold: Double {
            switch self {
            case .excellent: return ConfidenceThresholds.excellent
            case .good: return ConfidenceThresholds.good
            case .acceptable: return ConfidenceThresholds.acceptable
            case .poor: return ConfidenceThresholds.poor
            case .unacceptable: return ConfidenceThresholds.unacceptable
            }
        }
    }
    
    /// 质量问题类型
    enum QualityIssue: String, CaseIterable {
        case lowConfidence = "lowConfidence"
        case inconsistentResults = "inconsistentResults"
        case poorImageQuality = "poorImageQuality"
        case multipleObjects = "multipleObjects"
        case insufficientFeatures = "insufficientFeatures"
        case ambiguousCategory = "ambiguousCategory"
        case unreliableWeightVolume = "unreliableWeightVolume"
        
        var displayName: String {
            switch self {
            case .lowConfidence: return "识别置信度过低"
            case .inconsistentResults: return "多策略结果不一致"
            case .poorImageQuality: return "图片质量较差"
            case .multipleObjects: return "包含多个物品"
            case .insufficientFeatures: return "特征信息不足"
            case .ambiguousCategory: return "类别判断模糊"
            case .unreliableWeightVolume: return "重量体积估算不可靠"
            }
        }
        
        var description: String {
            switch self {
            case .lowConfidence: return "系统对识别结果的确信程度较低"
            case .inconsistentResults: return "不同识别策略给出了不同的结果"
            case .poorImageQuality: return "图片模糊、光线不足或角度不佳"
            case .multipleObjects: return "图片中包含多个物品，影响主要物品识别"
            case .insufficientFeatures: return "物品特征不够明显，难以准确识别"
            case .ambiguousCategory: return "物品类别边界模糊，可能属于多个类别"
            case .unreliableWeightVolume: return "缺乏足够信息进行准确的重量体积估算"
            }
        }
    }
    
    /// 改进建议
    struct ImprovementSuggestion {
        let type: SuggestionType
        let title: String
        let description: String
        let priority: Int // 1-5, 5最高
        let actionable: Bool
        
        enum SuggestionType: String {
            case retakePhoto = "retakePhoto"
            case improveAngle = "improveAngle"
            case betterLighting = "betterLighting"
            case isolateObject = "isolateObject"
            case addHint = "addHint"
            case useAlternativeMethod = "useAlternativeMethod"
            case manualInput = "manualInput"
        }
    }
    
    // MARK: - 主要方法
    
    /// 评估识别结果质量
    /// - Parameters:
    ///   - result: 识别结果
    ///   - imageData: 原始图片数据
    ///   - strategies: 使用的识别策略
    /// - Returns: 质量评估结果
    func assessRecognitionQuality(
        result: ItemInfo,
        imageData: Data,
        strategies: [PhotoRecognitionStrategy] = []
    ) -> QualityAssessment {
        
        // 1. 评估置信度等级
        let confidenceLevel = determineConfidenceLevel(result.confidence)
        
        // 2. 分析图片质量
        let imageQuality = analyzeImageQuality(imageData)
        
        // 3. 检测质量问题
        let qualityIssues = detectQualityIssues(
            result: result,
            imageQuality: imageQuality,
            strategies: strategies
        )
        
        // 4. 生成改进建议
        let suggestions = generateImprovementSuggestions(
            issues: qualityIssues,
            confidenceLevel: confidenceLevel,
            imageQuality: imageQuality
        )
        
        // 5. 计算总体评分
        let overallScore = calculateOverallScore(
            confidence: result.confidence,
            imageQuality: imageQuality,
            issues: qualityIssues
        )
        
        // 6. 判断是否需要重试
        let shouldRetry = determineShouldRetry(
            confidenceLevel: confidenceLevel,
            issues: qualityIssues
        )
        
        // 7. 推荐替代策略
        let alternativeStrategies = recommendAlternativeStrategies(
            issues: qualityIssues,
            usedStrategies: strategies
        )
        
        return QualityAssessment(
            overallScore: overallScore,
            confidenceLevel: confidenceLevel,
            qualityIssues: qualityIssues,
            suggestions: suggestions,
            shouldRetry: shouldRetry,
            alternativeStrategies: alternativeStrategies
        )
    }
    
    /// 验证识别结果的合理性
    /// - Parameter result: 识别结果
    /// - Returns: 验证结果和问题列表
    func validateRecognitionResult(_ result: ItemInfo) -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []
        
        // 检查重量合理性
        if result.weight <= 0 {
            issues.append("重量不能为零或负数")
        } else if result.weight > 50000 { // 50kg
            issues.append("重量过大，可能不适合旅行携带")
        }
        
        // 检查体积合理性
        if result.volume <= 0 {
            issues.append("体积不能为零或负数")
        } else if result.volume > 100000 { // 100L
            issues.append("体积过大，可能超出行李箱容量")
        }
        
        // 检查尺寸合理性
        if let dimensions = result.dimensions {
            if dimensions.length <= 0 || dimensions.width <= 0 || dimensions.height <= 0 {
                issues.append("尺寸不能为零或负数")
            }
            
            let calculatedVolume = dimensions.volume
            let volumeDifference = abs(calculatedVolume - result.volume) / result.volume
            if volumeDifference > 0.5 { // 差异超过50%
                issues.append("尺寸与体积不匹配")
            }
        }
        
        // 检查置信度合理性
        if result.confidence < 0 || result.confidence > 1 {
            issues.append("置信度超出有效范围 (0-1)")
        }
        
        // 检查类别与重量体积的匹配性
        let categoryIssues = validateCategoryConsistency(result)
        issues.append(contentsOf: categoryIssues)
        
        return (isValid: issues.isEmpty, issues: issues)
    }
    
    /// 筛选高质量识别结果
    /// - Parameters:
    ///   - results: 识别结果列表
    ///   - minConfidence: 最小置信度要求
    /// - Returns: 筛选后的结果
    func filterHighQualityResults(
        _ results: [ItemInfo],
        minConfidence: Double = ConfidenceThresholds.acceptable
    ) -> [ItemInfo] {
        return results.filter { result in
            let validation = validateRecognitionResult(result)
            return result.confidence >= minConfidence && validation.isValid
        }.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - 私有方法
    
    /// 确定置信度等级
    private func determineConfidenceLevel(_ confidence: Double) -> ConfidenceLevel {
        if confidence >= ConfidenceThresholds.excellent {
            return .excellent
        } else if confidence >= ConfidenceThresholds.good {
            return .good
        } else if confidence >= ConfidenceThresholds.acceptable {
            return .acceptable
        } else if confidence >= ConfidenceThresholds.poor {
            return .poor
        } else {
            return .unacceptable
        }
    }
    
    /// 分析图片质量
    private func analyzeImageQuality(_ imageData: Data) -> ImageQualityMetrics {
        let sizeKB = Double(imageData.count) / 1024.0
        
        // 基于文件大小估算质量（简化实现）
        let qualityScore: Double
        if sizeKB < 20 {
            qualityScore = 0.3 // 文件太小，可能质量较差
        } else if sizeKB < 100 {
            qualityScore = 0.6 // 中等质量
        } else if sizeKB < 500 {
            qualityScore = 0.8 // 较好质量
        } else {
            qualityScore = 0.9 // 高质量
        }
        
        return ImageQualityMetrics(
            fileSize: sizeKB,
            qualityScore: qualityScore,
            estimatedResolution: sizeKB > 100 ? "高" : "低",
            hasMultipleObjects: sizeKB > 200
        )
    }
    
    /// 图片质量指标
    private struct ImageQualityMetrics {
        let fileSize: Double
        let qualityScore: Double
        let estimatedResolution: String
        let hasMultipleObjects: Bool
    }
    
    /// 检测质量问题
    private func detectQualityIssues(
        result: ItemInfo,
        imageQuality: ImageQualityMetrics,
        strategies: [PhotoRecognitionStrategy]
    ) -> [QualityIssue] {
        var issues: [QualityIssue] = []
        
        // 检查置信度
        if result.confidence < ConfidenceThresholds.acceptable {
            issues.append(.lowConfidence)
        }
        
        // 检查图片质量
        if imageQuality.qualityScore < 0.5 {
            issues.append(.poorImageQuality)
        }
        
        // 检查多物品问题
        if imageQuality.hasMultipleObjects {
            issues.append(.multipleObjects)
        }
        
        // 检查特征充分性
        if result.confidence < ConfidenceThresholds.poor && imageQuality.qualityScore < 0.6 {
            issues.append(.insufficientFeatures)
        }
        
        // 检查类别模糊性
        if result.category == .other || result.confidence < ConfidenceThresholds.good {
            issues.append(.ambiguousCategory)
        }
        
        // 检查重量体积可靠性
        let validation = validateRecognitionResult(result)
        if !validation.isValid {
            issues.append(.unreliableWeightVolume)
        }
        
        return issues
    }
    
    /// 生成改进建议
    private func generateImprovementSuggestions(
        issues: [QualityIssue],
        confidenceLevel: ConfidenceLevel,
        imageQuality: ImageQualityMetrics
    ) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        for issue in issues {
            switch issue {
            case .lowConfidence:
                suggestions.append(ImprovementSuggestion(
                    type: .retakePhoto,
                    title: "重新拍摄",
                    description: "尝试在更好的光线条件下重新拍摄物品",
                    priority: 4,
                    actionable: true
                ))
                
            case .poorImageQuality:
                suggestions.append(ImprovementSuggestion(
                    type: .betterLighting,
                    title: "改善光线",
                    description: "在明亮的环境中拍摄，避免阴影和反光",
                    priority: 5,
                    actionable: true
                ))
                
            case .multipleObjects:
                suggestions.append(ImprovementSuggestion(
                    type: .isolateObject,
                    title: "单独拍摄",
                    description: "将目标物品单独放置，避免其他物品干扰",
                    priority: 4,
                    actionable: true
                ))
                
            case .insufficientFeatures:
                suggestions.append(ImprovementSuggestion(
                    type: .improveAngle,
                    title: "调整角度",
                    description: "从不同角度拍摄，展示物品的关键特征",
                    priority: 3,
                    actionable: true
                ))
                
            case .ambiguousCategory:
                suggestions.append(ImprovementSuggestion(
                    type: .addHint,
                    title: "添加提示",
                    description: "在识别时提供物品的类型或用途提示",
                    priority: 3,
                    actionable: true
                ))
                
            case .unreliableWeightVolume:
                suggestions.append(ImprovementSuggestion(
                    type: .manualInput,
                    title: "手动输入",
                    description: "考虑手动输入准确的重量和尺寸信息",
                    priority: 2,
                    actionable: true
                ))
                
            case .inconsistentResults:
                suggestions.append(ImprovementSuggestion(
                    type: .useAlternativeMethod,
                    title: "尝试其他方法",
                    description: "使用不同的识别策略或手动识别",
                    priority: 3,
                    actionable: true
                ))
            }
        }
        
        // 根据置信度等级添加通用建议
        if confidenceLevel == .unacceptable {
            suggestions.append(ImprovementSuggestion(
                type: .manualInput,
                title: "手动识别",
                description: "识别结果不可靠，建议手动输入物品信息",
                priority: 5,
                actionable: true
            ))
        }
        
        return suggestions.sorted { $0.priority > $1.priority }
    }
    
    /// 计算总体评分
    private func calculateOverallScore(
        confidence: Double,
        imageQuality: ImageQualityMetrics,
        issues: [QualityIssue]
    ) -> Double {
        var score = confidence * 0.6 // 置信度占60%权重
        score += imageQuality.qualityScore * 0.3 // 图片质量占30%权重
        
        // 根据问题数量调整评分
        let issuesPenalty = Double(issues.count) * 0.1
        score -= issuesPenalty
        
        return max(0.0, min(1.0, score))
    }
    
    /// 判断是否需要重试
    private func determineShouldRetry(
        confidenceLevel: ConfidenceLevel,
        issues: [QualityIssue]
    ) -> Bool {
        // 置信度过低时建议重试
        if confidenceLevel == .unacceptable || confidenceLevel == .poor {
            return true
        }
        
        // 存在严重质量问题时建议重试
        let seriousIssues: [QualityIssue] = [.poorImageQuality, .multipleObjects, .insufficientFeatures]
        return issues.contains { seriousIssues.contains($0) }
    }
    
    /// 推荐替代策略
    private func recommendAlternativeStrategies(
        issues: [QualityIssue],
        usedStrategies: [PhotoRecognitionStrategy]
    ) -> [PhotoRecognitionStrategy] {
        var recommendations: [PhotoRecognitionStrategy] = []
        let allStrategies: [PhotoRecognitionStrategy] = [.aiVision, .textExtraction, .colorAnalysis, .shapeAnalysis]
        let unusedStrategies = allStrategies.filter { !usedStrategies.contains($0) }
        
        for issue in issues {
            switch issue {
            case .insufficientFeatures:
                if !usedStrategies.contains(.textExtraction) {
                    recommendations.append(.textExtraction)
                }
                if !usedStrategies.contains(.colorAnalysis) {
                    recommendations.append(.colorAnalysis)
                }
                
            case .ambiguousCategory:
                if !usedStrategies.contains(.shapeAnalysis) {
                    recommendations.append(.shapeAnalysis)
                }
                
            case .poorImageQuality:
                // 图片质量差时，文字识别可能更有效
                if !usedStrategies.contains(.textExtraction) {
                    recommendations.append(.textExtraction)
                }
                
            default:
                break
            }
        }
        
        // 如果没有特定推荐，返回未使用的策略
        if recommendations.isEmpty {
            recommendations = Array(unusedStrategies.prefix(2))
        }
        
        return Array(Set(recommendations)) // 去重
    }
    
    /// 验证类别一致性
    private func validateCategoryConsistency(_ result: ItemInfo) -> [String] {
        var issues: [String] = []
        
        // 根据类别检查重量合理性
        switch result.category {
        case .electronics:
            if result.weight < 10 || result.weight > 5000 {
                issues.append("电子产品重量异常")
            }
            
        case .clothing:
            if result.weight < 50 || result.weight > 2000 {
                issues.append("衣物重量异常")
            }
            
        case .shoes:
            if result.weight < 200 || result.weight > 1500 {
                issues.append("鞋类重量异常")
            }
            
        case .books:
            if result.weight < 100 || result.weight > 3000 {
                issues.append("书籍重量异常")
            }
            
        case .toiletries:
            if result.weight < 10 || result.weight > 1000 {
                issues.append("洗漱用品重量异常")
            }
            
        default:
            break
        }
        
        return issues
    }
}