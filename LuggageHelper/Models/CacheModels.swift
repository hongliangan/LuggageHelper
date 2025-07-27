import Foundation

// MARK: - 缓存相关数据模型

// 注意：AlternativeItem 和 AlternativeConstraints 已移至 AIModels.swift

/// 航空公司政策
struct AirlinePolicy: Codable, Identifiable {
    let id = UUID()
    let airline: String
    let lastUpdated: String
    let checkedBaggage: CheckedBaggagePolicy
    let carryOn: CarryOnPolicy
    let restrictions: [RestrictionItem]
    let specialItems: [SpecialItem]
    let tips: [String]
    let contactInfo: ContactInfo
    
    enum CodingKeys: String, CodingKey {
        case airline, lastUpdated, checkedBaggage, carryOn, restrictions, specialItems, tips, contactInfo
    }
    
    struct CheckedBaggagePolicy: Codable {
        let weightLimit: Double
        let sizeLimit: SizeLimit
        let pieces: Int
        let fees: [Fee]
        
        struct Fee: Codable {
            let description: String
            let amount: Double
            let currency: String
        }
    }
    
    struct CarryOnPolicy: Codable {
        let weightLimit: Double
        let sizeLimit: SizeLimit
        let pieces: Int
    }
    
    struct SizeLimit: Codable {
        let length: Double
        let width: Double
        let height: Double
    }
    
    struct RestrictionItem: Codable {
        let item: String
        let rule: String
        let category: String
    }
    
    struct SpecialItem: Codable {
        let category: String
        let rules: String
        let additionalFees: Double?
    }
    
    struct ContactInfo: Codable {
        let phone: String
        let website: String
        let email: String
    }
}

// MARK: - 用户偏好序列化扩展

extension UserPreferences {
    func serialized() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - 行李箱约束序列化扩展

extension Luggage {
    func serializedConstraints() -> String {
        let constraints: [String: Any] = [
            "capacity": capacity,
            "emptyWeight": emptyWeight,
            "luggageType": luggageType.rawValue
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: constraints),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

// MARK: - 装箱约束序列化扩展

extension PackingConstraints {
    func serialized() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}