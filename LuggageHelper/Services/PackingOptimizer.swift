import Foundation

/// 装箱优化器
/// 提供基于物品体积、重量和优先级的装箱优化算法
class PackingOptimizer {
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = PackingOptimizer()
    
    /// 私有初始化
    private init() {}
    
    // MARK: - 装箱优化
    
    /// 优化装箱方案
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    ///   - airline: 航空公司（可选）
    /// - Returns: 装箱计划
    func optimizePacking(
        items: [LuggageItem],
        luggage: Luggage,
        airline: Airline? = nil
    ) -> PackingPlan {
        // 计算总重量和体积
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        
        // 计算空间利用率
        let efficiency = min(1.0, totalVolume / luggage.capacity)
        
        // 生成增强的装箱警告
        let warnings = generateEnhancedWarnings(items: items, luggage: luggage, airline: airline, totalWeight: totalWeight, totalVolume: totalVolume)
        
        // 使用增强的装箱顺序优化算法
        let packingItems = optimizePackingOrderEnhanced(items: items, luggage: luggage, airline: airline)
        
        // 生成智能装箱建议
        let suggestions = generateSmartPackingSuggestions(items: items, luggage: luggage, efficiency: efficiency, warnings: warnings)
        
        // 创建装箱计划
        return PackingPlan(
            luggageId: luggage.id,
            items: packingItems,
            totalWeight: totalWeight,
            totalVolume: totalVolume,
            efficiency: efficiency,
            warnings: warnings,
            suggestions: suggestions
        )
    }
    
    /// 生成增强的装箱警告
    private func generateEnhancedWarnings(
        items: [LuggageItem],
        luggage: Luggage,
        airline: Airline?,
        totalWeight: Double,
        totalVolume: Double
    ) -> [PackingWarning] {
        var warnings: [PackingWarning] = []
        
        // 检查超重 - 更精确的重量限制检查
        let totalWeightWithLuggage = totalWeight + (luggage.emptyWeight * 1000) // 转换为克
        
        if let airline = airline {
            let weightLimit = luggage.getWeightLimit(airline: airline) ?? 23000 // 默认23kg
            let weightLimitInGrams = weightLimit * 1000
            
            if totalWeightWithLuggage > weightLimitInGrams {
                let overweight = (totalWeightWithLuggage - weightLimitInGrams) / 1000
                let severity: WarningSeverity = overweight > 5.0 ? .critical : (overweight > 2.0 ? .high : .medium)
                warnings.append(PackingWarning(
                    type: .overweight,
                    message: "超重 \(String(format: "%.1f", overweight))kg，航司限重 \(String(format: "%.0f", weightLimit))kg",
                    severity: severity
                ))
            } else if totalWeightWithLuggage > weightLimitInGrams * 0.9 {
                // 接近重量限制时的预警
                let remaining = (weightLimitInGrams - totalWeightWithLuggage) / 1000
                warnings.append(PackingWarning(
                    type: .overweight,
                    message: "接近重量限制，还可增加 \(String(format: "%.1f", remaining))kg",
                    severity: .low
                ))
            }
        } else {
            // 没有航司信息时使用通用限制
            let standardLimit = 23000.0 // 23kg标准限制
            if totalWeightWithLuggage > standardLimit {
                let overweight = (totalWeightWithLuggage - standardLimit) / 1000
                warnings.append(PackingWarning(
                    type: .overweight,
                    message: "超过标准限重 \(String(format: "%.1f", overweight))kg（23kg标准）",
                    severity: overweight > 5.0 ? .high : .medium
                ))
            }
        }
        
        // 检查超尺寸 - 更详细的容量分析
        if totalVolume > luggage.capacity {
            let overVolume = totalVolume - luggage.capacity
            let overPercentage = (overVolume / luggage.capacity) * 100
            let severity: WarningSeverity = overPercentage > 50 ? .critical : (overPercentage > 20 ? .high : .medium)
            warnings.append(PackingWarning(
                type: .oversized,
                message: "超出容量 \(String(format: "%.0f", overVolume))cm³（\(String(format: "%.1f", overPercentage))%），建议移除部分物品",
                severity: severity
            ))
        } else if totalVolume > luggage.capacity * 0.95 {
            // 接近容量限制时的预警
            let remaining = luggage.capacity - totalVolume
            warnings.append(PackingWarning(
                type: .oversized,
                message: "接近容量限制，剩余空间 \(String(format: "%.0f", remaining))cm³",
                severity: .low
            ))
        }
        
        // 检查易碎物品
        let fragileItems = ItemAnalysisUtils.filterItems(items, by: .fragile)
        if !fragileItems.isEmpty {
            let severity: WarningSeverity = fragileItems.count > 3 ? .high : .medium
            warnings.append(PackingWarning(
                type: .fragile,
                message: "包含 \(fragileItems.count) 件易碎物品：\(fragileItems.prefix(3).map { $0.name }.joined(separator: "、"))等",
                severity: severity
            ))
        }
        
        // 检查液体物品
        let liquidItems = ItemAnalysisUtils.filterItems(items, by: .liquid)
        if !liquidItems.isEmpty {
            warnings.append(PackingWarning(
                type: .liquid,
                message: "包含 \(liquidItems.count) 件液体物品，请确保符合航空限制（单瓶≤100ml，总量≤1L）",
                severity: .medium
            ))
        }
        
        // 检查电池物品
        let batteryItems = ItemAnalysisUtils.filterItems(items, by: .battery)
        if !batteryItems.isEmpty {
            warnings.append(PackingWarning(
                type: .battery,
                message: "包含 \(batteryItems.count) 件电池物品，锂电池需随身携带，不可托运",
                severity: .medium
            ))
        }
        
        // 检查重量分布不均
        let heavyItems = items.filter { $0.weight > 1000 } // 超过1kg的物品
        if heavyItems.count > items.count / 2 {
            warnings.append(PackingWarning(
                type: .overweight,
                message: "重物较多（\(heavyItems.count)件），注意重量分布和搬运安全",
                severity: .low
            ))
        }
        
        return warnings
    }
    
