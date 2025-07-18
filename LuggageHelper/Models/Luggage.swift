import Foundation

/// 箱子/包的数据模型
struct Luggage: Identifiable, Codable {
    let id: UUID
    var name: String
    var capacity: Double
    var emptyWeight: Double
    var imagePath: String?
    var items: [LuggageItem]
    var note: String?
    
    /// 计算箱子/包当前总重量（含物品）
    var totalWeight: Double {
        return emptyWeight + items.reduce(0) { $0 + $1.weight }
    }
    
    /// 计算箱子/包当前已用容量
    var usedCapacity: Double {
        return items.reduce(0) { $0 + $1.volume }
    }
    
    /// 初始化方法
    init(id: UUID = UUID(), name: String, capacity: Double, emptyWeight: Double, imagePath: String? = nil, items: [LuggageItem] = [], note: String? = nil) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.emptyWeight = emptyWeight
        self.imagePath = imagePath
        self.items = items
        self.note = note
    }
}
