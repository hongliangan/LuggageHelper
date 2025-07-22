import Foundation

/// 物品状态枚举
/// 表示物品是独立存放还是已放入行李
enum ItemStatus: Equatable {
    /// 独立存放的物品
    case standalone(location: String?)
    
    /// 已放入行李的物品
    case inLuggage(luggage: Luggage, userLocation: String?)
    
    /// 获取用户设置的位置
    var userLocation: String? {
        switch self {
        case .standalone(let location):
            return location
        case .inLuggage(_, let userLocation):
            return userLocation
        }
    }
    
    /// 获取显示文本
    var displayText: String {
        switch self {
        case .standalone:
            return "🏠 独立存放"
        case .inLuggage(let luggage, _):
            return "📦 已装入 \(luggage.name)"
        }
    }
    
    /// 是否在行李中
    var isInLuggage: Bool {
        switch self {
        case .standalone:
            return false
        case .inLuggage:
            return true
        }
    }
    
    /// 判断是否相等
    static func == (lhs: ItemStatus, rhs: ItemStatus) -> Bool {
        switch (lhs, rhs) {
        case (.standalone(let loc1), .standalone(let loc2)):
            return loc1 == loc2
        case (.inLuggage(let lug1, let loc1), .inLuggage(let lug2, let loc2)):
            return lug1.id == lug2.id && loc1 == loc2
        default:
            return false
        }
    }
}