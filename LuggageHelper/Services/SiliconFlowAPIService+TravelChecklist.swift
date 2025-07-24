import Foundation

// MARK: - 旅行清单生成扩展
extension SiliconFlowAPIService {
    
    /// 解析旅行建议
    /// - Parameter content: AI 响应内容
    /// - Returns: 旅行建议
    func parseTravelSuggestion(from content: String) throws -> TravelSuggestion {
        // 提取 JSON 部分
        guard let jsonData = extractJSON(from: content) else {
            throw APIError.invalidResponse
        }
        
        // 检查JSON完整性并尝试修复
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            let openBraces = jsonString.filter { $0 == "{" }.count
            let closeBraces = jsonString.filter { $0 == "}" }.count
            let openBrackets = jsonString.filter { $0 == "[" }.count
            let closeBrackets = jsonString.filter { $0 == "]" }.count
            
            if openBraces != closeBraces || openBrackets != closeBrackets {
                // 尝试修复不完整的JSON
                let repairedJSON = repairIncompleteJSON(jsonString)
                if let repairedData = repairedJSON.data(using: .utf8) {
                    return try parseJSONData(repairedData)
                }
            }
        }
        
        // 尝试解析原始JSON
        return try parseJSONData(jsonData)
    }
    
    /// 修复不完整的JSON
    /// - Parameter incompleteJSON: 不完整的JSON字符串
    /// - Returns: 修复后的JSON字符串
    private func repairIncompleteJSON(_ incompleteJSON: String) -> String {
        var repairedJSON = incompleteJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 计算需要补充的括号
        let openBraces = repairedJSON.filter { $0 == "{" }.count
        let closeBraces = repairedJSON.filter { $0 == "}" }.count
        let openBrackets = repairedJSON.filter { $0 == "[" }.count
        let closeBrackets = repairedJSON.filter { $0 == "]" }.count
        
        // 补充缺失的右括号
        for _ in 0..<(openBrackets - closeBrackets) {
            repairedJSON += "]"
        }
        
        // 补充缺失的右大括号
        for _ in 0..<(openBraces - closeBraces) {
            repairedJSON += "}"
        }
        
        return repairedJSON
    }
    
    /// 解析JSON数据
    /// - Parameter jsonData: JSON数据
    /// - Returns: 旅行建议
    private func parseJSONData(_ jsonData: Data) throws -> TravelSuggestion {
        do {
            // 尝试使用 AIResponseParser 解析
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return try AIResponseParser.parseTravelSuggestion(from: jsonString)
            } else {
                throw APIError.invalidResponse
            }
        } catch {
            // 如果解析失败，尝试手动解析
            return try manualParseJSON(jsonData)
        }
    }
    
    /// 手动解析JSON
    /// - Parameter jsonData: JSON数据
    /// - Returns: 旅行建议
    private func manualParseJSON(_ jsonData: Data) throws -> TravelSuggestion {
        let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        
        guard let json = json else {
            throw APIError.invalidResponse
        }
        
        // 提取基本信息
        guard let destination = json["destination"] as? String,
              let duration = json["duration"] as? Int,
              let season = json["season"] as? String,
              let activities = json["activities"] as? [String] else {
            throw APIError.invalidResponse
        }
        
        // 解析建议物品
        let suggestedItemsJson = json["suggestedItems"] as? [[String: Any]] ?? []
        var suggestedItems: [SuggestedItem] = []
        
        for itemJson in suggestedItemsJson {
            guard let name = itemJson["name"] as? String,
                  let categoryString = itemJson["category"] as? String,
                  let importanceString = itemJson["importance"] as? String,
                  let reason = itemJson["reason"] as? String,
                  let quantity = itemJson["quantity"] as? Int else {
                continue
            }
            
            let category = ItemCategory(rawValue: categoryString) ?? .other
            let importance = ImportanceLevel(rawValue: importanceString) ?? .optional
            let estimatedWeight = itemJson["estimatedWeight"] as? Double
            let estimatedVolume = itemJson["estimatedVolume"] as? Double
            
            let item = SuggestedItem(
                name: name,
                category: category,
                importance: importance,
                reason: reason,
                quantity: quantity,
                estimatedWeight: estimatedWeight,
                estimatedVolume: estimatedVolume
            )
            
            suggestedItems.append(item)
        }
        
        // 提取类别、贴士和警告
        let categoriesStrings = json["categories"] as? [String] ?? []
        let categories = categoriesStrings.compactMap { ItemCategory(rawValue: $0) }
        let tips = json["tips"] as? [String] ?? []
        let warnings = json["warnings"] as? [String] ?? []
        
        // 创建旅行建议
        return TravelSuggestion(
            destination: destination,
            duration: duration,
            season: season,
            activities: activities,
            suggestedItems: suggestedItems,
            categories: categories,
            tips: tips,
            warnings: warnings
        )
    }
    
    /// 提取 JSON 数据
    /// - Parameter content: 包含 JSON 的字符串
    /// - Returns: JSON 数据
    private func extractJSON(from content: String) -> Data? {
        // 查找 JSON 代码块
        if let jsonStart = content.range(of: "```json"),
           let jsonEnd = content.range(of: "```", range: jsonStart.upperBound..<content.endIndex) {
            let jsonContent = String(content[jsonStart.upperBound..<jsonEnd.lowerBound])
            return jsonContent.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
        }
        
        // 查找 { 到 } 的内容
        if let start = content.firstIndex(of: "{"),
           let end = content.lastIndex(of: "}") {
            let jsonContent = String(content[start...end])
            return jsonContent.data(using: .utf8)
        }
        
        // 查找 [ 到 ] 的内容
        if let start = content.firstIndex(of: "["),
           let end = content.lastIndex(of: "]") {
            let jsonContent = String(content[start...end])
            return jsonContent.data(using: .utf8)
        }
        
        // 尝试整个内容
        return content.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
    }
}