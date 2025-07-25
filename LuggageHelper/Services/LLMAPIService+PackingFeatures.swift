import Foundation

// MARK: - 装箱优化功能扩展

extension LLMAPIService {
    
    // MARK: - 装箱优化功能
    
    /// 优化装箱方案
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱信息
    /// - Returns: 装箱计划
    func optimizePacking(items: [LuggageItem], luggage: Luggage) async throws -> PackingPlan {
        // 计算基础统计信息
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        let efficiency = min(1.0, totalVolume / luggage.capacity)
        
        // 构建详细的物品信息，包含类别和特性分析
        let itemsInfo = items.enumerated().map { index, item in
            let fragileIndicator = ItemAnalysisUtils.isFragileItem(item) ? " [易碎]" : ""
            let liquidIndicator = ItemAnalysisUtils.isLiquidItem(item) ? " [液体]" : ""
            let heavyIndicator = item.weight > 1000 ? " [重物]" : ""
            let valuableIndicator = ItemAnalysisUtils.isValuableItem(item) ? " [贵重]" : ""
            
            return """
            - ID: \(item.id.uuidString)
              名称: \(item.name)
              类别: \(item.category.displayName) (\(item.category.rawValue))
              重量: \(item.weight)g
              体积: \(item.volume)cm³
              特性: \(item.category.icon)\(fragileIndicator)\(liquidIndicator)\(heavyIndicator)\(valuableIndicator)
            """
        }.joined(separator: "\n")
        
        // 分析行李箱容量和重量限制
        let capacityUtilization = (totalVolume / luggage.capacity) * 100
        let weightWithLuggage = totalWeight + (luggage.emptyWeight * 1000) // 转换为克
        
        // 构建增强的提示词，包含更详细的优化策略
        let prompt = """
        作为专业的装箱优化专家，请为以下物品设计最优的装箱方案。请基于物理学原理、重量分布、物品特性和实用性考虑。
        
        行李箱信息：
        - 名称：\(luggage.name)
        - 类型：\(luggage.luggageType.displayName)
        - 容量：\(luggage.capacity)cm³
        - 空箱重量：\(luggage.emptyWeight)kg
        - 当前容量利用率：\(String(format: "%.1f", capacityUtilization))%
        
        物品清单（共\(items.count)件）：
        \(itemsInfo)
        
        统计信息：
        - 物品总重量：\(String(format: "%.1f", totalWeight/1000))kg
        - 物品总体积：\(String(format: "%.1f", totalVolume))cm³
        - 含箱总重量：\(String(format: "%.1f", weightWithLuggage/1000))kg
        
        优化策略要求：
        1. 重量分布：重物放底部，轻物放顶部，保持重心稳定
        2. 保护策略：易碎品用衣物包裹，放在中部避免挤压
        3. 便利性：常用物品放顶部，不常用的放底部
        4. 空间利用：利用鞋内空间，衣物填充空隙
        5. 安全考虑：液体密封，电池按规定放置
        6. 类别聚集：同类物品相对集中，便于查找
        
        请以JSON格式返回装箱计划：
        {
            "items": [
                {
                    "itemId": "完整的UUID字符串",
                    "position": "bottom/middle/top/side/corner",
                    "priority": 优先级（1-10，10最高），
                    "reason": "详细的装箱建议原因，说明为什么这样放置"
                }
            ],
            "totalWeight": \(totalWeight),
            "totalVolume": \(totalVolume),
            "efficiency": \(efficiency),
            "warnings": [
                {
                    "type": "overweight/oversized/fragile/liquid/battery/prohibited",
                    "message": "具体的警告信息",
                    "severity": "low/medium/high/critical"
                }
            ],
            "suggestions": [
                "具体的装箱优化建议",
                "空间利用技巧",
                "安全注意事项"
            ]
        }
        
        特别注意：
        - 检查是否超重（一般航空限制23kg）
        - 检查是否超容量
        - 识别易碎、液体、电池等特殊物品
        - 提供实用的装箱技巧
        - 考虑取用便利性
        """
        
        let messages = [
            ChatMessage.system("""
            你是一个专业的装箱优化专家，具有丰富的旅行经验和物理学知识。你能够：
            1. 基于物品重量、体积、形状和特性进行科学的装箱规划
            2. 考虑重心平衡、空间利用率和物品保护
            3. 识别潜在的安全隐患和航空限制
            4. 提供实用的装箱技巧和建议
            5. 始终返回有效的JSON格式数据，确保所有itemId都是完整的UUID格式
            """),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        // 创建物品ID映射，确保AI返回的ID能正确映射到实际物品
        let itemIdMapping = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0.id) })
        
        return try parsePackingPlanWithMapping(from: content, luggageId: luggage.id, itemIdMapping: itemIdMapping)
    }   
 
    // MARK: - 智能分类功能
    
    /// 自动分类物品
    /// - Parameter item: 物品
    /// - Returns: 物品类别
    func categorizeItem(_ item: LuggageItem) async throws -> ItemCategory {
        let prompt = """
        请为物品"\(item.name)"确定最合适的类别。
        
        可选类别：
        - clothing: 衣物
        - electronics: 电子产品
        - toiletries: 洗漱用品
        - documents: 证件文件
        - medicine: 药品保健
        - accessories: 配饰用品
        - shoes: 鞋类
        - books: 书籍文具
        - food: 食品饮料
        - sports: 运动用品
        - beauty: 美容化妆
        - other: 其他
        
        请只返回类别英文名称，不要其他内容。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品分类专家，能够准确识别各种物品的类别。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              let category = ItemCategory(rawValue: content) else {
            return .other
        }
        
        return category
    }
    
    /// 批量分类物品
    /// - Parameter items: 物品名称列表
    /// - Returns: 物品类别列表
    func batchCategorizeItems(_ items: [String]) async throws -> [ItemCategory] {
        guard !items.isEmpty else {
            throw APIError.insufficientData
        }
        
        let itemsList = items.enumerated().map { index, name in
            "\(index + 1). \(name)"
        }.joined(separator: "\n")
        
        let prompt = """
        请为以下物品确定最合适的类别：
        
        \(itemsList)
        
        可选类别：
        - clothing: 衣物
        - electronics: 电子产品
        - toiletries: 洗漱用品
        - documents: 证件文件
        - medicine: 药品保健
        - accessories: 配饰用品
        - shoes: 鞋类
        - books: 书籍文具
        - food: 食品饮料
        - sports: 运动用品
        - beauty: 美容化妆
        - other: 其他
        
        请以JSON数组格式返回，每个元素只包含类别英文名称，例如：
        ["clothing", "electronics", "other"]
        
        数组长度必须与物品数量一致，顺序与输入物品顺序相同。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品分类专家，能够准确识别各种物品的类别。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseCategoryArray(from: content, itemCount: items.count)
    }
    
    /// 生成物品标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    func generateItemTags(for item: LuggageItem) async throws -> [String] {
        let prompt = """
        请为物品"\(item.name)"生成3-5个相关标签，这些标签应该描述物品的特性、用途或场景。
        
        例如，对于"iPhone 13"，可能的标签有：
        - 电子设备
        - 通讯工具
        - 苹果产品
        - 智能手机
        - 便携设备
        
        请以JSON数组格式返回标签，例如：
        ["标签1", "标签2", "标签3"]
        
        标签应该简洁、准确，每个标签不超过5个字。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品标签生成专家，能够为各种物品生成准确、有用的标签。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseTagsArray(from: content)
    }    

    // MARK: - 个性化建议功能
    
    /// 获取个性化建议
    /// - Parameters:
    ///   - userProfile: 用户档案
    ///   - travelPlan: 旅行计划
    /// - Returns: 建议列表
    func getPersonalizedSuggestions(
        userProfile: UserProfile,
        travelPlan: TravelPlan
    ) async throws -> [SuggestedItem] {
        let historyInfo = userProfile.travelHistory.prefix(3).map { record in
            "- \(record.destination) (\(record.purpose.displayName)): 满意度\(record.satisfaction)/5"
        }.joined(separator: "\n")
        
        let prompt = """
        基于用户档案和旅行计划，提供个性化的物品建议：
        
        用户偏好：
        - 装箱风格：\(userProfile.preferences.packingStyle.displayName)
        - 预算水平：\(userProfile.preferences.budgetLevel.displayName)
        - 旅行频率：\(userProfile.preferences.travelFrequency.displayName)
        
        最近旅行记录：
        \(historyInfo)
        
        本次旅行计划：
        - 目的地：\(travelPlan.destination)
        - 天数：\(travelPlan.duration)
        - 季节：\(travelPlan.season)
        - 活动：\(travelPlan.activities.joined(separator: "、"))
        
        请以JSON数组格式返回个性化建议：
        [
            {
                "name": "物品名称",
                "category": "类别",
                "importance": "essential/important/recommended/optional",
                "reason": "个性化推荐理由",
                "quantity": 数量,
                "estimatedWeight": 预估重量,
                "estimatedVolume": 预估体积
            }
        ]
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的个性化旅行顾问，能够根据用户的历史偏好和旅行记录提供精准的个性化建议。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseSuggestedItems(from: content)
    }
    
    // MARK: - 遗漏检查功能
    
    /// 检查遗漏物品
    /// - Parameters:
    ///   - checklist: 当前清单
    ///   - travelPlan: 旅行计划
    /// - Returns: 遗漏物品警告
    func checkMissingItems(
        checklist: [LuggageItem],
        travelPlan: TravelPlan
    ) async throws -> [MissingItemAlert] {
        let currentItems = checklist.map { $0.name }.joined(separator: "、")
        
        let prompt = """
        检查以下旅行清单是否有重要物品遗漏：
        
        旅行信息：
        - 目的地：\(travelPlan.destination)
        - 天数：\(travelPlan.duration)
        - 季节：\(travelPlan.season)
        - 活动：\(travelPlan.activities.joined(separator: "、"))
        
        当前清单：\(currentItems)
        
        请以JSON数组格式返回可能遗漏的重要物品：
        [
            {
                "itemName": "物品名称",
                "category": "类别",
                "importance": "essential/important/recommended/optional",
                "reason": "为什么重要",
                "suggestion": "具体建议"
            }
        ]
        
        只返回真正重要且可能被遗漏的物品。
        """
        
        let messages = [
            ChatMessage.system("你是一个细心的旅行检查专家，能够发现旅行清单中可能遗漏的重要物品。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseMissingItemAlerts(from: content)
    }
    
    // MARK: - 重量预测功能
    
    /// 预测行李重量
    /// - Parameter items: 物品列表
    /// - Returns: 重量预测结果
    func predictWeight(items: [LuggageItem]) async throws -> WeightPrediction {
        let itemsInfo = items.map { item in
            "- \(item.name): \(item.weight)g"
        }.joined(separator: "\n")
        
        let prompt = """
        分析以下物品清单的重量分布和预测：
        
        \(itemsInfo)
        
        请以JSON格式返回分析结果：
        {
            "totalWeight": 总重量,
            "breakdown": [
                {
                    "category": "类别",
                    "weight": 重量,
                    "percentage": 百分比
                }
            ],
            "warnings": ["重量警告"],
            "suggestions": ["减重建议"],
            "confidence": 预测置信度
        }
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的重量分析专家，能够准确分析物品重量分布并提供优化建议。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseWeightPrediction(from: content)
    }
    
    // MARK: - 替代品建议功能
    
    /// 建议替代品
    /// - Parameters:
    ///   - item: 原物品
    ///   - constraints: 约束条件
    /// - Returns: 替代品列表
    func suggestAlternatives(
        for item: LuggageItem,
        constraints: PackingConstraints
    ) async throws -> [ItemInfo] {
        let prompt = """
        为物品"\(item.name)"（重量：\(item.weight)g，体积：\(item.volume)cm³）推荐替代品。
        
        约束条件：
        - 最大重量：\(constraints.maxWeight)g
        - 最大体积：\(constraints.maxVolume)cm³
        - 限制条件：\(constraints.restrictions.joined(separator: "、"))
        
        请以JSON数组格式返回替代品建议：
        [
            {
                "name": "替代品名称",
                "category": "\(item.category.rawValue)",
                "weight": 重量（克），
                "volume": 体积（立方厘米），
                "dimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "confidence": 置信度（0.0-1.0），
                "alternatives": [],
                "reason": "推荐理由"
            }
        ]
        
        请推荐2-4个符合约束条件的替代品。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品替代建议专家，能够根据约束条件推荐合适的替代品。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfoArray(from: content)
    }
    
    // MARK: - 航空公司政策查询功能
    
    /// 查询航空公司行李政策
    /// - Parameters:
    ///   - airline: 航空公司名称
    ///   - flightType: 航班类型（国内/国际）
    ///   - cabinClass: 舱位等级（经济舱/商务舱/头等舱）
    /// - Returns: 航空公司行李政策
    func queryAirlinePolicy(
        airline: String,
        flightType: FlightType = .international,
        cabinClass: CabinClass = .economy
    ) async throws -> AirlineLuggagePolicy {
        let prompt = """
        请查询\(airline)航空公司的行李政策信息，航班类型：\(flightType.displayName)，舱位：\(cabinClass.displayName)。
        
        请以JSON格式返回详细的行李政策信息：
        {
            "airline": "\(airline)",
            "carryOnWeight": 手提行李重量限制（千克，数值类型），
            "carryOnDimensions": {
                "length": 长度（厘米），
                "width": 宽度（厘米），
                "height": 高度（厘米）
            },
            "checkedWeight": 托运行李重量限制（千克，数值类型），
            "checkedDimensions": {
                "length": 长度（厘米），
                "width": 宽度（厘米），
                "height": 高度（厘米）
            },
            "restrictions": [
                "具体限制条款1",
                "具体限制条款2",
                "液体限制规定",
                "电池物品规定",
                "禁止携带物品"
            ],
            "lastUpdated": "2024-01-01T00:00:00Z",
            "source": "官方网站或权威来源"
        }
        
        请提供最新、准确的政策信息，包括：
        1. 手提行李和托运行李的重量、尺寸限制
        2. 液体、电池、易燃易爆物品的具体规定
        3. 特殊物品（运动器材、乐器等）的政策
        4. 超重超尺寸的收费标准
        5. 最新的政策更新时间
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的航空政策查询专家，具有最新的航空公司行李政策知识。请提供准确、详细的政策信息，并始终返回有效的JSON格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseAirlinePolicy(from: content)
    }
    
    /// 批量查询多个航空公司政策
    /// - Parameters:
    ///   - airlines: 航空公司列表
    ///   - flightType: 航班类型
    ///   - cabinClass: 舱位等级
    /// - Returns: 航空公司政策列表
    func batchQueryAirlinePolicies(
        airlines: [String],
        flightType: FlightType = .international,
        cabinClass: CabinClass = .economy
    ) async throws -> [AirlineLuggagePolicy] {
        guard !airlines.isEmpty else {
            throw APIError.insufficientData
        }
        
        let airlinesList = airlines.enumerated().map { index, airline in
            "\(index + 1). \(airline)"
        }.joined(separator: "\n")
        
        let prompt = """
        请批量查询以下航空公司的行李政策，航班类型：\(flightType.displayName)，舱位：\(cabinClass.displayName)：
        
        \(airlinesList)
        
        请以JSON数组格式返回所有航空公司的政策信息：
        [
            {
                "airline": "航空公司名称",
                "carryOnWeight": 手提行李重量限制（千克），
                "carryOnDimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "checkedWeight": 托运行李重量限制（千克），
                "checkedDimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "restrictions": ["限制条款列表"],
                "lastUpdated": "2024-01-01T00:00:00Z",
                "source": "信息来源"
            }
        ]
        
        请为每个航空公司提供准确的政策信息。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的航空政策查询专家，能够批量处理多个航空公司的政策查询。请返回有效的JSON数组格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseAirlinePolicyArray(from: content)
    }
    
    /// 检查物品是否符合航空公司政策
    /// - Parameters:
    ///   - items: 物品列表
    ///   - policy: 航空公司政策
    /// - Returns: 政策检查结果
    func checkItemsAgainstPolicy(
        items: [LuggageItem],
        policy: AirlineLuggagePolicy
    ) async throws -> PolicyCheckResult {
        let itemsInfo = items.map { item in
            "- \(item.name) (\(item.category.displayName)): \(item.weight)g, \(item.volume)cm³"
        }.joined(separator: "\n")
        
        let prompt = """
        请检查以下物品是否符合\(policy.airline)的行李政策：
        
        物品清单：
        \(itemsInfo)
        
        航空公司政策：
        - 手提行李重量限制：\(policy.carryOnWeight)kg
        - 手提行李尺寸限制：\(policy.carryOnDimensions.length)×\(policy.carryOnDimensions.width)×\(policy.carryOnDimensions.height)cm
        - 托运行李重量限制：\(policy.checkedWeight)kg
        - 托运行李尺寸限制：\(policy.checkedDimensions.length)×\(policy.checkedDimensions.width)×\(policy.checkedDimensions.height)cm
        - 限制条款：\(policy.restrictions.joined(separator: "；"))
        
        请以JSON格式返回检查结果：
        {
            "overallCompliance": true/false,
            "violations": [
                {
                    "itemName": "违规物品名称",
                    "violationType": "overweight/oversized/prohibited/restricted",
                    "description": "具体违规描述",
                    "severity": "low/medium/high/critical",
                    "suggestion": "解决建议"
                }
            ],
            "warnings": [
                {
                    "itemName": "物品名称",
                    "warningType": "attention/caution",
                    "message": "警告信息",
                    "suggestion": "建议"
                }
            ],
            "recommendations": [
                "整体建议1",
                "整体建议2"
            ],
            "estimatedFees": {
                "overweightFee": 超重费用（数值），
                "oversizeFee": 超尺寸费用（数值），
                "currency": "货币单位"
            }
        }
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的航空政策合规检查专家，能够准确识别物品是否符合航空公司政策并提供解决建议。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parsePolicyCheckResult(from: content)
    }
}