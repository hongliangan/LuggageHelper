import Foundation
import UIKit

/// 物品的数据模型
struct LuggageItem: Identifiable, Codable, Equatable, LuggageItemProtocol {
    let id: UUID
    var name: String
    var volume: Double
    var weight: Double
    var category: ItemCategory // 新增类别属性
    var imagePath: String?
    var location: String?
    var note: String?
    
    /// 初始化方法
    init(id: UUID = UUID(), name: String, volume: Double, weight: Double, category: ItemCategory = .other, imagePath: String? = nil, location: String? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.volume = volume
        self.weight = weight
        self.category = category
        self.imagePath = imagePath
        self.location = location
        self.note = note
    }
}
