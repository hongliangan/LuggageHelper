import Foundation
import os

// MARK: - LLM API 功能辅助方法扩展

extension LLMAPIService {
    
    // MARK: - 物品特性分析辅助方法
    
    /// 判断是否为易碎物品
    internal func isFragileItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isFragileItem(item)
    }
    
    /// 判断是否为液体物品
    internal func isLiquidItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isLiquidItem(item)
    }
    
    /// 判断是否为贵重物品
    internal func isValuableItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isValuableItem(item)
    }
    
    /// 判断是否为电池物品
    internal func isBatteryItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isBatteryItem(item)
    }
    
    // MARK: - JSON 解析辅助方法
    
    /// 解析装箱计划（带ID映射）
    internal func parsePackingPlanWithMapping(from content: String, luggageId: UUID, itemIdMapping: [String: UUID]) throws -> PackingPlan {
        let cleanedJSON = extractJSONContent(from: content)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let response = try JSONDecoder().decode(PackingPlanResponse.self, from: data)
            return response.toPackingPlan(luggageId: luggageId, itemIdMapping: itemIdMapping)
        } catch {
            // 如果解析失败，返回基础的装箱计划
            return createFallbackPackingPlan(items: Array(itemIdMapping.values), luggageId: luggageId)
        }
    }
    
    /// 创建备用装箱计划
    internal func createFallbackPackingPlan(items: [UUID], luggageId: UUID) -> PackingPlan {
        let packingItems = items.enumerated().map { index, itemId in
            PackingItem(
                itemId: itemId,
                position: .middle,
                priority: 5,
                reason: "基础装箱建议"
            )
        }
        
        return PackingPlan(
            luggageId: luggageId,
            items: packingItems,
            totalWeight: 0,
            totalVolume: 0,
            efficiency: 0.5,
            warnings: [],
            suggestions: ["请手动调整装箱方案"]
        )
    }
    
    /// 提取JSON内容
    internal func extractJSONContent(from content: String) -> String {
        // 查找 JSON 代码块
        if let jsonStart = content.range(of: "```json"),
           let jsonEnd = content.range(of: "```", range: jsonStart.upperBound..<content.endIndex) {
            let jsonContent = String(content[jsonStart.upperBound..<jsonEnd.lowerBound])
            return jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 查找大括号包围的JSON
        if let jsonStart = content.range(of: "{"),
           let jsonEnd = content.range(of: "}", options: .backwards) {
            return String(content[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 解析类别数组
    internal func parseCategoryArray(from content: String, itemCount: Int) throws -> [ItemCategory] {
        // 提取JSON部分
        guard let jsonData = extractJSONArray(from: content) else {
            throw AIError.invalidResponse
        }
        
        do {
            let categoryStrings = try JSONDecoder().decode([String].self, from: jsonData)
            
            // 验证数组长度
            guard categoryStrings.count == itemCount else {
                throw AIError.invalidResponse
            }
            
            // 转换为ItemCategory
            return categoryStrings.map { categoryString in
                ItemCategory(rawValue: categoryString) ?? .other
            }
        } catch {
            throw AIError.decodingError(error)
        }
    }
    
    /// 解析标签数组
    internal func parseTagsArray(from content: String) throws -> [String] {
        // 提取JSON部分
        guard let jsonData = extractJSONArray(from: content) else {
            throw AIError.invalidResponse
        }
        
        do {
            let tags = try JSONDecoder().decode([String].self, from: jsonData)
            return tags
        } catch {
            throw AIError.decodingError(error)
        }
    }
    
    /// 提取JSON数组字符串
    internal func extractJSONArray(from content: String) -> Data? {
        // 查找第一个 [ 或 { 字符
        guard let startIndex = content.firstIndex(where: { $0 == "[" || $0 == "{" }) else {
            return nil
        }
        
        // 查找匹配的结束字符
        let startChar = content[startIndex]
        let endChar = startChar == "[" ? "]" : "}"
        
        var depth = 1
        var currentIndex = content.index(after: startIndex)
        
        while currentIndex < content.endIndex && depth > 0 {
            let char = content[currentIndex]
            
            if char == startChar {
                depth += 1
            } else if String(char) == endChar {
                depth -= 1
            }
            
            currentIndex = content.index(after: currentIndex)
        }
        
        // 如果找到了匹配的结束字符
        if depth == 0 {
            let jsonString = String(content[startIndex..<currentIndex])
            return jsonString.data(using: .utf8)
        }
        
        return nil
    }    
   
 // MARK: - 数据解析方法
    
    /// 解析物品信息
    internal func parseItemInfo(from content: String, originalName: String) throws -> ItemInfo {
        return try AIResponseParser.parseItemInfo(from: content, originalName: originalName)
    }
    
    /// 解析物品信息数组
    internal func parseItemInfoArray(from content: String) throws -> [ItemInfo] {
        return try AIResponseParser.parseItemInfoArray(from: content)
    }
    
    /// 解析旅行建议
    internal func parseTravelSuggestion(from content: String) throws -> TravelSuggestion {
        return try AIResponseParser.parseTravelSuggestion(from: content)
    }
    
    /// 解析建议物品列表
    internal func parseSuggestedItems(from content: String) throws -> [SuggestedItem] {
        return try AIResponseParser.parseSuggestedItems(from: content)
    }
    
    /// 解析遗漏物品警告
    internal func parseMissingItemAlerts(from content: String) throws -> [MissingItemAlert] {
        return try AIResponseParser.parseMissingItemAlerts(from: content)
    }
    
    /// 解析重量预测
    internal func parseWeightPrediction(from content: String) throws -> WeightPrediction {
        return try AIResponseParser.parseWeightPrediction(from: content)
    }
    
    /// 解析航空公司政策
    internal func parseAirlinePolicy(from content: String) throws -> AirlineLuggagePolicy {
        return try AIResponseParser.parseAirlinePolicy(from: content)
    }
    
    /// 解析航空公司政策数组
    internal func parseAirlinePolicyArray(from content: String) throws -> [AirlineLuggagePolicy] {
        return try AIResponseParser.parseAirlinePolicyArray(from: content)
    }
    
    /// 解析政策检查结果
    internal func parsePolicyCheckResult(from content: String) throws -> PolicyCheckResult {
        return try AIResponseParser.parsePolicyCheckResult(from: content)
    }
    

    
    // MARK: - 错误处理辅助方法
    
    /// 处理API错误并返回用户友好的错误信息
    internal func handleAPIError(_ error: Error) -> AIError {
        if let aiError = error as? AIError {
            return aiError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .networkError(NSError(domain: "网络连接失败", code: -1, userInfo: [NSLocalizedDescriptionKey: "请检查网络连接"]))
            case .timedOut:
                return .networkError(NSError(domain: "请求超时", code: -2, userInfo: [NSLocalizedDescriptionKey: "请求超时，请稍后重试"]))
            default:
                return .networkError(urlError)
            }
        }
        
        if error is DecodingError {
            return .decodingError(error)
        }
        
        return .networkError(error)
    }
    
    /// 记录详细日志
    internal func logDetailed(_ message: String, level: OSLogType = .info) {
        if enableDetailedLogging {
            logger.log(level: level, "\(message)")
        }
    }
    
    /// 记录错误日志
    internal func logError(_ error: Error, context: String = "") {
        let errorMessage = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        // 替换 logger 调用为公共方法
        // 将：
        // logger.error("错误信息")
        // 改为：
        print("[LLMAPIService] 错误信息")
        // 或者创建一个公共的日志方法
    }
    
    // MARK: - 请求优化辅助方法
    
    /// 优化提示词长度
    internal func optimizePrompt(_ prompt: String, maxLength: Int = 4000) -> String {
        if prompt.count <= maxLength {
            return prompt
        }
        
        // 简单的截断策略，保留开头和结尾
        let halfLength = maxLength / 2
        let start = String(prompt.prefix(halfLength))
        let end = String(prompt.suffix(halfLength))
        
        return start + "\n...[内容已截断]...\n" + end
    }
    
    /// 验证物品数据完整性
    internal func validateItemData(_ item: LuggageItem) -> Bool {
        return !item.name.isEmpty && 
               item.weight > 0 && 
               item.volume > 0
    }
    
    /// 验证行李箱数据完整性
    internal func validateLuggageData(_ luggage: Luggage) -> Bool {
        return !luggage.name.isEmpty && 
               luggage.capacity > 0 && 
               luggage.emptyWeight > 0
    }
    
    // MARK: - 缓存辅助方法
    
    /// 生成缓存键
    internal func generateCacheKey(for method: String, parameters: [String: Any]) -> String {
        let sortedParams = parameters.sorted { $0.key < $1.key }
        let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(method)_\(paramString.hash)"
    }
    
    /// 检查缓存是否有效
    internal func isCacheValid(for key: String, maxAge: TimeInterval = 3600) -> Bool {
        // 这里可以实现具体的缓存验证逻辑
        // 暂时返回false，表示不使用缓存
        return false
    }
    
    // MARK: - 数据转换辅助方法
    
    /// 将重量从克转换为千克
    internal func gramsToKilograms(_ grams: Double) -> Double {
        return grams / 1000.0
    }
    
    /// 将体积从立方厘米转换为升
    internal func cubicCentimetersToLiters(_ cm3: Double) -> Double {
        return cm3 / 1000.0
    }
    
    /// 格式化重量显示
    internal func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
    
    /// 格式化体积显示
    internal func formatVolume(_ cm3: Double) -> String {
        if cm3 >= 1000 {
            return String(format: "%.1fL", cm3 / 1000.0)
        } else {
            return String(format: "%.0fcm³", cm3)
        }
    } 
   
    // MARK: - 统计分析辅助方法
    
    /// 计算物品类别分布
    internal func calculateCategoryDistribution(_ items: [LuggageItem]) -> [ItemCategory: (count: Int, weight: Double, volume: Double)] {
        var distribution: [ItemCategory: (count: Int, weight: Double, volume: Double)] = [:]
        
        for item in items {
            let current = distribution[item.category] ?? (count: 0, weight: 0.0, volume: 0.0)
            distribution[item.category] = (
                count: current.count + 1,
                weight: current.weight + item.weight,
                volume: current.volume + item.volume
            )
        }
        
        return distribution
    }
    
    /// 计算装箱效率评分
    internal func calculatePackingEfficiency(
        totalVolume: Double,
        luggageCapacity: Double,
        totalWeight: Double,
        weightLimit: Double?
    ) -> Double {
        let volumeEfficiency = min(1.0, totalVolume / luggageCapacity)
        
        var weightEfficiency = 1.0
        if let limit = weightLimit {
            weightEfficiency = min(1.0, totalWeight / limit)
        }
        
        // 综合评分：体积利用率占60%，重量利用率占40%
        return volumeEfficiency * 0.6 + weightEfficiency * 0.4
    }
    
    /// 生成装箱统计报告
    internal func generatePackingStats(_ items: [LuggageItem], luggage: Luggage) -> [String: Any] {
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        let distribution = calculateCategoryDistribution(items)
        
        return [
            "totalItems": items.count,
            "totalWeight": totalWeight,
            "totalVolume": totalVolume,
            "weightWithLuggage": totalWeight + (luggage.emptyWeight * 1000),
            "volumeUtilization": totalVolume / luggage.capacity,
            "categoryDistribution": distribution,
            "averageItemWeight": totalWeight / Double(items.count),
            "averageItemVolume": totalVolume / Double(items.count)
        ]
    }
    
    // MARK: - 安全检查辅助方法
    
    /// 检查航空安全限制
    internal func checkAirlineSafetyRestrictions(_ items: [LuggageItem]) -> [String] {
        var warnings: [String] = []
        
        for item in items {
            // 检查液体限制
            if ItemAnalysisUtils.isLiquidItem(item) {
                warnings.append("液体物品 '\(item.name)' 需符合航空液体限制（单瓶≤100ml，总量≤1L）")
            }
            
            // 检查电池限制
            if ItemAnalysisUtils.isBatteryItem(item) {
                warnings.append("电池物品 '\(item.name)' 需遵循航空电池规定，锂电池建议随身携带")
            }
            
            // 检查易碎品
            if ItemAnalysisUtils.isFragileItem(item) {
                warnings.append("易碎物品 '\(item.name)' 建议妥善包装或随身携带")
            }
            
            // 检查贵重物品
            if ItemAnalysisUtils.isValuableItem(item) {
                warnings.append("贵重物品 '\(item.name)' 建议随身携带，不要托运")
            }
        }
        
        return warnings
    }
    
    /// 检查重量限制
    internal func checkWeightLimits(
        items: [LuggageItem],
        luggage: Luggage,
        airline: Airline?
    ) -> [String] {
        var warnings: [String] = []
        
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalWeightWithLuggage = totalWeight + (luggage.emptyWeight * 1000)
        
        if let airline = airline {
            let weightLimit = luggage.luggageType == .carryOn ? 
                airline.carryOnWeightLimit : airline.checkedBaggageWeightLimit
            
            if totalWeightWithLuggage > weightLimit * 1000 {
                let overweight = (totalWeightWithLuggage - weightLimit * 1000) / 1000
                warnings.append("超重 \(String(format: "%.1f", overweight))kg，航司限重 \(String(format: "%.0f", weightLimit))kg")
            }
        } else {
            // 使用标准限制
            let standardLimit = luggage.luggageType == .carryOn ? 7000.0 : 23000.0 // 7kg手提，23kg托运
            if totalWeightWithLuggage > standardLimit {
                let overweight = (totalWeightWithLuggage - standardLimit) / 1000
                warnings.append("超过标准限重 \(String(format: "%.1f", overweight))kg")
            }
        }
        
        return warnings
    }
    
    /// 检查尺寸限制
    internal func checkSizeLimits(
        totalVolume: Double,
        luggageCapacity: Double
    ) -> [String] {
        var warnings: [String] = []
        
        if totalVolume > luggageCapacity {
            let overVolume = totalVolume - luggageCapacity
            let overPercentage = (overVolume / luggageCapacity) * 100
            warnings.append("超出容量 \(String(format: "%.0f", overVolume))cm³（\(String(format: "%.1f", overPercentage))%）")
        }
        
        return warnings
    }
    
    // MARK: - 新增缓存相关解析方法
    
    /// 解析装箱计划
    internal func parsePackingPlan(from content: String, luggageId: UUID) throws -> PackingPlan {
        let cleanedJSON = extractJSONContent(from: content)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = jsonObject else {
                throw AIError.invalidResponse
            }
            
            // 解析装箱物品
            var packingItems: [PackingItem] = []
            if let itemsArray = json["items"] as? [[String: Any]] {
                for (index, itemJson) in itemsArray.enumerated() {
                    let itemName = itemJson["itemName"] as? String ?? "物品\(index + 1)"
                    let priority = itemJson["priority"] as? Int ?? 5
                    let notes = itemJson["notes"] as? String ?? ""
                    
                    // 创建临时UUID（实际使用中应该有正确的映射）
                    let itemId = UUID()
                    
                    let packingItem = PackingItem(
                        itemId: itemId,
                        position: .middle, // 简化处理
                        priority: priority,
                        reason: notes
                    )
                    packingItems.append(packingItem)
                }
            }
            
            let totalWeight = json["totalWeight"] as? Double ?? 0
            let totalVolume = json["totalVolume"] as? Double ?? 0
            let efficiency = json["efficiency"] as? Double ?? 0.5
            
            // 解析警告
            var warnings: [PackingWarning] = []
            if let warningsArray = json["warnings"] as? [[String: Any]] {
                for warningJson in warningsArray {
                    let type = warningJson["type"] as? String ?? "attention"
                    let message = warningJson["message"] as? String ?? ""
                    let severity = warningJson["severity"] as? String ?? "medium"
                    
                    let warning = PackingWarning(
                        type: WarningType(rawValue: type) ?? .attention,
                        message: message,
                        severity: WarningSeverity(rawValue: severity) ?? .medium
                    )
                    warnings.append(warning)
                }
            }
            
            let suggestions = json["tips"] as? [String] ?? []
            
            return PackingPlan(
                luggageId: luggageId,
                items: packingItems,
                totalWeight: totalWeight,
                totalVolume: totalVolume,
                efficiency: efficiency,
                warnings: warnings,
                suggestions: suggestions
            )
            
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// 解析航空公司政策（新格式）
    internal func parseAirlinePolicy(from content: String) throws -> AirlinePolicy {
        let cleanedJSON = extractJSONContent(from: content)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            let policy = try decoder.decode(AirlinePolicy.self, from: data)
            return policy
        } catch {
            throw AIError.decodingError(error)
        }
    }
    
    /// 解析替代品建议
    internal func parseAlternativeItems(from content: String) throws -> [AlternativeItem] {
        let cleanedJSON = extractJSONContent(from: content)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = jsonObject,
                  let alternativesArray = json["alternatives"] as? [[String: Any]] else {
                throw AIError.invalidResponse
            }
            
            var alternatives: [AlternativeItem] = []
            
            for altJson in alternativesArray {
                let name = altJson["name"] as? String ?? ""
                let category = altJson["category"] as? String ?? "other"
                let weight = altJson["weight"] as? Double ?? 0
                let volume = altJson["volume"] as? Double ?? 0
                
                // 解析尺寸
                var dimensions = Dimensions(length: 0, width: 0, height: 0)
                if let dimJson = altJson["dimensions"] as? [String: Any] {
                    let length = dimJson["length"] as? Double ?? 0
                    let width = dimJson["width"] as? Double ?? 0
                    let height = dimJson["height"] as? Double ?? 0
                    dimensions = Dimensions(length: length, width: width, height: height)
                }
                
                let advantages = altJson["advantages"] as? [String] ?? []
                let disadvantages = altJson["disadvantages"] as? [String] ?? []
                let suitability = altJson["suitability"] as? Double ?? 0.5
                let reason = altJson["reason"] as? String ?? ""
                let estimatedPrice = altJson["estimatedPrice"] as? Double
                let availability = altJson["availability"] as? String ?? ""
                let compatibilityScore = altJson["compatibilityScore"] as? Double ?? 0.5
                
                let alternative = AlternativeItem(
                    name: name,
                    category: ItemCategory(rawValue: category) ?? .other,
                    weight: weight,
                    volume: volume,
                    dimensions: dimensions,
                    advantages: advantages,
                    disadvantages: disadvantages,
                    suitability: suitability,
                    reason: reason,
                    estimatedPrice: estimatedPrice,
                    availability: availability,
                    compatibilityScore: compatibilityScore
                )
                
                alternatives.append(alternative)
            }
            
            return alternatives
            
        } catch {
            throw AIError.decodingError(error)
        }
    }
    
    /// 解析批量替代品建议
    internal func parseBatchAlternativeItems(from content: String) throws -> [String: [AlternativeItem]] {
        let cleanedJSON = extractJSONContent(from: content)
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = jsonObject,
                  let batchResults = json["batchResults"] as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            var results: [String: [AlternativeItem]] = [:]
            
            for (itemName, alternativesData) in batchResults {
                if let alternativesArray = alternativesData as? [[String: Any]] {
                    var alternatives: [AlternativeItem] = []
                    
                    for altJson in alternativesArray {
                        let name = altJson["name"] as? String ?? ""
                        let category = altJson["category"] as? String ?? "other"
                        let weight = altJson["weight"] as? Double ?? 0
                        let volume = altJson["volume"] as? Double ?? 0
                        
                        let dimensions = Dimensions(length: 0, width: 0, height: 0) // 简化处理
                        let advantages = altJson["advantages"] as? [String] ?? []
                        let disadvantages = altJson["disadvantages"] as? [String] ?? []
                        let suitability = altJson["suitability"] as? Double ?? 0.5
                        let reason = altJson["reason"] as? String ?? ""
                        let compatibilityScore = altJson["compatibilityScore"] as? Double ?? 0.5
                        
                        let alternative = AlternativeItem(
                            name: name,
                            category: ItemCategory(rawValue: category) ?? .other,
                            weight: weight,
                            volume: volume,
                            dimensions: dimensions,
                            advantages: advantages,
                            disadvantages: disadvantages,
                            suitability: suitability,
                            reason: reason,
                            estimatedPrice: nil,
                            availability: "",
                            compatibilityScore: compatibilityScore
                        )
                        
                        alternatives.append(alternative)
                    }
                    
                    results[itemName] = alternatives
                }
            }
            
            return results
            
        } catch {
            throw AIError.decodingError(error)
        }
    }
    
    /// 解析功能性替代品建议
    internal func parseFunctionalAlternatives(from content: String) throws -> [AlternativeItem] {
        // 与parseAlternativeItems类似的实现
        return try parseAlternativeItems(from: content)
    }
}