import Foundation
import UIKit
import SwiftUI

/// 物品信息搜索服务
/// 通过网络搜索物品的体积和重量信息，并集成 AI 识别功能
class ItemSearchService: ObservableObject {
    
    /// 搜索结果数据模型
    struct ItemSearchResult {
        let name: String
        let weight: Double?
        let volume: Double?
        let source: String
        let confidence: Double // 置信度 0-1
        let dimensions: Dimensions?
        let category: ItemCategory?
        
        init(name: String, weight: Double?, volume: Double?, source: String, confidence: Double, dimensions: Dimensions? = nil, category: ItemCategory? = nil) {
            self.name = name
            self.weight = weight
            self.volume = volume
            self.source = source
            self.confidence = confidence
            self.dimensions = dimensions
            self.category = category
        }
        
        /// 从 ItemInfo 创建搜索结果
        static func fromItemInfo(_ itemInfo: ItemInfo) -> ItemSearchResult {
            return ItemSearchResult(
                name: itemInfo.name,
                weight: itemInfo.weight / 1000, // 转换为 kg
                volume: itemInfo.volume / 1000, // 转换为 L
                source: itemInfo.source,
                confidence: itemInfo.confidence,
                dimensions: itemInfo.dimensions,
                category: itemInfo.category
            )
        }
        
        /// 转换为 ItemInfo
        func toItemInfo() -> ItemInfo {
            return ItemInfo(
                name: name,
                category: category ?? .other,
                weight: (weight ?? 0) * 1000, // 转换为克
                volume: (volume ?? 0) * 1000, // 转换为立方厘米
                dimensions: dimensions,
                confidence: confidence,
                source: source
            )
        }
    }
    
    // MARK: - 属性
    
    /// AI 服务
    private let aiService = AIServiceExtensions.shared
    
    /// 是否使用 AI 增强搜索
    var useAIEnhancedSearch = true
    
    /// 搜索物品信息
    /// - Parameter itemName: 物品名称
    /// - Returns: 搜索结果数组
    func searchItemInfo(itemName: String) async -> [ItemSearchResult] {
        // 首先尝试从本地数据库获取结果
        var results = getMockSearchResults(for: itemName)
        
        // 如果启用了 AI 增强搜索，并且本地结果不够精确，则使用 AI 服务
        if useAIEnhancedSearch && (results.isEmpty || results.first?.confidence ?? 0 < 0.9) {
            do {
                let aiResult = try await aiService.identifyItem(name: itemName)
                let aiSearchResult = ItemSearchResult.fromItemInfo(aiResult)
                
                // 将 AI 结果添加到结果列表的最前面
                results.insert(aiSearchResult, at: 0)
                
                // 添加替代品建议
                for alternative in aiResult.alternatives {
                    results.append(ItemSearchResult.fromItemInfo(alternative))
                }
            } catch {
                print("AI 识别失败: \(error)")
                // 失败时继续使用本地结果
            }
        }
        
        // 去重并按置信度排序
        let uniqueResults = removeDuplicates(from: results)
        
        return uniqueResults
    }
    
    /// 搜索物品信息（带型号）
    /// - Parameters:
    ///   - itemName: 物品名称
    ///   - model: 型号
    /// - Returns: 搜索结果数组
    func searchItemInfo(itemName: String, model: String?) async -> [ItemSearchResult] {
        if let model = model, !model.isEmpty {
            // 如果有型号，优先使用 AI 识别
            if useAIEnhancedSearch {
                do {
                    let aiResult = try await aiService.identifyItem(name: itemName, model: model)
                    var results = [ItemSearchResult.fromItemInfo(aiResult)]
                    
                    // 添加替代品建议
                    for alternative in aiResult.alternatives {
                        results.append(ItemSearchResult.fromItemInfo(alternative))
                    }
                    
                    return results
                } catch {
                    print("AI 识别失败: \(error)")
                    // 失败时回退到基本搜索
                }
            }
        }
        
        // 回退到基本搜索
        return await searchItemInfo(itemName: itemName)
    }
    
