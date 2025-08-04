import Foundation
import UIKit

/// 识别结果验证器
/// 负责验证和筛选照片识别结果，确保结果的准确性和可靠性
class RecognitionResultValidator {
    
    // MARK: - 单例
    
    static let shared = RecognitionResultValidator()
    
    private init() {}
    
    // MARK: - 验证结果结构
    
    /// 验证结果
    struct ValidationResult {
        let isValid: Bool
        let confidence: Double
        let adjustedResult: ItemInfo?
        let validationIssues: [ValidationIssue]
        let recommendations: [ValidationRecommendation]
        let qualityScore: Double
    }
    
    /// 验证问题
    struct ValidationIssue {
        let type: IssueType
        let severity: IssueSeverity
        let description: String
        let affectedField: String?
        
        enum IssueType: String {
            case dataInconsistency = "dataInconsistency"
            case unreasonableValue = "unreasonableValue"
            case categoryMismatch = "categoryMismatch"
            case confidenceTooLow = "confidenceTooLow"
            case missingInformation = "missingInformation"
            case physicallyImpossible = "physicallyImpossible"
        }
        
        enum IssueSeverity: String {
            case critical = "critical"
            case major = "major"
            case minor = "minor"
            case warning = "warning"
        }
    }
    
    /// 验证建议
    struct ValidationRecommendation {
        let action: RecommendedAction
        let description: String
        let priority: Int // 1-5, 5最高
        
        enum RecommendedAction: String {
            case adjustValue = "adjustValue"
            case recategorize = "recategorize"
            case requestMoreInfo = "requestMoreInfo"
            case useAlternative = "useAlternative"
            case manualVerification = "manualVerification"
            case retryRecognition = "retryRecognition"
        }
    }
    
    // MARK: - 主要验证方法
    
    /// 验证单个识别结果
    /// - Parameters:
    ///   - result: 识别结果
    ///   - imageData: 原始图片数据（可选）
    ///   - context: 验证上下文（可选）
    /// - Returns: 验证结果
    func validateResult(
        _ result: ItemInfo,
        imageData: Data? = nil,
        context: ValidationContext? = nil
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []
        var recommendations: [ValidationRecommendation] = []
        var adjustedResult: ItemInfo? = nil
        
        // 1. 基础数据验证
        let basicIssues = validateBasicData(result)
        issues.append(contentsOf: basicIssues)
        
        // 2. 物理合理性验证
        let physicalIssues = validatePhysicalReasonableness(result)
        issues.append(contentsOf: physicalIssues)
        
        // 3. 类别一致性验证
        let categoryIssues = validateCategoryConsistency(result)
        issues.append(contentsOf: categoryIssues)
        
        // 4. 置信度验证
        let confidenceIssues = validateConfidence(result)
        issues.append(contentsOf: confidenceIssues)
        
        // 5. 上下文验证（如果提供）
        if let context = context {
            let contextIssues = validateContext(result, context: context)
            issues.append(contentsOf: contextIssues)
        }
        
        // 6. 生成修正建议
        recommendations = generateRecommendations(for: issues, result: result)
        
        // 7. 尝试自动修正
        adjustedResult = attemptAutoCorrection(result, issues: issues)
        
        // 8. 计算质量评分
        let qualityScore = calculateQualityScore(result, issues: issues)
        
        // 9. 调整置信度
        let adjustedConfidence = adjustConfidence(result.confidence, issues: issues, qualityScore: qualityScore)
        
        let isValid = issues.filter { $0.severity == .critical || $0.severity == .major }.isEmpty
        
        return ValidationResult(
            isValid: isValid,
            confidence: adjustedConfidence,
            adjustedResult: adjustedResult,
            validationIssues: issues,
            recommendations: recommendations,
            qualityScore: qualityScore
        )
    }
    
    /// 批量验证识别结果
    /// - Parameters:
    ///   - results: 识别结果列表
    ///   - context: 验证上下文
    /// - Returns: 验证结果列表
    func validateResults(
        _ results: [ItemInfo],
        context: ValidationContext? = nil
    ) -> [ValidationResult] {
        return results.map { result in
            validateResult(result, context: context)
        }
    }
    
