import Foundation

// MARK: - AI 增强功能扩展

extension LLMAPIService {
    
    // MARK: - 物品识别功能
    
    /// 识别物品信息
    /// - Parameters:
    ///   - name: 物品名称
    ///   - model: 物品型号（可选）
    ///   - brand: 品牌（可选）
    ///   - additionalInfo: 额外信息（可选）
    /// - Returns: 物品信息
    func identifyItem(name: String, model: String? = nil, brand: String? = nil, additionalInfo: String? = nil) async throws -> ItemInfo {
        // 确保配置同步
        let config = ensureConfigurationSync()
        
        // 添加调试信息
        print("🔍 identifyItem 使用的配置:")
        print("   - baseURL: \(config.baseURL)")
        print("   - model: \(config.model)")
        print("   - apiKey: \(config.apiKey.isEmpty ? "空" : "已设置(\(config.apiKey.prefix(10))...)")")
           
        guard config.isValid() else {
        // 添加更详细的错误信息
        let details = "baseURL: \(config.baseURL.isEmpty ? "空" : "已设置"), apiKey: \(config.apiKey.isEmpty ? "空" : "已设置"), model: \(config.model.isEmpty ? "空" : "已设置")"
        throw APIError.configurationError("LLM API配置无效 - \(details)")
        }
        
        let modelInfo = model.map { " 型号：\($0)" } ?? ""
        let brandInfo = brand.map { " 品牌：\($0)" } ?? ""
        let extraInfo = additionalInfo.map { " 补充信息：\($0)" } ?? ""
        
        let prompt = """
        请识别物品"\(name)\(modelInfo)\(brandInfo)\(extraInfo)"的详细信息，并以JSON格式返回：
        
        {
            "name": "标准化物品名称",
            "category": "物品类别",
            "weight": 重量（克，数值类型），
            "volume": 体积（立方厘米，数值类型），
            "dimensions": {
                "length": 长度（厘米，数值类型），
                "width": 宽度（厘米，数值类型），
                "height": 高度（厘米，数值类型）
            },
            "confidence": 置信度（0.0-1.0，数值类型），
            "alternatives": [
                {
                    "name": "替代品名称",
                    "weight": 重量（克），
                    "volume": 体积（立方厘米），
                    "reason": "推荐理由"
                }
            ]
        }
        
        物品类别必须是以下之一：
        - clothing: 衣物（衬衫、裤子、裙子、内衣等）
        - electronics: 电子产品（手机、电脑、充电器、耳机等）
        - toiletries: 洗漱用品（牙刷、洗发水、护肤品等）
        - documents: 证件文件（护照、身份证、合同等）
        - medicine: 药品保健（药品、维生素、医疗器械等）
        - accessories: 配饰用品（包包、首饰、手表、眼镜等）
        - shoes: 鞋类（运动鞋、皮鞋、拖鞋等）
        - books: 书籍文具（书籍、笔记本、文具等）
        - food: 食品饮料（零食、饮料、保健品等）
        - sports: 运动用品（运动器材、运动服装等）
        - beauty: 美容化妆（化妆品、护肤品、美容工具等）
        - other: 其他（无法归类的物品）
        """        

        let messages = [
            ChatMessage.system("你是一个专业的物品识别专家，具有丰富的产品知识和准确的重量体积估算能力。请始终返回有效的JSON格式数据，确保数值字段为数字类型。"),
            ChatMessage.user(prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            maxTokens: min(config.maxTokens ?? 2048, 2048),
            temperature: config.temperature ?? 0.7,
            topP: config.topP ?? 0.9,
            stream: false,
            responseFormat: nil,
            topK: config.topK ?? 50,
            frequencyPenalty: config.frequencyPenalty ?? 0.0,
            stop: nil
        )
        
        let response = try await performRequest(request, config: config)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfo(from: content, originalName: name)
    }
    
    /// 批量识别物品信息
    /// - Parameter items: 物品名称列表
    /// - Returns: 物品信息列表
    func batchIdentifyItems(_ items: [String]) async throws -> [ItemInfo] {
        guard !items.isEmpty else {
            throw APIError.insufficientData
        }
        
        let itemsList = items.enumerated().map { index, name in
            "\(index + 1). \(name)"
        }.joined(separator: "\n")
        
        let prompt = """
        请批量识别以下物品的详细信息，并以JSON数组格式返回：
        
        \(itemsList)
        
        返回格式：
        [
            {
                "name": "标准化物品名称",
                "category": "物品类别",
                "weight": 重量（克），
                "volume": 体积（立方厘米），
                "dimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "confidence": 置信度（0.0-1.0），
                "alternatives": []
            }
        ]
        
        请为每个物品提供准确的分类和合理的重量体积估算。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品识别专家，能够批量处理物品识别任务。请返回有效的JSON数组格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfoArray(from: content)
    } 
   
    /// 智能物品建议
    /// - Parameters:
    ///   - category: 物品类别
    ///   - purpose: 用途描述
    ///   - constraints: 约束条件（如重量、体积限制）
    /// - Returns: 建议的物品列表
    func suggestItemsForCategory(
        category: ItemCategory,
        purpose: String,
        constraints: PackingConstraints? = nil
    ) async throws -> [ItemInfo] {
        let constraintsInfo = constraints.map { c in
            "约束条件：最大重量\(c.maxWeight)g，最大体积\(c.maxVolume)cm³"
        } ?? ""
        
        let prompt = """
        请为"\(purpose)"推荐\(category.displayName)类别的物品，\(constraintsInfo)
        
        返回JSON数组格式：
        [
            {
                "name": "物品名称",
                "category": "\(category.rawValue)",
                "weight": 重量（克），
                "volume": 体积（立方厘米），
                "dimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "confidence": 置信度（0.0-1.0），
                "alternatives": []
            }
        ]
        
        请推荐3-5个最适合的物品，考虑实用性和便携性。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品推荐专家，能够根据用途和约束条件推荐合适的物品。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfoArray(from: content)
    }
    
    /// 从照片识别物品
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - hint: 识别提示（可选）
    /// - Returns: 物品信息
    func identifyItemFromPhoto(_ imageData: Data, hint: String? = nil) async throws -> ItemInfo {
        // 检查图片大小
        guard imageData.count > 0 else {
            throw APIError.invalidResponse
        }
        
        // 目前大多数 API 不支持图像输入，这里提供一个框架实现
        // 当支持视觉模型时，可以使用以下逻辑：
        
        /*
        // 将图片转换为 base64
        let base64Image = imageData.base64EncodedString()
        
        let hintText = hint.map { "提示：\($0)" } ?? ""
        
        let prompt = """
        请识别图片中的物品并返回详细信息。\(hintText)
        
        返回JSON格式：
        {
            "name": "物品名称",
            "category": "物品类别",
            "weight": 重量（克），
            "volume": 体积（立方厘米），
            "dimensions": {
                "length": 长度（厘米），
                "width": 宽度（厘米），
                "height": 高度（厘米）
            },
            "confidence": 置信度（0.0-1.0），
            "alternatives": []
        }
        """
        
        // 构建包含图片的消息
        let messages = [
            ChatMessage.system("你是一个专业的图像识别专家，能够准确识别图片中的物品。"),
            // 这里需要支持图片消息格式
            ChatMessage(role: "user", content: prompt, image: base64Image)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfo(from: content, originalName: "图片识别物品")
        */
        
        // 临时实现：基于图片大小和提示进行模拟识别
        return try await simulatePhotoRecognition(imageData: imageData, hint: hint)
    } 
   
    /// 模拟照片识别（临时实现）
    private func simulatePhotoRecognition(imageData: Data, hint: String?) async throws -> ItemInfo {
        // 基于图片大小和提示进行简单推测
        let imageSizeKB = Double(imageData.count) / 1024.0
        
        var estimatedCategory: ItemCategory = .other
        var estimatedName = "未知物品"
        var confidence = 0.3
        
        // 如果有提示，尝试识别
        if let hint = hint?.lowercased() {
            if hint.contains("衣") || hint.contains("shirt") || hint.contains("clothes") {
                estimatedCategory = .clothing
                estimatedName = "衣物"
                confidence = 0.6
            } else if hint.contains("电") || hint.contains("phone") || hint.contains("电脑") {
                estimatedCategory = .electronics
                estimatedName = "电子产品"
                confidence = 0.6
            } else if hint.contains("鞋") || hint.contains("shoe") {
                estimatedCategory = .shoes
                estimatedName = "鞋类"
                confidence = 0.6
            } else if hint.contains("包") || hint.contains("bag") {
                estimatedCategory = .accessories
                estimatedName = "包包"
                confidence = 0.6
            }
        }
        
        // 基于图片大小估算物品大小
        let estimatedWeight = min(max(imageSizeKB * 10, 50), 2000) // 50g - 2kg
        let estimatedVolume = min(max(imageSizeKB * 50, 100), 10000) // 100cm³ - 10L
        
        return ItemInfo(
            name: estimatedName,
            category: estimatedCategory,
            weight: estimatedWeight,
            volume: estimatedVolume,
            dimensions: Dimensions(
                length: pow(estimatedVolume, 1.0/3.0),
                width: pow(estimatedVolume, 1.0/3.0),
                height: pow(estimatedVolume, 1.0/3.0)
            ),
            confidence: confidence,
            source: "照片模拟识别"
        )
    }
    
    /// 检查是否支持照片识别
    func supportsPhotoRecognition() -> Bool {
        // 检查当前配置的模型是否支持视觉功能
        // 这里可以根据模型名称判断
        let config = currentConfig ?? LLMConfigurationManager.shared.currentConfig
        guard config.isValid() else {
            return false
        }
        let visionModels = ["gpt-4-vision", "claude-3", "gemini-pro-vision"]
        return visionModels.contains { config.model.contains($0) }
    }
    
    // MARK: - 旅行建议功能
    
    /// 生成旅行物品清单
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 旅行天数
    ///   - season: 季节
    ///   - activities: 活动列表
    ///   - userPreferences: 用户偏好（可选）
    /// - Returns: 旅行建议
    func generateTravelChecklist(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userPreferences: UserPreferences? = nil
    ) async throws -> TravelSuggestion {
        let preferencesInfo = userPreferences.map { prefs in
            """
            用户偏好：
            - 装箱风格：\(prefs.packingStyle.displayName)
            - 预算水平：\(prefs.budgetLevel.displayName)
            - 偏好品牌：\(prefs.preferredBrands.joined(separator: "、"))
            - 避免物品：\(prefs.avoidedItems.joined(separator: "、"))
            """
        } ?? ""
        
        let prompt = """
        请为前往\(destination)的\(duration)天\(season)旅行生成详细的物品清单建议。
        计划活动：\(activities.joined(separator: "、"))
        \(preferencesInfo)
        
        请以JSON格式返回：
        {
            "destination": "\(destination)",
            "duration": \(duration),
            "season": "\(season)",
            "activities": \(activities),
            "suggestedItems": [
                {
                    "name": "物品名称",
                    "category": "类别",
                    "importance": "essential/important/recommended/optional",
                    "reason": "推荐理由",
                    "quantity": 数量,
                    "estimatedWeight": 预估重量（克）,
                    "estimatedVolume": 预估体积（立方厘米）
                }
            ],
            "categories": ["主要类别列表"],
            "tips": ["旅行小贴士"],
            "warnings": ["注意事项"]
        }
        
        请考虑当地气候、文化特点和活动需求。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的旅行规划助手，擅长根据目的地、季节和行程提供实用的行李打包建议。请始终返回有效的JSON格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseTravelSuggestion(from: content)
    }    

    // MARK: - 物品替代建议功能
    
    /// 为指定物品建议替代品
    /// - Parameters:
    ///   - item: 原始物品信息
    ///   - constraints: 约束条件（重量、体积、预算等）
    ///   - purpose: 使用目的或场景
    ///   - preferences: 用户偏好
    /// - Returns: 替代品建议列表
    func suggestAlternatives(
        for item: ItemInfo,
        constraints: AlternativeConstraints? = nil,
        purpose: String? = nil,
        preferences: UserPreferences? = nil
    ) async throws -> [AlternativeItem] {
        let config = currentConfig ?? LLMConfigurationManager.shared.currentConfig
        
        guard config.isValid() else {
            throw APIError.configurationError("LLM API配置无效")
        }
        
        let constraintsInfo = constraints.map { c in
            var info = "约束条件："
            if let maxWeight = c.maxWeight {
                info += " 最大重量\(maxWeight)g"
            }
            if let maxVolume = c.maxVolume {
                info += " 最大体积\(maxVolume)cm³"
            }
            if let maxBudget = c.maxBudget {
                info += " 预算上限\(maxBudget)元"
            }
            if let requiredFeatures = c.requiredFeatures, !requiredFeatures.isEmpty {
                info += " 必需功能：\(requiredFeatures.joined(separator: "、"))"
            }
            return info
        } ?? ""
        
        let purposeInfo = purpose.map { "使用场景：\($0)" } ?? ""
        
        let preferencesInfo = preferences.map { prefs in
            var info = "用户偏好："
            if !prefs.preferredBrands.isEmpty {
                info += " 偏好品牌：\(prefs.preferredBrands.joined(separator: "、"))"
            }
            if !prefs.avoidedItems.isEmpty {
                info += " 避免物品：\(prefs.avoidedItems.joined(separator: "、"))"
            }
            info += " 装箱风格：\(prefs.packingStyle.displayName)"
            info += " 预算水平：\(prefs.budgetLevel.displayName)"
            return info
        } ?? ""
        
        let prompt = """
        请为物品"\(item.name)"（类别：\(item.category.displayName)，重量：\(item.weight)g，体积：\(item.volume)cm³）推荐替代品。
        
        \(constraintsInfo)
        \(purposeInfo)
        \(preferencesInfo)
        
        请以JSON格式返回：
        {
            "originalItem": {
                "name": "\(item.name)",
                "category": "\(item.category.rawValue)",
                "weight": \(item.weight),
                "volume": \(item.volume)
            },
            "alternatives": [
                {
                    "name": "替代品名称",
                    "category": "类别",
                    "weight": 重量（克，数值类型），
                    "volume": 体积（立方厘米，数值类型），
                    "dimensions": {
                        "length": 长度（厘米，数值类型），
                        "width": 宽度（厘米，数值类型），
                        "height": 高度（厘米，数值类型）
                    },
                    "advantages": ["优势1", "优势2"],
                    "disadvantages": ["劣势1", "劣势2"],
                    "suitability": 适用性评分（0.0-1.0，数值类型），
                    "reason": "推荐理由",
                    "estimatedPrice": 预估价格（元，数值类型，可选），
                    "availability": "购买渠道",
                    "compatibilityScore": 兼容性评分（0.0-1.0，数值类型）
                }
            ],
            "recommendations": [
                {
                    "scenario": "使用场景",
                    "bestAlternative": "最佳替代品名称",
                    "reason": "推荐理由"
                }
            ]
        }
        
        请提供3-5个高质量的替代品建议，考虑功能性、便携性、性价比等因素。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的产品替代建议专家，具有丰富的产品知识和比较分析能力。请始终返回有效的JSON格式数据，确保数值字段为数字类型。"),
            ChatMessage.user(prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            maxTokens: min(config.maxTokens ?? 2048, 3000),
            temperature: config.temperature ?? 0.7,
            topP: config.topP ?? 0.9,
            stream: false,
            responseFormat: nil,
            topK: config.topK ?? 50,
            frequencyPenalty: config.frequencyPenalty ?? 0.0,
            stop: nil
        )
        
        let response = try await performRequest(request, config: config)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseAlternativeItems(from: content)
    }
    
    /// 批量建议替代品
    /// - Parameters:
    ///   - items: 物品列表
    ///   - constraints: 全局约束条件
    ///   - purpose: 使用目的
    /// - Returns: 批量替代建议
    func batchSuggestAlternatives(
        for items: [ItemInfo],
        constraints: AlternativeConstraints? = nil,
        purpose: String? = nil
    ) async throws -> [String: [AlternativeItem]] {
        guard !items.isEmpty else {
            throw APIError.insufficientData
        }
        
        let itemsList = items.enumerated().map { index, item in
            "\(index + 1). \(item.name)（\(item.category.displayName)，\(item.weight)g，\(item.volume)cm³）"
        }.joined(separator: "\n")
        
        let constraintsInfo = constraints.map { c in
            var info = "全局约束："
            if let maxWeight = c.maxWeight {
                info += " 单品最大重量\(maxWeight)g"
            }
            if let maxVolume = c.maxVolume {
                info += " 单品最大体积\(maxVolume)cm³"
            }
            if let maxBudget = c.maxBudget {
                info += " 单品预算上限\(maxBudget)元"
            }
            return info
        } ?? ""
        
        let purposeInfo = purpose.map { "使用场景：\($0)" } ?? ""
        
        let prompt = """
        请为以下物品批量推荐替代品：
        
        \(itemsList)
        
        \(constraintsInfo)
        \(purposeInfo)
        
        请以JSON格式返回：
        {
            "batchResults": {
                "物品1名称": [
                    {
                        "name": "替代品名称",
                        "category": "类别",
                        "weight": 重量（克），
                        "volume": 体积（立方厘米），
                        "advantages": ["优势"],
                        "disadvantages": ["劣势"],
                        "suitability": 适用性评分（0.0-1.0），
                        "reason": "推荐理由",
                        "compatibilityScore": 兼容性评分（0.0-1.0）
                    }
                ]
            },
            "globalRecommendations": [
                {
                    "category": "类别",
                    "suggestion": "整体建议",
                    "potentialSavings": {
                        "weight": 重量节省（克），
                        "volume": 体积节省（立方厘米）
                    }
                }
            ]
        }
        
        为每个物品提供2-3个最佳替代品，并给出整体优化建议。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的批量产品替代建议专家，能够综合考虑多个物品的替代方案并提供整体优化建议。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseBatchAlternativeItems(from: content)
    }
    
    /// 智能替代品搜索
    /// - Parameters:
    ///   - functionality: 所需功能描述
    ///   - constraints: 约束条件
    ///   - excludeItems: 排除的物品
    /// - Returns: 功能性替代品建议
    func searchFunctionalAlternatives(
        functionality: String,
        constraints: AlternativeConstraints? = nil,
        excludeItems: [String] = []
    ) async throws -> [AlternativeItem] {
        let constraintsInfo = constraints.map { c in
            var info = "约束条件："
            if let maxWeight = c.maxWeight {
                info += " 最大重量\(maxWeight)g"
            }
            if let maxVolume = c.maxVolume {
                info += " 最大体积\(maxVolume)cm³"
            }
            if let maxBudget = c.maxBudget {
                info += " 预算上限\(maxBudget)元"
            }
            if let requiredFeatures = c.requiredFeatures, !requiredFeatures.isEmpty {
                info += " 必需功能：\(requiredFeatures.joined(separator: "、"))"
            }
            return info
        } ?? ""
        
        let excludeInfo = excludeItems.isEmpty ? "" : "排除物品：\(excludeItems.joined(separator: "、"))"
        
        let prompt = """
        请为功能需求"\(functionality)"推荐合适的物品。
        
        \(constraintsInfo)
        \(excludeInfo)
        
        请以JSON格式返回：
        {
            "functionality": "\(functionality)",
            "alternatives": [
                {
                    "name": "物品名称",
                    "category": "类别",
                    "weight": 重量（克，数值类型），
                    "volume": 体积（立方厘米，数值类型），
                    "dimensions": {
                        "length": 长度（厘米，数值类型），
                        "width": 宽度（厘米，数值类型），
                        "height": 高度（厘米，数值类型）
                    },
                    "advantages": ["优势"],
                    "disadvantages": ["劣势"],
                    "suitability": 适用性评分（0.0-1.0，数值类型），
                    "reason": "推荐理由",
                    "functionalityMatch": 功能匹配度（0.0-1.0，数值类型），
                    "versatility": 多功能性评分（0.0-1.0，数值类型）
                }
            ],
            "bestMatch": {
                "name": "最佳匹配物品名称",
                "reason": "选择理由"
            }
        }
        
        请推荐3-5个能够满足功能需求的物品，优先考虑多功能性和便携性。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的功能性产品推荐专家，能够根据功能需求推荐最合适的物品。请始终返回有效的JSON格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseFunctionalAlternatives(from: content)
    }
}