    /// 增强的装箱顺序优化算法
    private func optimizePackingOrderEnhanced(
        items: [LuggageItem],
        luggage: Luggage,
        airline: Airline?
    ) -> [PackingItem] {
        // 按多个维度对物品进行分析和排序
        let analyzedItems = items.map { item -> (item: LuggageItem, analysis: ItemAnalysis) in
            let analysis = analyzeItem(item)
            return (item: item, analysis: analysis)
        }
        
        // 按类别和特性分组
        let categorizedItems = Dictionary(grouping: analyzedItems) { $0.item.category }
        
        // 增强的装箱规则，考虑更多因素
        let packingRules: [(ItemCategory, PackingPosition, Int, String)] = [
            // (类别, 位置, 基础优先级, 原因)
            (.documents, .top, 10, "证件文件应放在顶部，方便安检和取用"),
            (.medicine, .top, 9, "药品应放在顶部，紧急时方便取用"),
            (.electronics, .middle, 8, "电子产品应放在中部，避免挤压和震动"),
            (.beauty, .top, 7, "美容用品应放在顶部，避免挤压变形"),
            (.toiletries, .top, 6, "洗漱用品应放在顶部，方便取用且防止泄漏"),
            (.accessories, .side, 5, "配饰可以放在侧面，填充空隙"),
            (.food, .top, 4, "食品应放在顶部，避免挤压"),
            (.clothing, .bottom, 3, "衣物应放在底部，可以作为缓冲层"),
            (.sports, .side, 3, "运动用品可以放在侧面或底部"),
            (.shoes, .bottom, 2, "鞋子应放在底部，避免压坏其他物品"),
            (.books, .bottom, 1, "书籍应放在底部，避免压坏其他物品"),
            (.other, .corner, 1, "其他物品可以放在角落，填充空隙")
        ]
        
        var packingItems: [PackingItem] = []
        
        // 按规则处理每个类别
        for (category, defaultPosition, basePriority, baseReason) in packingRules {
            if let categoryItems = categorizedItems[category] {
                for (item, analysis) in categoryItems {
                    // 根据物品特性调整位置和优先级
                    let (adjustedPosition, adjustedPriority, adjustedReason) = adjustPackingStrategy(
                        item: item,
                        analysis: analysis,
                        defaultPosition: defaultPosition,
                        basePriority: basePriority,
                        baseReason: baseReason
                    )
                    
                    packingItems.append(PackingItem(
                        itemId: item.id,
                        position: adjustedPosition,
                        priority: adjustedPriority,
                        reason: adjustedReason
                    ))
                }
            }
        }
        
        // 处理未分类的物品
        let packedItemIds = Set(packingItems.map { $0.itemId })
        let allItemIds = Set(items.map { $0.id })
        let missingItemIds = allItemIds.subtracting(packedItemIds)
        
        for itemId in missingItemIds {
            if let item = items.first(where: { $0.id == itemId }) {
                packingItems.append(PackingItem(
                    itemId: item.id,
                    position: .corner,
                    priority: 1,
                    reason: "未分类物品，放在角落填充空隙"
                ))
            }
        }
        
        // 按优先级排序，确保高优先级物品优先处理
        return packingItems.sorted { $0.priority > $1.priority }
    }
    