    /// 通过图片识别物品
    /// - Parameter imageData: 图片数据
    /// - Returns: 搜索结果
    func identifyItemFromPhoto(_ imageData: Data) async -> ItemSearchResult? {
        do {
            let aiResult = try await aiService.identifyItemFromPhoto(imageData)
            return ItemSearchResult.fromItemInfo(aiResult)
        } catch {
            print("照片识别失败: \(error)")
            return nil
        }
    }
    
    /// 分类物品
    /// - Parameter item: 物品
    /// - Returns: 物品类别
    func categorizeItem(_ item: LuggageItemProtocol) async -> ItemCategory? {
        guard useAIEnhancedSearch else {
            // 如果未启用 AI 增强搜索，尝试从本地数据库获取类别
            let mockResults = getMockSearchResults(for: item.name)
            return mockResults.first?.category
        }
        
        do {
            // 创建一个 LuggageItem 对象来传递给 aiService
            let luggageItem = LuggageItem(id: item.id, name: item.name, volume: item.volume, weight: item.weight)
            let category = try await aiService.categorizeItem(luggageItem)
            return category
        } catch {
            print("物品分类失败: \(error)")
            
            // 失败时尝试从本地数据库获取类别
            let mockResults = getMockSearchResults(for: item.name)
            return mockResults.first?.category
        }
    }
    
    /// 批量分类物品
    /// - Parameter items: 物品列表
    /// - Returns: 物品ID到类别的映射
    func batchCategorizeItems(_ items: [LuggageItemProtocol]) async -> [UUID: ItemCategory] {
        guard useAIEnhancedSearch else {
            // 如果未启用 AI 增强搜索，尝试从本地数据库获取类别
            var results: [UUID: ItemCategory] = [:]
            for item in items {
                let mockResults = getMockSearchResults(for: item.name)
                if let category = mockResults.first?.category {
                    results[item.id] = category
                }
            }
            return results
        }
        
        do {
            // 将 LuggageItemProtocol 转换为 LuggageItem 数组
            let luggageItems = items.map { item in
                LuggageItem(id: item.id, name: item.name, volume: item.volume, weight: item.weight)
            }
            let results = try await aiService.batchCategorizeItems(luggageItems)
            return results
        } catch {
            print("批量分类失败: \(error)")
            
            // 失败时尝试从本地数据库获取类别
            var results: [UUID: ItemCategory] = [:]
            for item in items {
                let mockResults = getMockSearchResults(for: item.name)
                if let category = mockResults.first?.category {
                    results[item.id] = category
                }
            }
            return results
        }
    }
    
    /// 生成物品标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    func generateItemTags(for item: LuggageItemProtocol) async -> [String] {
        guard useAIEnhancedSearch else {
            // 如果未启用 AI 增强搜索，返回一些基本标签
            return getBasicTags(for: item.name)
        }
        
