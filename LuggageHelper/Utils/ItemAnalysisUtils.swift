import Foundation

/// 物品分析工具类
/// 提供物品特性分析的共享方法
struct ItemAnalysisUtils {
    
    // MARK: - 物品特性分析
    
    /// 判断是否为易碎物品
    static func isFragileItem(_ item: LuggageItem) -> Bool {
        let fragileKeywords = ["玻璃", "陶瓷", "易碎", "镜子", "屏幕", "显示器", "相机", "镜头", "眼镜", "手表"]
        let itemNameLower = item.name.lowercased()
        return item.category == .electronics || 
               fragileKeywords.contains { itemNameLower.contains($0.lowercased()) }
    }
    
    /// 判断是否为液体物品
    static func isLiquidItem(_ item: LuggageItem) -> Bool {
        let liquidKeywords = ["洗发水", "沐浴露", "护肤", "化妆水", "精华", "乳液", "香水", "液体", "凝胶", "膏状", "洗面奶"]
        let itemNameLower = item.name.lowercased()
        return item.category == .toiletries || item.category == .beauty ||
               liquidKeywords.contains { itemNameLower.contains($0.lowercased()) }
    }
    
    /// 判断是否为贵重物品
    static func isValuableItem(_ item: LuggageItem) -> Bool {
        let valuableKeywords = ["手机", "电脑", "相机", "手表", "首饰", "证件", "护照", "身份证", "珠宝", "钻石"]
        let itemNameLower = item.name.lowercased()
        return item.category == .electronics || item.category == .documents ||
               valuableKeywords.contains { itemNameLower.contains($0.lowercased()) } ||
               item.weight > 500 // 重量超过500g的电子产品通常比较贵重
    }
    
    /// 判断是否为电池物品
    static func isBatteryItem(_ item: LuggageItem) -> Bool {
        let batteryKeywords = ["电池", "充电宝", "移动电源", "锂电池", "充电器", "电源", "battery"]
        let itemNameLower = item.name.lowercased()
        return item.category == .electronics ||
               batteryKeywords.contains { itemNameLower.contains($0.lowercased()) }
    }
    
    /// 判断是否为常用物品
    static func isFrequentlyUsedItem(_ item: LuggageItem) -> Bool {
        let frequentKeywords = ["手机", "充电器", "洗漱", "牙刷", "毛巾", "内衣", "袜子", "药品", "证件"]
        let itemNameLower = item.name.lowercased()
        return item.category == .documents || item.category == .medicine ||
               frequentKeywords.contains { itemNameLower.contains($0.lowercased()) }
    }
    
    // MARK: - 物品分析结构
    
    /// 物品分析结果
    struct ItemAnalysis {
        let isFragile: Bool
        let isLiquid: Bool
        let isHeavy: Bool
        let isValuable: Bool
        let isBattery: Bool
        let isFrequentlyUsed: Bool
        let weightRatio: Double // 重量占总重量的比例
        let volumeRatio: Double // 体积占总体积的比例
    }
    
    /// 分析物品特性
    static func analyzeItem(_ item: LuggageItem, totalWeight: Double = 0, totalVolume: Double = 0) -> ItemAnalysis {
        return ItemAnalysis(
            isFragile: isFragileItem(item),
            isLiquid: isLiquidItem(item),
            isHeavy: item.weight > 1000, // 超过1kg
            isValuable: isValuableItem(item),
            isBattery: isBatteryItem(item),
            isFrequentlyUsed: isFrequentlyUsedItem(item),
            weightRatio: totalWeight > 0 ? item.weight / totalWeight : 0,
            volumeRatio: totalVolume > 0 ? item.volume / totalVolume : 0
        )
    }
    
    // MARK: - 批量分析
    
    /// 批量分析物品特性
    static func analyzeItems(_ items: [LuggageItem]) -> [UUID: ItemAnalysis] {
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        
        var results: [UUID: ItemAnalysis] = [:]
        for item in items {
            results[item.id] = analyzeItem(item, totalWeight: totalWeight, totalVolume: totalVolume)
        }
        
        return results
    }
    
