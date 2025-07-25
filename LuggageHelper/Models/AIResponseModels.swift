import Foundation

// MARK: - AI API 响应解析模型

/// 物品信息响应模型
struct ItemInfoResponse: Codable {
    let name: String
    let category: String
    let weight: Double
    let volume: Double
    let dimensions: DimensionsResponse?
    let confidence: Double
    let alternatives: [AlternativeItemResponse]?
    
    /// 转换为 ItemInfo
    func toItemInfo() -> ItemInfo {
        let itemCategory = ItemCategory(rawValue: category) ?? .other
        let itemDimensions = dimensions?.toDimensions()
        let itemAlternatives = alternatives?.compactMap { $0.toItemInfo() } ?? []
        
        return ItemInfo(
            name: name,
            category: itemCategory,
            weight: weight,
            volume: volume,
            dimensions: itemDimensions,
            confidence: confidence,
            alternatives: itemAlternatives,
            source: "AI识别"
        )
    }
}

/// 尺寸响应模型
struct DimensionsResponse: Codable {
    let length: Double
    let width: Double
    let height: Double
    
    /// 转换为 Dimensions
    func toDimensions() -> Dimensions {
        return Dimensions(length: length, width: width, height: height)
    }
}

/// 替代品响应模型
struct AlternativeItemResponse: Codable {
    let name: String
    let weight: Double
    let volume: Double
    let reason: String?
    
    /// 转换为 ItemInfo
    func toItemInfo() -> ItemInfo {
        return ItemInfo(
            name: name,
            category: .other,
            weight: weight,
            volume: volume,
            confidence: 0.8,
            source: "AI建议"
        )
    }
}

/// 旅行建议响应模型
struct TravelSuggestionResponse: Codable {
    let destination: String
    let duration: Int
    let season: String
    let activities: [String]
    let suggestedItems: [SuggestedItemResponse]
    let categories: [String]
    let tips: [String]?
    let warnings: [String]?
    
    /// 转换为 TravelSuggestion
    func toTravelSuggestion() -> TravelSuggestion {
        let itemCategories = categories.compactMap { ItemCategory(rawValue: $0) }
        let items = suggestedItems.map { $0.toSuggestedItem() }
        
        return TravelSuggestion(
            destination: destination,
            duration: duration,
            season: season,
            activities: activities,
            suggestedItems: items,
            categories: itemCategories,
            tips: tips ?? [],
            warnings: warnings ?? []
        )
    }
}

/// 建议物品响应模型
struct SuggestedItemResponse: Codable {
    let name: String
    let category: String
    let importance: String
    let reason: String
    let quantity: Int
    let estimatedWeight: Double?
    let estimatedVolume: Double?
    
    /// 转换为 SuggestedItem
    func toSuggestedItem() -> SuggestedItem {
        let itemCategory = ItemCategory(rawValue: category) ?? .other
        let importanceLevel = ImportanceLevel(rawValue: importance) ?? .optional
        
        return SuggestedItem(
            name: name,
            category: itemCategory,
            importance: importanceLevel,
            reason: reason,
            quantity: quantity,
            estimatedWeight: estimatedWeight,
            estimatedVolume: estimatedVolume
        )
    }
}

/// 装箱计划响应模型
struct PackingPlanResponse: Codable {
    let items: [PackingItemResponse]
    let totalWeight: Double
    let totalVolume: Double
    let efficiency: Double
    let warnings: [PackingWarningResponse]
    let suggestions: [String]
    
    /// 转换为 PackingPlan
    func toPackingPlan(luggageId: UUID, itemIdMapping: [String: UUID] = [:]) -> PackingPlan {
        let packingItems = items.compactMap { item in
            item.toPackingItem(itemIdMapping: itemIdMapping)
        }
        
        let packingWarnings = warnings.map { $0.toPackingWarning() }
        
        return PackingPlan(
            luggageId: luggageId,
            items: packingItems,
            totalWeight: totalWeight,
            totalVolume: totalVolume,
            efficiency: efficiency,
            warnings: packingWarnings,
            suggestions: suggestions
        )
    }
}

/// 装箱物品响应模型
struct PackingItemResponse: Codable {
    let itemId: String
    let position: String
    let priority: Int
    let reason: String
    