    /// 物品分析结构（使用共享工具类）
    private typealias ItemAnalysis = ItemAnalysisUtils.ItemAnalysis
    
    /// 分析物品特性
    private func analyzeItem(_ item: LuggageItem) -> ItemAnalysisUtils.ItemAnalysis {
        return ItemAnalysisUtils.analyzeItem(item)
    }
    
    /// 根据物品特性调整装箱策略
    private func adjustPackingStrategy(
        item: LuggageItem,
        analysis: ItemAnalysis,
        defaultPosition: PackingPosition,
        basePriority: Int,
        baseReason: String
    ) -> (PackingPosition, Int, String) {
        var position = defaultPosition
        var priority = basePriority
        var reason = baseReason
        
        // 易碎物品调整
        if analysis.isFragile {
            position = .middle // 易碎品放中间
            priority += 2
            reason += "，易碎品需要衣物保护"
        }
        
        // 重物调整
        if analysis.isHeavy {
            position = .bottom // 重物放底部
            priority += 1
            reason += "，重物放底部保持重心稳定"
        }
        
        // 贵重物品调整
        if analysis.isValuable {
            priority += 3
            reason += "，贵重物品建议随身携带"
        }
        
        // 液体物品调整
        if analysis.isLiquid {
            position = .top // 液体放顶部，防止泄漏
            priority += 1
            reason += "，液体物品需密封并符合航空限制"
        }
        
        // 电池物品调整
        if analysis.isBattery {
            priority += 2
            reason += "，电池物品需遵循航空安全规定"
        }
        
        // 常用物品调整
        if analysis.isFrequentlyUsed {
            if position == .bottom {
                position = .top // 常用物品放顶部
            }
            priority += 1
            reason += "，常用物品方便取用"
        }
        
        // 确保优先级在合理范围内
        priority = min(10, max(1, priority))
        
        return (position, priority, reason)
    }
    
