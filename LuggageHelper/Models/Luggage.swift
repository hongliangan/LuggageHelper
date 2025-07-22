import Foundation

/// 箱子/包的数据模型
struct Luggage: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var capacity: Double
    var emptyWeight: Double
    var imagePath: String?
    var items: [LuggageItem]
    var note: String?
    var luggageType: LuggageType
    var selectedAirlineId: UUID?
    
    /// 计算箱子/包当前总重量（含物品）
    var totalWeight: Double {
        return emptyWeight + items.reduce(0) { $0 + $1.weight }
    }
    
    /// 计算箱子/包当前已用容量
    var usedCapacity: Double {
        return items.reduce(0) { $0 + $1.volume }
    }
    
    /// 检查是否超重
    func isOverweight(airline: Airline?) -> Bool {
        guard let airline = airline else { return false }
        let weightLimit = luggageType == .carryOn ? airline.carryOnWeightLimit : airline.checkedBaggageWeightLimit
        return totalWeight > weightLimit
    }
    
    /// 获取重量限制
    func getWeightLimit(airline: Airline?) -> Double? {
        guard let airline = airline else { return nil }
        return luggageType == .carryOn ? airline.carryOnWeightLimit : airline.checkedBaggageWeightLimit
    }
    
    /// 初始化方法
    init(id: UUID = UUID(), name: String, capacity: Double, emptyWeight: Double, imagePath: String? = nil, items: [LuggageItem] = [], note: String? = nil, luggageType: LuggageType = .checked, selectedAirlineId: UUID? = nil) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.emptyWeight = emptyWeight
        self.imagePath = imagePath
        self.items = items
        self.note = note
        self.luggageType = luggageType
        self.selectedAirlineId = selectedAirlineId
    }
}