    /// 转换为 PackingItem
    func toPackingItem(itemIdMapping: [String: UUID] = [:]) -> PackingItem? {
        // 尝试从映射中获取 UUID，如果没有则尝试解析字符串
        let uuid: UUID
        if let mappedId = itemIdMapping[itemId] {
            uuid = mappedId
        } else if let parsedId = UUID(uuidString: itemId) {
            uuid = parsedId
        } else {
            // 如果无法解析，返回 nil
            return nil
        }
        
        let packingPosition = PackingPosition(rawValue: position) ?? .middle
        
        return PackingItem(
            itemId: uuid,
            position: packingPosition,
            priority: priority,
            reason: reason
        )
    }
}

/// 装箱警告响应模型
struct PackingWarningResponse: Codable {
    let type: String
    let message: String
    let severity: String
    
    /// 转换为 PackingWarning
    func toPackingWarning() -> PackingWarning {
        let warningType = WarningType(rawValue: type) ?? .overweight
        let warningSeverity = WarningSeverity(rawValue: severity) ?? .medium
        
        return PackingWarning(
            type: warningType,
            message: message,
            severity: warningSeverity
        )
    }
}

/// 重量预测响应模型
struct WeightPredictionResponse: Codable {
    let totalWeight: Double
    let breakdown: [CategoryWeightResponse]
    let warnings: [String]
    let suggestions: [String]
    let confidence: Double
    
    /// 转换为 WeightPrediction
    func toWeightPrediction() -> WeightPrediction {
        let categoryWeights = breakdown.map { $0.toCategoryWeight() }
        
        return WeightPrediction(
            totalWeight: totalWeight,
            breakdown: categoryWeights,
            warnings: warnings,
            suggestions: suggestions,
            confidence: confidence
        )
    }
}

/// 类别重量响应模型
struct CategoryWeightResponse: Codable {
    let category: String
    let weight: Double
    let percentage: Double
    
    /// 转换为 CategoryWeight
    func toCategoryWeight() -> WeightPrediction.CategoryWeight {
        let itemCategory = ItemCategory(rawValue: category) ?? .other
        
        return WeightPrediction.CategoryWeight(
            category: itemCategory,
            weight: weight,
            percentage: percentage
        )
    }
}

/// 遗漏物品警告响应模型
struct MissingItemAlertResponse: Codable {
    let itemName: String
    let category: String
    let importance: String
    let reason: String
    let suggestion: String?
    
    /// 转换为 MissingItemAlert
    func toMissingItemAlert() -> MissingItemAlert {
        let itemCategory = ItemCategory(rawValue: category) ?? .other
        let importanceLevel = ImportanceLevel(rawValue: importance) ?? .optional
        
        return MissingItemAlert(
            itemName: itemName,
            category: itemCategory,
            importance: importanceLevel,
            reason: reason,
            suggestion: suggestion
        )
    }
}

/// 航空公司政策响应模型
struct AirlinePolicyResponse: Codable {
    let airline: String
    let carryOnWeight: Double
    let carryOnDimensions: DimensionsResponse
    let checkedWeight: Double
    let checkedDimensions: DimensionsResponse
    let restrictions: [String]
    let lastUpdated: String? // ISO 8601 日期字符串
    let source: String?
    
    /// 转换为 AirlineLuggagePolicy
    func toAirlineLuggagePolicy() -> AirlineLuggagePolicy {
        let dateFormatter = ISO8601DateFormatter()
        let updatedDate = lastUpdated.flatMap { dateFormatter.date(from: $0) } ?? Date()
        
        return AirlineLuggagePolicy(
            airline: airline,
            carryOnWeight: carryOnWeight,
            carryOnDimensions: carryOnDimensions.toDimensions(),
            checkedWeight: checkedWeight,
            checkedDimensions: checkedDimensions.toDimensions(),
            restrictions: restrictions,
            lastUpdated: updatedDate,
            source: source ?? "AI查询"
        )
    }
}

/// 个性化建议响应模型
struct PersonalizedSuggestionsResponse: Codable {
    let suggestions: [SuggestedItemResponse]
    let reasoning: String?
    let confidence: Double?
    
    /// 转换为 SuggestedItem 数组
    func toSuggestedItems() -> [SuggestedItem] {
        return suggestions.map { $0.toSuggestedItem() }
    }
}

/// 政策检查结果响应模型
struct PolicyCheckResultResponse: Codable {
    let overallCompliance: Bool
    let violations: [PolicyViolationResponse]
    let warnings: [PolicyWarningResponse]
    let recommendations: [String]
    let estimatedFees: EstimatedFeesResponse?
    
