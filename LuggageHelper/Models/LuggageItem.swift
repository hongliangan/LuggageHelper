import Foundation

/// 物品的数据模型
struct LuggageItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var volume: Double
    var weight: Double
    var imagePath: String?
    var location: String?
    var note: String?
    
    /// 初始化方法
    init(id: UUID = UUID(), name: String, volume: Double, weight: Double, imagePath: String? = nil, location: String? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.volume = volume
        self.weight = weight
        self.imagePath = imagePath
        self.location = location
        self.note = note
    }
}
