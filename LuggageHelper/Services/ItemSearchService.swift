import Foundation

/// 物品信息搜索服务
/// 通过网络搜索物品的体积和重量信息
class ItemSearchService: ObservableObject {
    
    /// 搜索结果数据模型
    struct ItemSearchResult {
        let name: String
        let weight: Double?
        let volume: Double?
        let source: String
        let confidence: Double // 置信度 0-1
    }
    
    /// 搜索物品信息
    /// - Parameter itemName: 物品名称
    /// - Returns: 搜索结果数组
    func searchItemInfo(itemName: String) async -> [ItemSearchResult] {
        // 这里是一个模拟实现，实际应用中可以集成真实的搜索API
        // 比如调用购物网站API、产品数据库等
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let mockResults = self.getMockSearchResults(for: itemName)
                continuation.resume(returning: mockResults)
            }
        }
    }
    
    /// 获取模拟搜索结果
    private func getMockSearchResults(for itemName: String) -> [ItemSearchResult] {
        let commonItems: [String: (weight: Double, volume: Double)] = [
            "iPhone": (0.2, 0.1),
            "iPad": (0.5, 0.5),
            "MacBook": (1.4, 2.0),
            "充电器": (0.3, 0.2),
            "充电宝": (0.4, 0.3),
            "耳机": (0.05, 0.05),
            "T恤": (0.15, 0.5),
            "牛仔裤": (0.6, 1.0),
            "运动鞋": (0.8, 2.5),
            "洗发水": (0.4, 0.4),
            "牙刷": (0.02, 0.02),
            "毛巾": (0.3, 0.8),
            "雨伞": (0.4, 0.3),
            "水杯": (0.3, 0.5),
            "笔记本": (0.5, 0.8),
            "钱包": (0.1, 0.1),
            "太阳镜": (0.05, 0.1),
            "护照": (0.05, 0.01),
            "药品": (0.1, 0.1),
            "化妆品": (0.2, 0.2)
        ]
        
        var results: [ItemSearchResult] = []
        
        // 精确匹配
        if let itemData = commonItems[itemName] {
            results.append(ItemSearchResult(
                name: itemName,
                weight: itemData.weight,
                volume: itemData.volume,
                source: "内置数据库",
                confidence: 1.0
            ))
        }
        
        // 模糊匹配
        for (key, value) in commonItems {
            if key.contains(itemName) || itemName.contains(key) {
                results.append(ItemSearchResult(
                    name: key,
                    weight: value.weight,
                    volume: value.volume,
                    source: "内置数据库",
                    confidence: 0.7
                ))
            }
        }
        
        // 移除重复项并按置信度排序
        let uniqueResults = Array(Set(results.map { $0.name })).compactMap { name in
            results.first { $0.name == name }
        }.sorted { $0.confidence > $1.confidence }
        
        return Array(uniqueResults.prefix(5)) // 最多返回5个结果
    }
}

// 让 ItemSearchResult 支持 Equatable
extension ItemSearchService.ItemSearchResult: Equatable {
    static func == (lhs: ItemSearchService.ItemSearchResult, rhs: ItemSearchService.ItemSearchResult) -> Bool {
        return lhs.name == rhs.name && lhs.source == rhs.source
    }
}