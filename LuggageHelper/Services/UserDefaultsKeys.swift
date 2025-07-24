import Foundation

/// UserDefaults 键管理
struct UserDefaultsKeys {
    // MARK: - API Configuration Keys
    static let apiBaseURL = "api_base_url"
    static let apiKey = "api_key"
    static let apiModel = "api_model"
    static let apiMaxTokens = "api_max_tokens"
    static let apiTemperature = "api_temperature"
    static let apiTopP = "api_top_p"

    // MARK: - Item Data Keys
    /// 物品分类键
    static let itemCategories = "itemCategories"
    
    /// 物品标签键前缀
    static let itemTagsPrefix = "itemTags_"
    
    /// 用户分类偏好键
    static let userCategoryPreferences = "AIItemCategoryManager.userPreferences"
    
    /// 分类规则键
    static let categoryRules = "AIItemCategoryManager.categoryRules"
    
    /// 获取物品标签键
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品标签键
    static func itemTags(for itemId: UUID) -> String {
        return "\(itemTagsPrefix)\(itemId.uuidString)"
    }
}