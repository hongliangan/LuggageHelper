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
        
        // 生成装箱警告
        var warnings: [PackingWarning] = []
        
        // 检查超重
        if let airline = airline {
            let weightLimit = luggage.getWeightLimit(airline: airline) ?? 0
            if totalWeight > weightLimit {
                let overweight = totalWeight - weightLimit
                warnings.append(PackingWarning(
                    type: .overweight,
                    message: "超重 \(String(format: "%.1f", overweight))kg，限重 \(String(format: "%.1f", weightLimit))kg",
                    severity: overweight > 5.0 ? .high : .medium
                ))
            }
        }
        
        // 检查超尺寸
        if totalVolume > luggage.capacity {
            let overVolume = totalVolume - luggage.capacity
            warnings.append(PackingWarning(
                type: .oversized,
                message: "超出容量 \(String(format: "%.1f", overVolume))cm³，容量 \(String(format: "%.1f", luggage.capacity))cm³",
                severity: overVolume > luggage.capacity * 0.2 ? .high : .medium
            ))
        }
        
        // 优化装箱顺序
        let packingItems = optimizePackingOrder(items: items, luggage: luggage)
        
        // 生成装箱建议
        let suggestions = generatePackingSuggestions(items: items, luggage: luggage)
        
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
        var categoryBreakdown: [CategoryAnalysis] = []
        
        for (category, categoryItems) in categorizedItems {
            let categoryWeight = categoryItems.reduce(0) { $0 + $1.weight }
            let categoryVolume = categoryItems.reduce(0) { $0 + $1.volume }
            
            let weightPercentage = totalWeight > 0 ? categoryWeight / totalWeight : 0
            let volumePercentage = totalVolume > 0 ? categoryVolume / totalVolume : 0
            
            let averageItemWeight = categoryWeight / Double(categoryItems.count)
            let averageItemVolume = categoryVolume / Double(categoryItems.count)
            
            categoryBreakdown.append(CategoryAnalysis(
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