    /// 转换为 PolicyCheckResult
    func toPolicyCheckResult() -> PolicyCheckResult {
        let policyViolations = violations.map { $0.toPolicyViolation() }
        let policyWarnings = warnings.map { $0.toPolicyWarning() }
        let fees = estimatedFees?.toEstimatedFees()
        
        return PolicyCheckResult(
            overallCompliance: overallCompliance,
            violations: policyViolations,
            warnings: policyWarnings,
            recommendations: recommendations,
            estimatedFees: fees
        )
    }
}

/// 政策违规响应模型
struct PolicyViolationResponse: Codable {
    let itemName: String
    let violationType: String
    let description: String
    let severity: String
    let suggestion: String
    
    /// 转换为 PolicyViolation
    func toPolicyViolation() -> PolicyViolation {
        let type = ViolationType(rawValue: violationType) ?? .prohibited
        let sev = ViolationSeverity(rawValue: severity) ?? .medium
        
        return PolicyViolation(
            itemName: itemName,
            violationType: type,
            description: description,
            severity: sev,
            suggestion: suggestion
        )
    }
}

/// 政策警告响应模型
struct PolicyWarningResponse: Codable {
    let itemName: String
    let warningType: String
    let message: String
    let suggestion: String
    
    /// 转换为 PolicyWarning
    func toPolicyWarning() -> PolicyWarning {
        let type = WarningType(rawValue: warningType) ?? .attention
        
        return PolicyWarning(
            itemName: itemName,
            warningType: type,
            message: message,
            suggestion: suggestion
        )
    }
}

/// 预估费用响应模型
struct EstimatedFeesResponse: Codable {
    let overweightFee: Double
    let oversizeFee: Double
    let currency: String
    
    /// 转换为 EstimatedFees
    func toEstimatedFees() -> EstimatedFees {
        return EstimatedFees(
            overweightFee: overweightFee,
            oversizeFee: oversizeFee,
            currency: currency
        )
    }
}

// MARK: - 替代品建议响应模型

/// 替代品建议响应模型
struct AlternativeItemsResponse: Codable {
    let originalItem: OriginalItemResponse
    let alternatives: [AlternativeItemDetailResponse]
    let recommendations: [RecommendationResponse]?
    
    struct OriginalItemResponse: Codable {
        let name: String
        let category: String
        let weight: Double
        let volume: Double
    }
    
    struct RecommendationResponse: Codable {
        let scenario: String
        let bestAlternative: String
        let reason: String
    }
    
    /// 转换为 AlternativeItem 数组
    func toAlternativeItems() -> [AlternativeItem] {
        return alternatives.map { $0.toAlternativeItem() }
    }
}

/// 替代品详细信息响应模型
struct AlternativeItemDetailResponse: Codable {
    let name: String
    let category: String
    let weight: Double
    let volume: Double
    let dimensions: DimensionsResponse
    let advantages: [String]
    let disadvantages: [String]
    let suitability: Double
    let reason: String
    let estimatedPrice: Double?
    let availability: String?
    let compatibilityScore: Double
    let functionalityMatch: Double?
    let versatility: Double?
    
    /// 转换为 AlternativeItem
    func toAlternativeItem() -> AlternativeItem {
        return AlternativeItem(
            name: name,
            category: ItemCategory(rawValue: category) ?? .other,
            weight: weight,
            volume: volume,
            dimensions: dimensions.toDimensions(),
            advantages: advantages,
            disadvantages: disadvantages,
            suitability: suitability,
            reason: reason,
            estimatedPrice: estimatedPrice,
            availability: availability,
            compatibilityScore: compatibilityScore,
            functionalityMatch: functionalityMatch,
            versatility: versatility
        )
    }
}

/// 批量替代品建议响应模型
struct BatchAlternativeItemsResponse: Codable {
    let batchResults: [String: [AlternativeItemDetailResponse]]
    let globalRecommendations: [GlobalRecommendationResponse]?
    
    struct GlobalRecommendationResponse: Codable {
        let category: String
        let suggestion: String
        let potentialSavings: PotentialSavingsResponse
        
        struct PotentialSavingsResponse: Codable {
            let weight: Double
            let volume: Double
        }
    }
    
    /// 转换为批量替代品结果
    func toBatchAlternativeItems() -> [String: [AlternativeItem]] {
        var result: [String: [AlternativeItem]] = [:]
        
        for (itemName, alternatives) in batchResults {
            result[itemName] = alternatives.map { $0.toAlternativeItem() }
        }
        
        return result
    }
}

