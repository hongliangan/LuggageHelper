import Foundation

/// 航空公司行李限制数据模型
struct Airline: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var code: String // 航空公司代码，如 "CA", "MU"
    var carryOnWeightLimit: Double // 手提行李重量限制（kg）
    var carryOnSizeLimit: String // 手提行李尺寸限制
    var checkedBaggageWeightLimit: Double // 托运行李重量限制（kg）
    var checkedBaggageSizeLimit: String // 托运行李尺寸限制
    var note: String?
    
    init(id: UUID = UUID(), name: String, code: String, carryOnWeightLimit: Double, carryOnSizeLimit: String, checkedBaggageWeightLimit: Double, checkedBaggageSizeLimit: String, note: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.carryOnWeightLimit = carryOnWeightLimit
        self.carryOnSizeLimit = carryOnSizeLimit
        self.checkedBaggageWeightLimit = checkedBaggageWeightLimit
        self.checkedBaggageSizeLimit = checkedBaggageSizeLimit
        self.note = note
    }
    
    /// 预设的常见航空公司数据
    static let presetAirlines: [Airline] = [
        Airline(name: "中国国际航空", code: "CA", carryOnWeightLimit: 5, carryOnSizeLimit: "55×40×20cm", checkedBaggageWeightLimit: 23, checkedBaggageSizeLimit: "158cm"),
        Airline(name: "中国东方航空", code: "MU", carryOnWeightLimit: 5, carryOnSizeLimit: "55×40×20cm", checkedBaggageWeightLimit: 23, checkedBaggageSizeLimit: "158cm"),
        Airline(name: "中国南方航空", code: "CZ", carryOnWeightLimit: 5, carryOnSizeLimit: "55×40×20cm", checkedBaggageWeightLimit: 23, checkedBaggageSizeLimit: "158cm"),
        Airline(name: "海南航空", code: "HU", carryOnWeightLimit: 5, carryOnSizeLimit: "55×40×20cm", checkedBaggageWeightLimit: 23, checkedBaggageSizeLimit: "158cm"),
        Airline(name: "厦门航空", code: "MF", carryOnWeightLimit: 5, carryOnSizeLimit: "55×40×20cm", checkedBaggageWeightLimit: 23, checkedBaggageSizeLimit: "158cm")
    ]
}

/// 行李类型枚举
enum LuggageType: String, CaseIterable, Codable {
    case carryOn = "手提行李"
    case checked = "托运行李"
    
    var displayName: String {
        return self.rawValue
    }
}