    /// 生成智能装箱建议
    private func generateSmartPackingSuggestions(
        items: [LuggageItem],
        luggage: Luggage,
        efficiency: Double,
        warnings: [PackingWarning]
    ) -> [String] {
        var suggestions: [String] = []
        
        // 基于空间利用率的建议
        if efficiency < 0.5 {
            suggestions.append("空间利用率较低（\(String(format: "%.1f", efficiency * 100))%），可以考虑使用更小的行李箱")
            suggestions.append("利用鞋内空间放置袜子、内衣等小物品")
        } else if efficiency > 0.9 {
            suggestions.append("空间接近饱和，建议使用真空压缩袋压缩衣物")
            suggestions.append("考虑将部分物品分装到随身包中")
        }
        
        // 基于物品类型的建议
        let categorizedItems = Dictionary(grouping: items) { $0.category }
        
        // 衣物建议
        if let clothingItems = categorizedItems[.clothing], clothingItems.count > 5 {
            suggestions.append("衣物较多，建议卷起来放置而不是折叠，可节省30%空间")
            suggestions.append("选择多功能衣物，一件衣服多种搭配")
        }
        
        // 电子产品建议
        if let electronicsItems = categorizedItems[.electronics], electronicsItems.count > 3 {
            suggestions.append("电子产品较多，建议使用专用收纳包，避免相互摩擦")
            suggestions.append("充电线和配件可以用小袋子分类收纳")
        }
        
        // 鞋类建议
        if let shoeItems = categorizedItems[.shoes], shoeItems.count > 2 {
            suggestions.append("多双鞋子可以套装收纳，节省空间")
            suggestions.append("鞋内可以放置袜子、充电器等小物品")
        }
        
        // 基于警告的建议
        for warning in warnings {
            switch warning.type {
            case .overweight:
                suggestions.append("当前行李超重，建议移除一些重物或分散到其他行李中")
            case .oversized:
                suggestions.append("当前行李尺寸超标，建议重新整理或更换更大的行李箱")
            case .fragile:
                suggestions.append("建议为易碎物品添加额外保护，如泡沫包装或衣物包裹")
            case .liquid:
                suggestions.append("请确保液体容器符合航空公司规定，建议使用密封袋包装")
            case .battery:
                suggestions.append("锂电池需要特殊处理，建议随身携带并确保电量适中")
            case .prohibited:
                suggestions.append("检测到可能的禁止物品，请确认是否符合航空公司规定")
            case .attention:
                suggestions.append("此物品需要特别注意，请查看相关规定")
            }
        }
        
        // 通用装箱技巧
        suggestions.append("重物放底部，轻物放顶部，保持行李箱重心稳定")
        suggestions.append("常用物品放在容易取到的位置")
        suggestions.append("预留一些空间用于旅行中的购物")
        
        return suggestions
    }
    
    /// 优化装箱顺序
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    /// - Returns: 装箱物品列表
    private func optimizePackingOrder(
        items: [LuggageItem],
        luggage: Luggage
    ) -> [PackingItem] {
        // 按类别分组
        let categorizedItems = Dictionary(grouping: items) { $0.category }
        
        // 装箱顺序和位置规则
        let packingRules: [(ItemCategory, PackingPosition, Int, String)] = [
            // (类别, 位置, 优先级, 原因)
            (.clothing, .bottom, 3, "衣物应放在底部，可以作为缓冲层"),
            (.shoes, .bottom, 2, "鞋子应放在底部，避免压坏其他物品"),
            (.electronics, .middle, 8, "电子产品应放在中部，避免挤压"),
            (.toiletries, .top, 5, "洗漱用品应放在顶部，方便取用"),
            (.documents, .top, 10, "证件文件应放在顶部，方便取用"),
            (.medicine, .top, 9, "药品应放在顶部，方便取用"),
            (.accessories, .side, 6, "配饰可以放在侧面，填充空隙"),
            (.books, .bottom, 1, "书籍应放在底部，避免压坏其他物品"),
            (.food, .top, 4, "食品应放在顶部，避免挤压"),
            (.sports, .side, 3, "运动用品可以放在侧面或底部"),
            (.beauty, .top, 7, "美容用品应放在顶部，避免挤压"),
            (.other, .corner, 1, "其他物品可以放在角落，填充空隙")
        ]
        
        // 创建装箱物品列表
        var packingItems: [PackingItem] = []
        
        // 按规则添加物品
        for (category, position, priority, reason) in packingRules {
            if let items = categorizedItems[category] {
                for item in items {
                    packingItems.append(PackingItem(
                        itemId: item.id,
                        position: position,
                        priority: priority,
                        reason: reason
                    ))
                }
            }
        }
        
        // 检查是否有遗漏的物品
        let packedItemIds = Set(packingItems.map { $0.itemId })
        let allItemIds = Set(items.map { $0.id })
        let missingItemIds = allItemIds.subtracting(packedItemIds)
        
        // 添加遗漏的物品
        for itemId in missingItemIds {
            if let item = items.first(where: { $0.id == itemId }) {
                packingItems.append(PackingItem(
                    itemId: item.id,
                    position: .corner,
                    priority: 1,
                    reason: "其他物品，放在角落填充空隙"
                ))
            }
        }
        
        return packingItems
    }
    