    /// 筛选有效结果
    /// - Parameters:
    ///   - results: 识别结果列表
    ///   - minConfidence: 最小置信度要求
    ///   - allowMinorIssues: 是否允许轻微问题
    /// - Returns: 筛选后的有效结果
    func filterValidResults(
        _ results: [ItemInfo],
        minConfidence: Double = 0.7,
        allowMinorIssues: Bool = true
    ) -> [ItemInfo] {
        let validationResults = validateResults(results)
        
        return validationResults.compactMap { validation in
            guard validation.confidence >= minConfidence else { return nil }
            
            let hasCriticalIssues = validation.validationIssues.contains { 
                $0.severity == .critical || $0.severity == .major 
            }
            
            if hasCriticalIssues && !allowMinorIssues {
                return nil
            }
            
            // 返回修正后的结果或原始结果
            if let adjustedResult = validation.adjustedResult {
                return adjustedResult
            }
            
            // 检查是否有物理上不可能的问题
            let hasPhysicallyImpossibleIssue = validation.validationIssues.contains { $0.type == .physicallyImpossible }
            if hasPhysicallyImpossibleIssue {
                return nil
            }
            
            // 返回原始结果
            return results.first { result in
                // 这里需要一个合适的比较方式，假设我们比较名称
                result.name == validation.adjustedResult?.name
            }
        }.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - 验证上下文
    
    /// 验证上下文
    struct ValidationContext {
        let expectedCategory: ItemCategory?
        let expectedWeightRange: ClosedRange<Double>?
        let expectedVolumeRange: ClosedRange<Double>?
        let travelPurpose: String?
        let userHint: String?
        let previousResults: [ItemInfo]?
    }
    
    // MARK: - 私有验证方法
    
    /// 验证基础数据
    private func validateBasicData(_ result: ItemInfo) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // 检查名称
        if result.name.isEmpty || result.name.count < 2 {
            issues.append(ValidationIssue(
                type: .missingInformation,
                severity: .major,
                description: "物品名称过短或为空",
                affectedField: "name"
            ))
        }
        
        // 检查重量
        if result.weight <= 0 {
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .critical,
                description: "重量不能为零或负数",
                affectedField: "weight"
            ))
        } else if result.weight > 100000 { // 100kg
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .major,
                description: "重量过大，超出常理",
                affectedField: "weight"
            ))
        }
        
        // 检查体积
        if result.volume <= 0 {
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .critical,
                description: "体积不能为零或负数",
                affectedField: "volume"
            ))
        } else if result.volume > 1000000 { // 1000L
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .major,
                description: "体积过大，超出常理",
                affectedField: "volume"
            ))
        }
        
        // 检查置信度
        if result.confidence < 0 || result.confidence > 1 {
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .critical,
                description: "置信度超出有效范围 (0-1)",
                affectedField: "confidence"
            ))
        }
        
        return issues
    }
    
    /// 验证物理合理性
    private func validatePhysicalReasonableness(_ result: ItemInfo) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // 检查尺寸与体积的一致性
        if let dimensions = result.dimensions {
            let calculatedVolume = dimensions.volume
            let volumeDifference = abs(calculatedVolume - result.volume) / result.volume
            
            if volumeDifference > 0.8 { // 差异超过80%
                issues.append(ValidationIssue(
                    type: .dataInconsistency,
                    severity: .major,
                    description: "尺寸计算的体积与给定体积差异过大",
                    affectedField: "dimensions"
                ))
            }
            
            // 检查尺寸合理性
            if dimensions.length <= 0 || dimensions.width <= 0 || dimensions.height <= 0 {
                issues.append(ValidationIssue(
                    type: .unreasonableValue,
                    severity: .critical,
                    description: "尺寸不能为零或负数",
                    affectedField: "dimensions"
                ))
            }
            
            // 检查极端尺寸
            let maxDimension = max(dimensions.length, dimensions.width, dimensions.height)
            if maxDimension > 300 { // 3米
                issues.append(ValidationIssue(
                    type: .unreasonableValue,
                    severity: .major,
                    description: "尺寸过大，不适合旅行携带",
                    affectedField: "dimensions"
                ))
            }
        }
        
        // 检查密度合理性
        let density = result.weight / result.volume // g/cm³
        if density > 20 { // 密度超过20g/cm³（比铅还重）
            issues.append(ValidationIssue(
                type: .physicallyImpossible,
                severity: .major,
                description: "物品密度过高，可能不符合物理常识",
                affectedField: "weight"
            ))
        } else if density < 0.01 { // 密度低于0.01g/cm³（比空气还轻）
            issues.append(ValidationIssue(
                type: .physicallyImpossible,
                severity: .major,
                description: "物品密度过低，可能不符合物理常识",
                affectedField: "weight"
            ))
        }
        
        return issues
    }
    
    /// 验证类别一致性
    private func validateCategoryConsistency(_ result: ItemInfo) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // 定义各类别的典型重量范围（克）
        let categoryWeightRanges: [ItemCategory: ClosedRange<Double>] = [
            .electronics: 10...5000,
            .clothing: 50...2000,
            .shoes: 200...1500,
            .books: 100...3000,
            .toiletries: 10...1000,
            .accessories: 5...1000,
            .documents: 1...500,
            .medicine: 1...500,
            .food: 10...2000,
            .sports: 50...10000,
            .beauty: 5...500
        ]
        
        if let expectedRange = categoryWeightRanges[result.category] {
            if !expectedRange.contains(result.weight) {
                let severity: ValidationIssue.IssueSeverity = 
                    result.weight < expectedRange.lowerBound * 0.1 || result.weight > expectedRange.upperBound * 10 
                    ? .major : .minor
                
                issues.append(ValidationIssue(
                    type: .categoryMismatch,
                    severity: severity,
                    description: "\(result.category.displayName)类别的重量异常",
                    affectedField: "category"
                ))
            }
        }
        
        // 检查名称与类别的匹配性
        let categoryKeywords: [ItemCategory: [String]] = [
            .electronics: ["手机", "电脑", "充电", "耳机", "相机", "平板"],
            .clothing: ["衣", "裤", "裙", "衫", "外套", "内衣"],
            .shoes: ["鞋", "靴", "拖鞋", "运动鞋"],
            .books: ["书", "本", "笔记", "文具"],
            .toiletries: ["牙", "洗", "沐浴", "洗发", "护肤"],
            .accessories: ["包", "表", "眼镜", "首饰", "帽"],
            .medicine: ["药", "维生素", "保健"],
            .food: ["食", "零食", "饮料", "茶"],
            .beauty: ["化妆", "口红", "粉底", "面膜"]
        ]
        
        if let keywords = categoryKeywords[result.category] {
            let nameContainsKeyword = keywords.contains { keyword in
                result.name.lowercased().contains(keyword.lowercased())
            }
            
            if !nameContainsKeyword && result.confidence > 0.8 {
                issues.append(ValidationIssue(
                    type: .categoryMismatch,
                    severity: .minor,
                    description: "物品名称与类别不太匹配",
                    affectedField: "category"
                ))
            }
        }
        
        return issues
    }
    
    /// 验证置信度
    private func validateConfidence(_ result: ItemInfo) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if result.confidence < 0.3 {
            issues.append(ValidationIssue(
                type: .confidenceTooLow,
                severity: .major,
                description: "识别置信度过低，结果可能不可靠",
                affectedField: "confidence"
            ))
        } else if result.confidence < 0.5 {
            issues.append(ValidationIssue(
                type: .confidenceTooLow,
                severity: .minor,
                description: "识别置信度较低，建议谨慎使用",
                affectedField: "confidence"
            ))
        }
        
        return issues
    }
    
    /// 验证上下文
    private func validateContext(_ result: ItemInfo, context: ValidationContext) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // 检查期望类别
        if let expectedCategory = context.expectedCategory,
           expectedCategory != result.category {
            issues.append(ValidationIssue(
                type: .categoryMismatch,
                severity: .minor,
                description: "识别类别与期望类别不符",
                affectedField: "category"
            ))
        }
        
        // 检查期望重量范围
        if let expectedWeightRange = context.expectedWeightRange,
           !expectedWeightRange.contains(result.weight) {
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .minor,
                description: "重量超出期望范围",
                affectedField: "weight"
            ))
        }
        
        // 检查期望体积范围
        if let expectedVolumeRange = context.expectedVolumeRange,
           !expectedVolumeRange.contains(result.volume) {
            issues.append(ValidationIssue(
                type: .unreasonableValue,
                severity: .minor,
                description: "体积超出期望范围",
                affectedField: "volume"
            ))
        }
        
        return issues
    }
    
    /// 生成修正建议
    private func generateRecommendations(
        for issues: [ValidationIssue],
        result: ItemInfo
    ) -> [ValidationRecommendation] {
        var recommendations: [ValidationRecommendation] = []
        
        for issue in issues {
            switch issue.type {
            case .unreasonableValue:
                recommendations.append(ValidationRecommendation(
                    action: .adjustValue,
                    description: "调整\(issue.affectedField ?? "相关")数值到合理范围",
                    priority: issue.severity == .critical ? 5 : 3
                ))
                
            case .categoryMismatch:
                recommendations.append(ValidationRecommendation(
                    action: .recategorize,
                    description: "重新评估物品类别",
                    priority: 3
                ))
                
            case .confidenceTooLow:
                recommendations.append(ValidationRecommendation(
                    action: .retryRecognition,
                    description: "尝试重新识别或使用其他识别方法",
                    priority: 4
                ))
                
            case .dataInconsistency:
                recommendations.append(ValidationRecommendation(
                    action: .manualVerification,
                    description: "手动验证和修正数据不一致问题",
                    priority: 4
                ))
                
            case .missingInformation:
                recommendations.append(ValidationRecommendation(
                    action: .requestMoreInfo,
                    description: "补充缺失的物品信息",
                    priority: 3
                ))
                
            case .physicallyImpossible:
                recommendations.append(ValidationRecommendation(
                    action: .useAlternative,
                    description: "使用替代识别方法或手动输入",
                    priority: 5
                ))
            }
        }
        
        return recommendations.sorted { $0.priority > $1.priority }
    }
    
    /// 尝试自动修正
    private func attemptAutoCorrection(_ result: ItemInfo, issues: [ValidationIssue]) -> ItemInfo? {
        var correctedResult = result
        var hasCorrected = false
        
        for issue in issues {
            switch issue.type {
            case .unreasonableValue:
                if issue.affectedField == "weight" {
                    // 修正异常重量
                    if result.weight <= 0 {
                        correctedResult = ItemInfo(
                            name: correctedResult.name,
                            category: correctedResult.category,
                            weight: 100.0, // 默认100g
                            volume: correctedResult.volume,
                            dimensions: correctedResult.dimensions,
                            confidence: correctedResult.confidence * 0.8,
                            alternatives: correctedResult.alternatives,
                            source: correctedResult.source + " (重量已修正)"
                        )
                        hasCorrected = true
                    } else if result.weight > 50000 {
                        correctedResult = ItemInfo(
                            name: correctedResult.name,
                            category: correctedResult.category,
                            weight: 1000.0, // 限制为1kg
                            volume: correctedResult.volume,
                            dimensions: correctedResult.dimensions,
                            confidence: correctedResult.confidence * 0.7,
                            alternatives: correctedResult.alternatives,
                            source: correctedResult.source + " (重量已修正)"
                        )
                        hasCorrected = true
                    }
                }
                
                if issue.affectedField == "volume" {
                    // 修正异常体积
                    if result.volume <= 0 {
                        correctedResult = ItemInfo(
                            name: correctedResult.name,
                            category: correctedResult.category,
                            weight: correctedResult.weight,
                            volume: 100.0, // 默认100cm³
                            dimensions: correctedResult.dimensions,
                            confidence: correctedResult.confidence * 0.8,
                            alternatives: correctedResult.alternatives,
                            source: correctedResult.source + " (体积已修正)"
                        )
                        hasCorrected = true
                    }
                }
                
            case .dataInconsistency:
                // 修正尺寸与体积不一致
                if let dimensions = result.dimensions {
                    let calculatedVolume = dimensions.volume
                    if abs(calculatedVolume - result.volume) / result.volume > 0.5 {
                        correctedResult = ItemInfo(
                            name: correctedResult.name,
                            category: correctedResult.category,
                            weight: correctedResult.weight,
                            volume: calculatedVolume,
                            dimensions: correctedResult.dimensions,
                            confidence: correctedResult.confidence * 0.9,
                            alternatives: correctedResult.alternatives,
                            source: correctedResult.source + " (体积已修正)"
                        )
                        hasCorrected = true
                    }
                }
                
            default:
                break
            }
        }
        
        return hasCorrected ? correctedResult : nil
    }
    
    /// 计算质量评分
    private func calculateQualityScore(_ result: ItemInfo, issues: [ValidationIssue]) -> Double {
        var score = result.confidence
        
        // 根据问题严重程度扣分
        for issue in issues {
            switch issue.severity {
            case .critical:
                score -= 0.3
            case .major:
                score -= 0.2
            case .minor:
                score -= 0.1
            case .warning:
                score -= 0.05
            }
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// 调整置信度
    private func adjustConfidence(
        _ originalConfidence: Double,
        issues: [ValidationIssue],
        qualityScore: Double
    ) -> Double {
        var adjustedConfidence = originalConfidence
        
        // 根据质量评分调整
        adjustedConfidence = (adjustedConfidence + qualityScore) / 2.0
        
        // 如果有严重问题，大幅降低置信度
        let hasCriticalIssues = issues.contains { $0.severity == .critical }
        if hasCriticalIssues {
            adjustedConfidence *= 0.5
        }
        
        let hasMajorIssues = issues.contains { $0.severity == .major }
        if hasMajorIssues {
            adjustedConfidence *= 0.8
        }
        
        return max(0.0, min(1.0, adjustedConfidence))
    }
}