        do {
            // 创建一个 LuggageItem 对象来传递给 aiService
            let luggageItem = LuggageItem(id: item.id, name: item.name, volume: item.volume, weight: item.weight)
            let tags = try await aiService.generateItemTags(for: luggageItem)
            return tags
        } catch {
            print("生成标签失败: \(error)")
            
            // 失败时返回一些基本标签
            return getBasicTags(for: item.name)
        }
    }
    
    /// 获取基本标签
    /// - Parameter itemName: 物品名称
    /// - Returns: 基本标签列表
    private func getBasicTags(for itemName: String) -> [String] {
        // 根据物品名称生成一些基本标签
        var tags: [String] = []
        
        // 添加物品名称作为标签
        tags.append(itemName)
        
        // 根据物品名称添加一些常见标签
        if itemName.contains("手机") || itemName.contains("iPhone") || itemName.contains("iPad") {
            tags.append("电子")
            tags.append("设备")
            tags.append("充电")
        } else if itemName.contains("衣") || itemName.contains("裤") || itemName.contains("鞋") {
            tags.append("穿着")
            tags.append("服装")
        } else if itemName.contains("书") || itemName.contains("笔") {
            tags.append("阅读")
            tags.append("文具")
        }
        
        return Array(Set(tags)) // 去重
    }
    
    /// 批量搜索物品信息
    /// - Parameter itemNames: 物品名称列表
    /// - Returns: 搜索结果字典
    func batchSearchItemInfo(itemNames: [String]) async -> [String: [ItemSearchResult]] {
        var results: [String: [ItemSearchResult]] = [:]
        
        // 并行处理多个搜索请求
        await withTaskGroup(of: (String, [ItemSearchResult]).self) { group in
            for itemName in itemNames {
                group.addTask {
                    let searchResults = await self.searchItemInfo(itemName: itemName)
                    return (itemName, searchResults)
                }
            }
            
            for await (itemName, searchResults) in group {
                results[itemName] = searchResults
            }
        }
        
        return results
    }
    
    // MARK: - 私有方法
    
    /// 获取模拟搜索结果
    private func getMockSearchResults(for itemName: String) -> [ItemSearchResult] {
        let commonItems: [String: (weight: Double, volume: Double, category: ItemCategory)] = [
            "iPhone": (0.2, 0.1, .electronics),
            "iPhone 13": (0.17, 0.08, .electronics),
            "iPhone 14": (0.17, 0.08, .electronics),
            "iPhone 15": (0.17, 0.08, .electronics),
            "iPad": (0.5, 0.5, .electronics),
            "iPad Pro": (0.65, 0.6, .electronics),
            "iPad Mini": (0.3, 0.3, .electronics),
            "MacBook": (1.4, 2.0, .electronics),
            "MacBook Air": (1.2, 1.8, .electronics),
            "MacBook Pro": (1.6, 2.2, .electronics),
            "充电器": (0.3, 0.2, .electronics),
            "充电宝": (0.4, 0.3, .electronics),
            "耳机": (0.05, 0.05, .electronics),
            "AirPods": (0.04, 0.02, .electronics),
            "T恤": (0.15, 0.5, .clothing),
            "衬衫": (0.25, 0.6, .clothing),
            "牛仔裤": (0.6, 1.0, .clothing),
            "短裤": (0.3, 0.5, .clothing),
            "运动鞋": (0.8, 2.5, .shoes),
            "皮鞋": (0.9, 2.0, .shoes),
            "凉鞋": (0.5, 1.5, .shoes),
            "洗发水": (0.4, 0.4, .toiletries),
            "沐浴露": (0.4, 0.4, .toiletries),
            "牙刷": (0.02, 0.02, .toiletries),
            "牙膏": (0.1, 0.05, .toiletries),
            "毛巾": (0.3, 0.8, .toiletries),
            "雨伞": (0.4, 0.3, .accessories),
            "水杯": (0.3, 0.5, .accessories),
            "保温杯": (0.35, 0.5, .accessories),
            "笔记本": (0.5, 0.8, .books),
            "书": (0.7, 1.0, .books),
            "钱包": (0.1, 0.1, .accessories),
            "太阳镜": (0.05, 0.1, .accessories),
            "护照": (0.05, 0.01, .documents),
            "身份证": (0.01, 0.001, .documents),
            "药品": (0.1, 0.1, .medicine),
            "感冒药": (0.05, 0.05, .medicine),
            "创可贴": (0.02, 0.01, .medicine),
            "化妆品": (0.2, 0.2, .beauty),
            "口红": (0.02, 0.01, .beauty),
            "粉底液": (0.05, 0.03, .beauty),
            "相机": (0.7, 1.0, .electronics),
            "单反相机": (1.2, 2.0, .electronics),
            "微单相机": (0.6, 0.8, .electronics),
            "三脚架": (1.0, 2.0, .electronics),
            "游泳衣": (0.2, 0.3, .clothing),
            "泳镜": (0.05, 0.1, .accessories),
            "帽子": (0.1, 0.5, .accessories),
            "围巾": (0.2, 0.4, .accessories),
            "手套": (0.1, 0.2, .accessories),
            "袜子": (0.05, 0.1, .clothing),
            "内衣": (0.1, 0.2, .clothing),
            "睡衣": (0.3, 0.7, .clothing),
            "外套": (0.8, 2.0, .clothing),
            "羽绒服": (1.0, 3.0, .clothing),
            "雨衣": (0.3, 0.5, .clothing),
            "登山鞋": (1.0, 2.5, .shoes),
            "拖鞋": (0.3, 1.0, .shoes),
            "手机充电器": (0.1, 0.1, .electronics),
            "笔记本充电器": (0.3, 0.3, .electronics),
            "转换插头": (0.1, 0.1, .electronics),
            "剃须刀": (0.2, 0.2, .toiletries),
            "防晒霜": (0.15, 0.1, .toiletries),
            "面膜": (0.1, 0.1, .beauty),
            "指甲刀": (0.02, 0.01, .toiletries),
            "梳子": (0.05, 0.05, .toiletries),
            "眼镜": (0.05, 0.05, .accessories),
            "隐形眼镜": (0.01, 0.01, .accessories),
            "隐形眼镜护理液": (0.15, 0.1, .toiletries),
            "纸巾": (0.1, 0.2, .toiletries),
            "湿巾": (0.15, 0.2, .toiletries),
            "垃圾袋": (0.05, 0.1, .accessories),
            "旅行枕": (0.3, 1.0, .accessories),
            "眼罩": (0.02, 0.05, .accessories),
            "耳塞": (0.01, 0.01, .accessories),
            "指南针": (0.05, 0.02, .accessories),
            "地图": (0.1, 0.1, .documents),
            "笔": (0.01, 0.01, .books),
            "笔记本电脑": (1.5, 2.0, .electronics),
            "平板电脑": (0.5, 0.5, .electronics),
            "电子书阅读器": (0.2, 0.2, .electronics),
            "相机电池": (0.05, 0.02, .electronics),
            "移动硬盘": (0.2, 0.1, .electronics),
            "U盘": (0.01, 0.01, .electronics),
            "SD卡": (0.01, 0.01, .electronics),
            "耳机适配器": (0.01, 0.01, .electronics),
            "蓝牙音箱": (0.3, 0.3, .electronics),
            "手表": (0.05, 0.02, .accessories),
            "智能手表": (0.05, 0.02, .electronics),
            "手环": (0.02, 0.01, .accessories),
            "项链": (0.02, 0.01, .accessories),
            "戒指": (0.01, 0.01, .accessories),
            "手链": (0.01, 0.01, .accessories),
            "耳环": (0.01, 0.01, .accessories),
            "发夹": (0.01, 0.01, .accessories),
            "发带": (0.01, 0.01, .accessories),
            "腰带": (0.1, 0.1, .accessories),
            "背包": (0.8, 20.0, .accessories),
            "手提包": (0.5, 10.0, .accessories),
            "钱包": (0.1, 0.1, .accessories),
            "护照包": (0.1, 0.1, .accessories),
            "行李牌": (0.02, 0.02, .accessories),
            "行李锁": (0.05, 0.02, .accessories),
            "行李绑带": (0.1, 0.1, .accessories),
            "行李秤": (0.2, 0.2, .accessories),
            "旅行支票": (0.01, 0.01, .documents),
            "信用卡": (0.01, 0.01, .documents),
            "现金": (0.01, 0.01, .documents),
            "驾照": (0.01, 0.01, .documents),
            "保险单": (0.01, 0.01, .documents),
            "酒店预订单": (0.01, 0.01, .documents),
            "机票": (0.01, 0.01, .documents),
            "火车票": (0.01, 0.01, .documents),
            "巧克力": (0.1, 0.1, .food),
            "饼干": (0.2, 0.3, .food),
            "水果": (0.5, 0.5, .food),
            "矿泉水": (0.5, 0.5, .food),
            "能量棒": (0.05, 0.05, .food),
            "坚果": (0.2, 0.2, .food),
            "口香糖": (0.02, 0.02, .food),
            "咖啡": (0.1, 0.1, .food),
            "茶包": (0.05, 0.05, .food),
            "速溶咖啡": (0.05, 0.05, .food),
            "运动水壶": (0.3, 0.5, .sports),
            "瑜伽垫": (1.0, 3.0, .sports),
            "跳绳": (0.1, 0.1, .sports),
            "健身手套": (0.1, 0.1, .sports),
            "泳帽": (0.05, 0.05, .sports),
            "护膝": (0.1, 0.2, .sports),
            "护腕": (0.05, 0.1, .sports),
            "运动袜": (0.05, 0.1, .clothing),
            "运动内衣": (0.1, 0.1, .clothing),
            "运动短裤": (0.2, 0.3, .clothing),
            "运动长裤": (0.4, 0.8, .clothing),
            "运动T恤": (0.2, 0.4, .clothing),
            "运动外套": (0.5, 1.0, .clothing),
            "运动手环": (0.02, 0.01, .electronics),
            "运动耳机": (0.05, 0.05, .electronics),
            "运动手表": (0.05, 0.02, .electronics),
            "运动眼镜": (0.05, 0.05, .accessories),
            "运动头带": (0.05, 0.05, .accessories),
            "运动毛巾": (0.2, 0.3, .toiletries)
        ]
        
        var results: [ItemSearchResult] = []
        
        // 精确匹配
        if let itemData = commonItems[itemName] {
            results.append(ItemSearchResult(
                name: itemName,
                weight: itemData.weight,
                volume: itemData.volume,
                source: "内置数据库",
                confidence: 1.0,
                category: itemData.category
            ))
        }
        
        // 模糊匹配
        for (key, value) in commonItems {
            if key != itemName && (key.contains(itemName) || itemName.contains(key)) {
                // 计算匹配度
                let confidence = calculateMatchConfidence(query: itemName, item: key)
                
                results.append(ItemSearchResult(
                    name: key,
                    weight: value.weight,
                    volume: value.volume,
                    source: "内置数据库",
                    confidence: confidence,
                    category: value.category
                ))
            }
        }
        
        // 移除重复项并按置信度排序
        return removeDuplicates(from: results)
    }
    
    /// 计算匹配置信度
    private func calculateMatchConfidence(query: String, item: String) -> Double {
        // 完全匹配
        if query == item {
            return 1.0
        }
        
        // 包含关系
        if item.contains(query) {
            let ratio = Double(query.count) / Double(item.count)
            return min(0.9, 0.5 + ratio * 0.4) // 最高0.9
        }
        
        if query.contains(item) {
            let ratio = Double(item.count) / Double(query.count)
            return min(0.8, 0.4 + ratio * 0.4) // 最高0.8
        }
        
        // 部分匹配
        let queryWords = query.components(separatedBy: " ")
        let itemWords = item.components(separatedBy: " ")
        
        let matchingWords = queryWords.filter { word in
            itemWords.contains { $0.contains(word) || word.contains($0) }
        }
        
        if !matchingWords.isEmpty {
            return min(0.7, 0.3 + Double(matchingWords.count) / Double(queryWords.count) * 0.4)
        }
        
        return 0.3 // 默认低置信度
    }
    
    /// 移除重复项并排序
    private func removeDuplicates(from results: [ItemSearchResult]) -> [ItemSearchResult] {
        // 按名称分组，保留置信度最高的
        var bestResults: [String: ItemSearchResult] = [:]
        
        for result in results {
            if let existing = bestResults[result.name] {
                if result.confidence > existing.confidence {
                    bestResults[result.name] = result
                }
            } else {
                bestResults[result.name] = result
            }
        }
        
        // 按置信度排序
        let sortedResults = bestResults.values.sorted { $0.confidence > $1.confidence }
        
        return Array(sortedResults.prefix(5)) // 最多返回5个结果
    }
}

// MARK: - 扩展

// 让 ItemSearchResult 支持 Identifiable
extension ItemSearchService.ItemSearchResult: Identifiable {
    var id: String {
        return "\(name)-\(source)"
    }
}

// 让 ItemSearchResult 支持 Equatable
extension ItemSearchService.ItemSearchResult: Equatable {
    static func == (lhs: ItemSearchService.ItemSearchResult, rhs: ItemSearchService.ItemSearchResult) -> Bool {
        return lhs.name == rhs.name && lhs.source == rhs.source
    }
}

// 让 ItemSearchResult 支持 Hashable
extension ItemSearchService.ItemSearchResult: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(source)
    }
}