    /// 生成装箱建议
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    /// - Returns: 装箱建议
    private func generatePackingSuggestions(
        items: [LuggageItem],
        luggage: Luggage
    ) -> [String] {
        var suggestions: [String] = []
        
        // 检查是否有易碎物品
        let fragileItems = items.filter { item in
            // 这里简化处理，实际应该有更复杂的判断
            return item.category == .electronics || item.name.contains("易碎")
        }
        
        if !fragileItems.isEmpty {
            suggestions.append("易碎物品应放在中部，用衣物包裹保护")
        }
        
        // 检查是否有液体物品
        let liquidItems = items.filter { item in
            // 这里简化处理，实际应该有更复杂的判断
            return item.category == .toiletries || item.name.contains("液体")
        }
        
        if !liquidItems.isEmpty {
            suggestions.append("液体物品应密封放置，避免泄漏")
        }
        
        // 检查是否有重物
        let heavyItems = items.filter { $0.weight > 1000 } // 超过1kg的物品
        
        if !heavyItems.isEmpty {
            suggestions.append("重物应放在行李箱底部靠近轮子的位置，保持稳定")
        }
        
        // 检查是否有贵重物品
        let valuableItems = items.filter { item in
            // 这里简化处理，实际应该有更复杂的判断
            return item.category == .electronics || item.category == .documents
        }
        
        if !valuableItems.isEmpty {
            suggestions.append("贵重物品建议随身携带，不要托运")
        }
        
        // 空间优化建议
        if items.count > 10 {
            suggestions.append("衣物可以卷起来放置，节省空间")
            suggestions.append("使用真空压缩袋可以减少衣物体积")
            suggestions.append("小物品可以放在鞋子内部，充分利用空间")
        }
        
        return suggestions
    }
    
    // MARK: - 重量优化
    
    /// 优化重量分布
    /// - Parameters:
    ///   - items: 物品列表
    ///   - maxWeight: 最大重量限制
    /// - Returns: 优化后的物品分组
    func optimizeWeightDistribution(
        items: [LuggageItem],
        maxWeight: Double
    ) -> [[LuggageItem]] {
        // 计算总重量
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        
        // 如果总重量不超过限制，直接返回
        if totalWeight <= maxWeight {
            return [items]
        }
        
        // 按重要性和重量排序
        let sortedItems = items.sorted { (item1, item2) -> Bool in
            // 这里简化处理，实际应该有更复杂的判断
            // 优先考虑类别重要性
            let priority1 = getCategoryPriority(item1.category)
            let priority2 = getCategoryPriority(item2.category)
            
            if priority1 != priority2 {
                return priority1 > priority2
            }
            
            // 其次考虑重量，优先放入重的物品
            return item1.weight > item2.weight
        }
        
        // 贪心算法：尽可能将物品放入第一个行李箱
        var groups: [[LuggageItem]] = [[]]
        var currentWeight = 0.0
        
        for item in sortedItems {
            if currentWeight + item.weight <= maxWeight {
                // 放入当前行李箱
                groups[0].append(item)
                currentWeight += item.weight
            } else {
                // 创建新的行李箱
                groups.append([item])
                currentWeight = item.weight
            }
        }
        
        return groups
    }
    
    /// 获取类别优先级
    /// - Parameter category: 物品类别
    /// - Returns: 优先级（1-10，越高越重要）
    private func getCategoryPriority(_ category: ItemCategory) -> Int {
        switch category {
        case .documents: return 10
        case .medicine: return 9
        case .electronics: return 8
        case .toiletries: return 7
        case .clothing: return 6
        case .accessories: return 5
        case .shoes: return 4
        case .food: return 3
        case .books: return 2
        case .sports, .beauty, .other: return 1
        }
    }
    
    // MARK: - 物品特性分析方法（使用共享工具类）
    
