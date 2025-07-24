import Foundation

// MARK: - 旅行清单生成扩展
extension SiliconFlowAPIService {
    
    /// 解析旅行建议
    /// - Parameter content: AI 响应内容
    /// - Returns: 旅行建议
    func parseTravelSuggestion(from content: String) throws -> TravelSuggestion {
        // 打印原始响应内容用于调试
        print("[DEBUG] AI 原始响应内容:")
        print(content)
        print("[DEBUG] 响应内容长度: \(content.count)")
        
        // 提取 JSON 部分
        guard let jsonData = extractJSON(from: content) else {
            print("[ERROR] 无法提取JSON数据")
            throw APIError.invalidResponse
        }
        
        // 打印提取的JSON数据
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[DEBUG] 提取的JSON数据:")
            print(jsonString)
            print("[DEBUG] JSON数据长度: \(jsonString.count)")
            
            // 检查JSON是否完整
            let openBraces = jsonString.filter { $0 == "{" }.count
            let closeBraces = jsonString.filter { $0 == "}" }.count
            let openBrackets = jsonString.filter { $0 == "[" }.count
            let closeBrackets = jsonString.filter { $0 == "]" }.count
            
            print("[DEBUG] JSON结构检查: {\(openBraces) }\(closeBraces) [\(openBrackets) ]\(closeBrackets)")
            
            if openBraces != closeBraces || openBrackets != closeBrackets {
                print("[WARNING] JSON结构不完整，尝试修复")
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
        
        print("[DEBUG] 修复后的JSON: \(repairedJSON)")
        return repairedJSON
    }
    
    /// 解析JSON数据
    /// - Parameter jsonData: JSON数据
    /// - Returns: 旅行建议
    private func parseJSONData(_ jsonData: Data) throws -> TravelSuggestion {
        do {
            // 尝试使用 AIResponseParser 解析
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[DEBUG] 尝试使用 AIResponseParser 解析")
                return try AIResponseParser.parseTravelSuggestion(from: jsonString)
            } else {
                throw APIError.invalidResponse
            }
        } catch {
            print("[DEBUG] AIResponseParser 解析失败: \(error)")
            // 如果解析失败，尝试手动解析
            return try manualParseJSON(jsonData)
        }
    }
    
    /// 手动解析JSON
    /// - Parameter jsonData: JSON数据
    /// - Returns: 旅行建议
    private func manualParseJSON(_ jsonData: Data) throws -> TravelSuggestion {
        print("[DEBUG] 尝试手动解析JSON")
        
        let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        
        guard let json = json else {
            print("[ERROR] JSON序列化失败")
            throw APIError.invalidResponse
        }
        
        print("[DEBUG] JSON解析成功，字段: \(json.keys.sorted())")
        
        // 提取基本信息
        guard let destination = json["destination"] as? String else {
            print("[ERROR] 缺少destination字段")
            throw APIError.invalidResponse
        }
        
        guard let duration = json["duration"] as? Int else {
            print("[ERROR] 缺少duration字段")
            throw APIError.invalidResponse
        }
        
        guard let season = json["season"] as? String else {
            print("[ERROR] 缺少season字段")
            throw APIError.invalidResponse
        }
        
        guard let activities = json["activities"] as? [String] else {
            print("[ERROR] 缺少activities字段")
            throw APIError.invalidResponse
        }
        
        // suggestedItems可能不完整，需要特殊处理
        let suggestedItemsJson = json["suggestedItems"] as? [[String: Any]] ?? []
        print("[DEBUG] 找到\(suggestedItemsJson.count)个物品")
        
        // 解析建议物品
        var suggestedItems: [SuggestedItem] = []
        for (index, itemJson) in suggestedItemsJson.enumerated() {
            print("[DEBUG] 解析第\(index + 1)个物品: \(itemJson.keys.sorted())")
            
            guard let name = itemJson["name"] as? String,
                  let categoryString = itemJson["category"] as? String,
                  let importanceString = itemJson["importance"] as? String,
                  let reason = itemJson["reason"] as? String,
                  let quantity = itemJson["quantity"] as? Int else {
                print("[WARNING] 第\(index + 1)个物品字段不完整，跳过")
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
        
        print("[DEBUG] 成功解析\(suggestedItems.count)个物品")
        
        // 提取类别
        let categoriesStrings = json["categories"] as? [String] ?? []
        let categories = categoriesStrings.compactMap { ItemCategory(rawValue: $0) }
        
        // 提取贴士和警告
        let tips = json["tips"] as? [String] ?? []
        let warnings = json["warnings"] as? [String] ?? []
        
        print("[DEBUG] 创建TravelSuggestion对象")
        
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