    /// 按特性筛选物品
    static func filterItems(_ items: [LuggageItem], by characteristic: ItemCharacteristic) -> [LuggageItem] {
        return items.filter { item in
            switch characteristic {
            case .fragile:
                return isFragileItem(item)
            case .liquid:
                return isLiquidItem(item)
            case .valuable:
                return isValuableItem(item)
            case .battery:
                return isBatteryItem(item)
            case .heavy:
                return item.weight > 1000
            case .frequentlyUsed:
                return isFrequentlyUsedItem(item)
            }
        }
    }
    
    /// 物品特性枚举
    enum ItemCharacteristic {
        case fragile        // 易碎
        case liquid         // 液体
        case valuable       // 贵重
        case battery        // 电池
        case heavy          // 重物
        case frequentlyUsed // 常用
        
        var displayName: String {
            switch self {
            case .fragile: return "易碎品"
            case .liquid: return "液体"
            case .valuable: return "贵重品"
            case .battery: return "电池"
            case .heavy: return "重物"
            case .frequentlyUsed: return "常用品"
            }
        }
        
        var icon: String {
            switch self {
            case .fragile: return "⚠️"
            case .liquid: return "💧"
            case .valuable: return "💎"
            case .battery: return "🔋"
            case .heavy: return "⚖️"
            case .frequentlyUsed: return "⭐"
            }
        }
    }
    
    // MARK: - 统计分析
    
    /// 生成物品特性统计
    static func generateCharacteristicStats(_ items: [LuggageItem]) -> [ItemCharacteristic: Int] {
        var stats: [ItemCharacteristic: Int] = [:]
        
        stats[.fragile] = filterItems(items, by: .fragile).count
        stats[.liquid] = filterItems(items, by: .liquid).count
        stats[.valuable] = filterItems(items, by: .valuable).count
        stats[.battery] = filterItems(items, by: .battery).count
        stats[.heavy] = filterItems(items, by: .heavy).count
        stats[.frequentlyUsed] = filterItems(items, by: .frequentlyUsed).count
        
        return stats
    }
    
    /// 生成安全检查报告
    static func generateSafetyReport(_ items: [LuggageItem]) -> SafetyReport {
        let fragileItems = filterItems(items, by: .fragile)
        let liquidItems = filterItems(items, by: .liquid)
        let valuableItems = filterItems(items, by: .valuable)
        let batteryItems = filterItems(items, by: .battery)
        
        var warnings: [String] = []
        var suggestions: [String] = []
        
        if !fragileItems.isEmpty {
            warnings.append("包含 \(fragileItems.count) 件易碎物品")
            suggestions.append("易碎物品建议用衣物包裹，放在行李箱中央")
        }
        
        if !liquidItems.isEmpty {
            warnings.append("包含 \(liquidItems.count) 件液体物品")
            suggestions.append("液体物品需符合航空限制（单瓶≤100ml，总量≤1L）")
        }
        
        if !valuableItems.isEmpty {
            warnings.append("包含 \(valuableItems.count) 件贵重物品")
            suggestions.append("贵重物品建议随身携带，不要托运")
        }
        
        if !batteryItems.isEmpty {
            warnings.append("包含 \(batteryItems.count) 件电池物品")
            suggestions.append("锂电池必须随身携带，不可托运")
        }
        
        return SafetyReport(
            warnings: warnings,
            suggestions: suggestions,
            fragileCount: fragileItems.count,
            liquidCount: liquidItems.count,
            valuableCount: valuableItems.count,
            batteryCount: batteryItems.count
        )
    }
    
    /// 安全检查报告
    struct SafetyReport {
        let warnings: [String]
        let suggestions: [String]
        let fragileCount: Int
        let liquidCount: Int
        let valuableCount: Int
        let batteryCount: Int
        
        var hasWarnings: Bool {
            return !warnings.isEmpty
        }
        
        var totalSpecialItems: Int {
            return fragileCount + liquidCount + valuableCount + batteryCount
        }
    }
}