    /// 判断是否为易碎物品
    private func isFragileItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isFragileItem(item)
    }
    
    /// 判断是否为液体物品
    private func isLiquidItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isLiquidItem(item)
    }
    
    /// 判断是否为贵重物品
    private func isValuableItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isValuableItem(item)
    }
    
    /// 判断是否为电池物品
    private func isBatteryItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isBatteryItem(item)
    }
    
    /// 判断是否为常用物品
    private func isFrequentlyUsedItem(_ item: LuggageItem) -> Bool {
        return ItemAnalysisUtils.isFrequentlyUsedItem(item)
    }
    
    // MARK: - 装箱分析
    
    /// 分析装箱方案
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    /// - Returns: 装箱分析结果
    func analyzePackingPlan(
        items: [LuggageItem],
        luggage: Luggage
    ) -> PackingAnalysis {
        // 计算总重量和体积
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        
        // 计算空间利用率
        let utilizationRate = min(1.0, totalVolume / luggage.capacity)
        
        // 按类别分组
        let categorizedItems = Dictionary(grouping: items) { $0.category }
        
        // 创建类别分析
        var categoryBreakdown: [PackingCategoryAnalysis] = []
        
        for (category, categoryItems) in categorizedItems {
            let categoryWeight = categoryItems.reduce(0) { $0 + $1.weight }
            let categoryVolume = categoryItems.reduce(0) { $0 + $1.volume }
            
            let weightPercentage = totalWeight > 0 ? categoryWeight / totalWeight : 0
            let volumePercentage = totalVolume > 0 ? categoryVolume / totalVolume : 0
            
            let averageItemWeight = categoryWeight / Double(categoryItems.count)
            let averageItemVolume = categoryVolume / Double(categoryItems.count)
            
            categoryBreakdown.append(PackingCategoryAnalysis(
                category: category,
                itemCount: categoryItems.count,
                totalWeight: categoryWeight,
                totalVolume: categoryVolume,
                weightPercentage: weightPercentage,
                volumePercentage: volumePercentage,
                averageItemWeight: averageItemWeight,
                averageItemVolume: averageItemVolume
            ))
        }
        
        // 生成装箱警告
        let warnings = generatePackingWarnings(items: items, luggage: luggage)
        
        // 生成智能建议
        let recommendations = generateSmartRecommendations(
            items: items,
            luggage: luggage,
            utilizationRate: utilizationRate
        )
        
        // 计算装箱评分
        let score = calculatePackingScore(
            items: items,
            luggage: luggage,
            utilizationRate: utilizationRate,
            warnings: warnings
        )
        
        return PackingAnalysis(
            luggageId: luggage.id,
            totalItems: items.count,
            totalWeight: totalWeight,
            totalVolume: totalVolume,
            utilizationRate: utilizationRate,
            categoryBreakdown: categoryBreakdown,
            recommendations: recommendations,
            warnings: warnings,
            score: score
        )
    }
    
    /// 生成装箱警告
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    /// - Returns: 装箱警告列表
    private func generatePackingWarnings(
        items: [LuggageItem],
        luggage: Luggage
    ) -> [PackingWarning] {
        var warnings: [PackingWarning] = []
        
        // 计算总重量和体积
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        
        // 检查超重
        if totalWeight > 23000 { // 假设23kg是标准限制
            warnings.append(PackingWarning(
                type: .overweight,
                message: "行李总重量超过23kg，可能需要支付超重费用",
                severity: totalWeight > 30000 ? .high : .medium
            ))
        }
        
        // 检查超尺寸
        if totalVolume > luggage.capacity {
            warnings.append(PackingWarning(
                type: .oversized,
                message: "物品总体积超过行李箱容量，可能无法全部装入",
                severity: totalVolume > luggage.capacity * 1.2 ? .high : .medium
            ))
        }
        
        // 检查易碎物品
        let fragileItems = items.filter { item in
            return item.category == .electronics || item.name.contains("易碎")
        }
        
        if !fragileItems.isEmpty {
            warnings.append(PackingWarning(
                type: .fragile,
                message: "包含易碎物品，请妥善保护",
                severity: .medium
            ))
        }
        
        // 检查液体物品
        let liquidItems = items.filter { item in
            return item.category == .toiletries || item.name.contains("液体")
        }
        
        if !liquidItems.isEmpty {
            warnings.append(PackingWarning(
                type: .liquid,
                message: "包含液体物品，请确保密封并符合航空限制",
                severity: .medium
            ))
        }
        
        // 检查电池物品
        let batteryItems = items.filter { item in
            return item.category == .electronics || item.name.contains("电池")
        }
        
        if !batteryItems.isEmpty {
            warnings.append(PackingWarning(
                type: .battery,
                message: "包含电池物品，请遵循航空公司规定",
                severity: .medium
            ))
        }
        
        return warnings
    }
    
    /// 生成智能建议
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    ///   - utilizationRate: 空间利用率
    /// - Returns: 智能建议列表
    private func generateSmartRecommendations(
        items: [LuggageItem],
        luggage: Luggage,
        utilizationRate: Double
    ) -> [SmartSuggestion] {
        var recommendations: [SmartSuggestion] = []
        
        // 空间优化建议
        if utilizationRate < 0.7 {
            recommendations.append(SmartSuggestion(
                type: .spaceOptimization,
                title: "空间利用率偏低",
                description: "当前空间利用率为 \(String(format: "%.1f", utilizationRate * 100))%，可以考虑使用更小的行李箱或添加更多物品",
                priority: 5
            ))
        } else if utilizationRate > 0.95 {
            recommendations.append(SmartSuggestion(
                type: .spaceOptimization,
                title: "空间接近饱和",
                description: "当前空间利用率为 \(String(format: "%.1f", utilizationRate * 100))%，建议使用压缩袋或减少物品",
                priority: 7
            ))
        }
        
        // 重量优化建议
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        if totalWeight > 20000 { // 20kg
            recommendations.append(SmartSuggestion(
                type: .weightReduction,
                title: "行李重量接近限制",
                description: "当前重量为 \(String(format: "%.1f", totalWeight / 1000))kg，接近航空公司限制，建议减少重物",
                priority: 8
            ))
        }
        
        // 类别建议
        let categorizedItems = Dictionary(grouping: items) { $0.category }
        
        // 检查是否缺少必需品
        let essentialCategories: [ItemCategory] = [.documents, .medicine, .toiletries]
        for category in essentialCategories {
            if categorizedItems[category] == nil || categorizedItems[category]!.isEmpty {
                recommendations.append(SmartSuggestion(
                    type: .itemRecommendation,
                    title: "可能缺少必需品",
                    description: "未发现\(category.displayName)类物品，请确认是否需要添加",
                    priority: 9,
                    category: category
                ))
            }
        }
        
        return recommendations
    }
    
    /// 计算装箱评分
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱
    ///   - utilizationRate: 空间利用率
    ///   - warnings: 警告列表
    /// - Returns: 装箱评分（0-100）
    private func calculatePackingScore(
        items: [LuggageItem],
        luggage: Luggage,
        utilizationRate: Double,
        warnings: [PackingWarning]
    ) -> Double {
        // 基础分数
        var score = 80.0
        
        // 空间利用率评分
        if utilizationRate < 0.5 {
            score -= 10.0 // 利用率过低，扣分
        } else if utilizationRate > 0.95 {
            score -= 5.0 // 利用率过高，轻微扣分
        } else if utilizationRate >= 0.7 && utilizationRate <= 0.9 {
            score += 10.0 // 利用率适中，加分
        }
        
        // 警告扣分
        for warning in warnings {
            switch warning.severity {
            case .low:
                score -= 2.0
            case .medium:
                score -= 5.0
            case .high:
                score -= 10.0
            case .critical:
                score -= 20.0
            }
        }
        
        // 类别平衡评分
        let categorizedItems = Dictionary(grouping: items) { $0.category }
        if categorizedItems.count >= 5 {
            score += 5.0 // 类别多样性好，加分
        }
        
        // 确保分数在0-100范围内
        return min(100.0, max(0.0, score))
    }
}