/// 功能性替代品响应模型
struct FunctionalAlternativesResponse: Codable {
    let functionality: String
    let alternatives: [AlternativeItemDetailResponse]
    let bestMatch: BestMatchResponse?
    
    struct BestMatchResponse: Codable {
        let name: String
        let reason: String
    }
    
    /// 转换为 AlternativeItem 数组
    func toFunctionalAlternatives() -> [AlternativeItem] {
        return alternatives.map { $0.toAlternativeItem() }
    }
}

/// 替代品约束条件响应模型
struct AlternativeConstraintsResponse: Codable {
    let maxWeight: Double?
    let maxVolume: Double?
    let maxBudget: Double?
    let requiredFeatures: [String]?
    let excludedBrands: [String]?
    let preferredBrands: [String]?
    
    /// 转换为 AlternativeConstraints
    func toAlternativeConstraints() -> AlternativeConstraints {
        return AlternativeConstraints(
            maxWeight: maxWeight,
            maxVolume: maxVolume,
            maxBudget: maxBudget,
            requiredFeatures: requiredFeatures,
            excludedBrands: excludedBrands,
            preferredBrands: preferredBrands
        )
    }
}

// MARK: - 通用响应包装器

/// API 响应包装器
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIErrorResponse?
    let timestamp: String
    let requestId: String?
}

/// API 错误响应
struct APIErrorResponse: Codable {
    let code: String
    let message: String
    let details: [String: String]?
}

// MARK: - 批量操作响应

/// 批量物品识别响应
struct BatchItemIdentificationResponse: Codable {
    let results: [ItemIdentificationResult]
    let totalProcessed: Int
    let successCount: Int
    let failureCount: Int
    
    struct ItemIdentificationResult: Codable {
        let originalName: String
        let success: Bool
        let result: ItemInfoResponse?
        let error: String?
        
        enum CodingKeys: String, CodingKey {
            case originalName, success, result, error
        }
    }
    
    /// 转换为 ItemInfo 数组
    func toItemInfoArray() -> [ItemInfo] {
        return results.compactMap { result in
            guard result.success, let itemResponse = result.result else {
                return nil
            }
            return itemResponse.toItemInfo()
        }
    }
}

/// 批量建议响应
struct BatchSuggestionsResponse: Codable {
    let travelSuggestions: [TravelSuggestionResponse]
    let personalizedSuggestions: [SuggestedItemResponse]
    let packingOptimizations: [PackingPlanResponse]
    let warnings: [String]
    
    enum CodingKeys: String, CodingKey {
        case travelSuggestions, personalizedSuggestions, packingOptimizations, warnings
    }
    
    /// 转换为各自的模型数组
    func convertToModels(luggageIds: [UUID] = []) -> (
        travelSuggestions: [TravelSuggestion],
        personalizedSuggestions: [SuggestedItem],
        packingOptimizations: [PackingPlan]
    ) {
        let travel = travelSuggestions.map { $0.toTravelSuggestion() }
        let personalized = personalizedSuggestions.map { $0.toSuggestedItem() }
        let packing = packingOptimizations.enumerated().map { index, response in
            let luggageId = index < luggageIds.count ? luggageIds[index] : UUID()
            return response.toPackingPlan(luggageId: luggageId)
        }
        
        return (travel, personalized, packing)
    }
}

// MARK: - 扩展方法

extension Array where Element == ItemInfoResponse {
    /// 批量转换为 ItemInfo
    func toItemInfoArray() -> [ItemInfo] {
        return self.map { $0.toItemInfo() }
    }
}

extension Array where Element == SuggestedItemResponse {
    /// 批量转换为 SuggestedItem
    func toSuggestedItemArray() -> [SuggestedItem] {
        return self.map { $0.toSuggestedItem() }
    }
}

extension Array where Element == MissingItemAlertResponse {
    /// 批量转换为 MissingItemAlert
    func toMissingItemAlertArray() -> [MissingItemAlert] {
        return self.map { $0.toMissingItemAlert() }
    }
}

// MARK: - JSON 解析辅助

/// JSON 解析器
struct AIResponseParser {
    
    /// 从 JSON 字符串解析物品信息
    static func parseItemInfo(from jsonString: String, originalName: String) throws -> ItemInfo {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        do {
            let response = try JSONDecoder().decode(ItemInfoResponse.self, from: data)
            return response.toItemInfo()
        } catch {
            // 如果解析失败，返回默认值
            return ItemInfo.defaultItem(name: originalName)
        }
    }
    
    /// 从 JSON 字符串解析旅行建议
    static func parseTravelSuggestion(from jsonString: String) throws -> TravelSuggestion {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(TravelSuggestionResponse.self, from: data)
        return response.toTravelSuggestion()
    }
    
    /// 从 JSON 字符串解析装箱计划
    static func parsePackingPlan(from jsonString: String, luggageId: UUID) throws -> PackingPlan {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(PackingPlanResponse.self, from: data)
        return response.toPackingPlan(luggageId: luggageId)
    }
    
    /// 从 JSON 字符串解析重量预测
    static func parseWeightPrediction(from jsonString: String) throws -> WeightPrediction {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(WeightPredictionResponse.self, from: data)
        return response.toWeightPrediction()
    }
    
    /// 从 JSON 字符串解析遗漏物品警告
    static func parseMissingItemAlerts(from jsonString: String) throws -> [MissingItemAlert] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let responses = try JSONDecoder().decode([MissingItemAlertResponse].self, from: data)
        return responses.toMissingItemAlertArray()
    }
    
    /// 从 JSON 字符串解析建议物品数组
    static func parseSuggestedItems(from jsonString: String) throws -> [SuggestedItem] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let responses = try JSONDecoder().decode([SuggestedItemResponse].self, from: data)
        return responses.toSuggestedItemArray()
    }
    
    /// 从 JSON 字符串解析物品信息数组
    static func parseItemInfoArray(from jsonString: String) throws -> [ItemInfo] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let responses = try JSONDecoder().decode([ItemInfoResponse].self, from: data)
        return responses.toItemInfoArray()
    }
    
    /// 从 JSON 字符串解析航空公司政策
    static func parseAirlinePolicy(from jsonString: String) throws -> AirlineLuggagePolicy {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(AirlinePolicyResponse.self, from: data)
        return response.toAirlineLuggagePolicy()
    }
    
    /// 从 JSON 字符串解析航空公司政策数组
    static func parseAirlinePolicyArray(from jsonString: String) throws -> [AirlineLuggagePolicy] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let responses = try JSONDecoder().decode([AirlinePolicyResponse].self, from: data)
        return responses.map { $0.toAirlineLuggagePolicy() }
    }
    
    /// 从 JSON 字符串解析政策检查结果
    static func parsePolicyCheckResult(from jsonString: String) throws -> PolicyCheckResult {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(PolicyCheckResultResponse.self, from: data)
        return response.toPolicyCheckResult()
    }
    
    /// 从 JSON 字符串解析替代品建议
    static func parseAlternativeItems(from jsonString: String) throws -> [AlternativeItem] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(AlternativeItemsResponse.self, from: data)
        return response.toAlternativeItems()
    }
    
    /// 从 JSON 字符串解析批量替代品建议
    static func parseBatchAlternativeItems(from jsonString: String) throws -> [String: [AlternativeItem]] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(BatchAlternativeItemsResponse.self, from: data)
        return response.toBatchAlternativeItems()
    }
    
    /// 从 JSON 字符串解析功能性替代品建议
    static func parseFunctionalAlternatives(from jsonString: String) throws -> [AlternativeItem] {
        let cleanedJSON = extractJSON(from: jsonString)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIParsingError.invalidJSON
        }
        
        let response = try JSONDecoder().decode(FunctionalAlternativesResponse.self, from: data)
        return response.toFunctionalAlternatives()
    }
    
    /// 提取 JSON 内容
    private static func extractJSON(from content: String) -> String {
        // 查找 JSON 代码块
        if let jsonStart = content.range(of: "```json"),
           let jsonEnd = content.range(of: "```", range: jsonStart.upperBound..<content.endIndex) {
            let jsonContent = String(content[jsonStart.upperBound..<jsonEnd.lowerBound])
            return jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 查找 { 到 } 的内容
        if let start = content.firstIndex(of: "{"),
           let end = content.lastIndex(of: "}") {
            return String(content[start...end])
        }
        
        // 查找 [ 到 ] 的内容
        if let start = content.firstIndex(of: "["),
           let end = content.lastIndex(of: "]") {
            return String(content[start...end])
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// AI 解析错误
enum AIParsingError: LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "无效的 JSON 格式"
        case .missingRequiredField(let field):
            return "缺少必需字段: \(field)"
        case .invalidFormat(let format):
            return "无效的数据格式: \(format)"
        }
    }
}