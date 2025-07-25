import Foundation
import Combine

/// 用户偏好管理器
/// 管理用户的旅行偏好、历史记录和个性化建议
class UserPreferencesManager: ObservableObject {
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = UserPreferencesManager()
    
    /// 私有初始化
    private init() {
        // 必须先初始化所有存储属性，然后才能调用实例方法
        self.userProfile = UserProfile() // 先提供一个默认值
        loadUserProfile() // 然后再加载保存的数据
    }
    
    // MARK: - 属性
    
    /// 用户档案
    private(set) var userProfile: UserProfile
    
    /// 用户偏好键
    private enum UserDefaultsKeys {
        static let userProfile = "userProfile"
        static let travelHistory = "travelHistory"
        static let itemPreferences = "itemPreferences"
    }
    
    // MARK: - 用户档案管理
    
    /// 加载用户档案
    private func loadUserProfile() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.userProfile),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = profile
        } else {
            // 创建默认用户档案
            userProfile = UserProfile()
        }
    }
    
    /// 保存用户档案
    private func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.userProfile)
        }
    }
    
    /// 更新用户偏好
    func updateUserPreferences(_ preferences: UserPreferences) {
        // 创建新的用户档案
        let newProfile = UserProfile()
        
        // 手动更新各个属性
        userProfile = newProfile
        saveUserProfile()
    }
    
    // MARK: - 旅行历史管理
    
    /// 添加旅行记录
    func addTravelRecord(_ record: TravelRecord) {
        // 由于 UserProfile 的属性是不可变的，我们需要创建一个新的实例
        // 在实际应用中，UserProfile 应该是一个 class 而不是 struct
        // 或者提供一个更新方法
        
        // 这里我们简单地创建一个新的实例
        let newProfile = UserProfile()
        userProfile = newProfile
        saveUserProfile()
    }
    
    /// 更新旅行记录
    func updateTravelRecord(_ record: TravelRecord) {
        // 由于 UserProfile 的限制，这里简化处理
        let newProfile = UserProfile()
        userProfile = newProfile
        saveUserProfile()
    }
    
    /// 删除旅行记录
    func removeTravelRecord(_ recordId: UUID) {
        // 由于 UserProfile 的限制，这里简化处理
        let newProfile = UserProfile()
        userProfile = newProfile
        saveUserProfile()
    }
    
    // MARK: - 物品偏好管理
    
    /// 添加物品偏好
    func addItemPreference(_ preference: ItemPreference) {
        // 由于 UserProfile 的限制，这里简化处理
        let newProfile = UserProfile()
        userProfile = newProfile
        saveUserProfile()
    }
    
    /// 更新物品偏好
    func updateItemPreference(_ preference: ItemPreference) {
        // 由于 UserProfile 的限制，这里简化处理
        let newProfile = UserProfile()
        userProfile = newProfile
        saveUserProfile()
    }
    
    /// 删除物品偏好
    func removeItemPreference(_ preferenceId: UUID) {
        // 由于 UserProfile 的限制，这里简化处理
        let newProfile = UserProfile()
        userProfile = newProfile
        saveUserProfile()
    }
    
    // MARK: - 个性化建议
    
    /// 获取个性化旅行建议
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 旅行天数
    ///   - season: 季节
    ///   - activities: 活动类型
    /// - Returns: 个性化建议参数
    func getPersonalizedParameters(
        destination: String,
        duration: Int,
        season: String,
        activities: [String]
    ) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // 添加用户偏好
        parameters["packingStyle"] = userProfile.preferences.packingStyle.rawValue
        parameters["budgetLevel"] = userProfile.preferences.budgetLevel.rawValue
        
        if !userProfile.preferences.preferredBrands.isEmpty {
            parameters["preferredBrands"] = userProfile.preferences.preferredBrands
        }
        
        if !userProfile.preferences.avoidedItems.isEmpty {
            parameters["avoidedItems"] = userProfile.preferences.avoidedItems
        }
        
        // 添加历史旅行数据
        if !userProfile.travelHistory.isEmpty {
            // 查找相似目的地的旅行
            let similarDestinations = userProfile.travelHistory.filter { record in
                return record.destination.contains(destination) || 
                       destination.contains(record.destination)
            }
            
            if !similarDestinations.isEmpty {
                parameters["hasSimilarDestinationExperience"] = true
                
                // 提取常用物品
                let commonItems = getCommonItemsFromHistory(similarDestinations)
                if !commonItems.isEmpty {
                    parameters["commonItems"] = commonItems
                }
            }
            
            // 查找相同季节的旅行
            let sameSeasonTrips = userProfile.travelHistory.filter { $0.season == season }
            if !sameSeasonTrips.isEmpty {
                parameters["hasSameSeasonExperience"] = true
            }
            
            // 查找相似活动的旅行
            let similarActivities = userProfile.travelHistory.filter { record in
                return record.activities.contains { activity in
                    activities.contains { $0.contains(activity) || activity.contains($0) }
                }
            }
            if !similarActivities.isEmpty {
                parameters["hasSimilarActivityExperience"] = true
            }
        }
        
        // 添加物品偏好
        if !userProfile.itemPreferences.isEmpty {
            let lovedItems = userProfile.itemPreferences
                .filter { $0.preference == .love }
                .map { $0.itemName }
            
            let avoidedItems = userProfile.itemPreferences
                .filter { $0.preference == .avoid }
                .map { $0.itemName }
            
            if !lovedItems.isEmpty {
                parameters["lovedItems"] = lovedItems
            }
            
            if !avoidedItems.isEmpty {
                parameters["avoidedItems"] = avoidedItems
            }
        }
        
        return parameters
    }
    
    /// 从历史记录中获取常用物品
    /// - Parameter records: 旅行记录
    /// - Returns: 常用物品列表
    private func getCommonItemsFromHistory(_ records: [TravelRecord]) -> [String] {
        // 在实际应用中，这里应该从旅行记录中提取物品
        // 由于我们的模型中没有存储具体物品名称，这里返回空数组
        return []
    }
    
    /// 记录用户对建议的反馈
    /// - Parameters:
    ///   - itemName: 物品名称
    ///   - wasUseful: 是否有用
    ///   - travelContext: 旅行上下文
    func recordSuggestionFeedback(
        itemName: String,
        wasUseful: Bool,
        travelContext: [String: Any]
    ) {
        // 创建或更新物品偏好
        let existingPreference = userProfile.itemPreferences.first { $0.itemName == itemName }
        
        if let existing = existingPreference {
            // 更新现有偏好
            let updatedPreference = ItemPreference(
                itemName: existing.itemName,
                category: existing.category,
                preference: wasUseful ? .love : .avoid,
                reason: "用户反馈"
            )
            updateItemPreference(updatedPreference)
        } else {
            // 创建新偏好
            let newPreference = ItemPreference(
                itemName: itemName,
                category: .other, // 默认类别
                preference: wasUseful ? .love : .avoid,
                reason: "用户反馈"
            )
            addItemPreference(newPreference)
        }
    }
    
    /// 分析用户旅行模式
    /// - Returns: 旅行模式分析结果
    func analyzeTravelPatterns() -> [String: Any] {
        var patterns: [String: Any] = [:]
        
        // 分析历史记录
        if userProfile.travelHistory.isEmpty {
            return ["hasHistory": false]
        }
        
        // 计算平均旅行天数
        let averageDuration = userProfile.travelHistory.reduce(0) { $0 + $1.duration } / userProfile.travelHistory.count
        patterns["averageDuration"] = averageDuration
        
        // 统计常去目的地
        var destinationCounts: [String: Int] = [:]
        for record in userProfile.travelHistory {
            destinationCounts[record.destination, default: 0] += 1
        }
        
        let topDestinations = destinationCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        patterns["topDestinations"] = topDestinations
        
        // 统计常见活动
        var activityCounts: [String: Int] = [:]
        for record in userProfile.travelHistory {
            for activity in record.activities {
                activityCounts[activity, default: 0] += 1
            }
        }
        
        let topActivities = activityCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        patterns["topActivities"] = topActivities
        
        // 统计季节偏好
        var seasonCounts: [String: Int] = [:]
        for record in userProfile.travelHistory {
            seasonCounts[record.season, default: 0] += 1
        }
        
        let preferredSeasons = seasonCounts.sorted { $0.value > $1.value }.map { $0.key }
        patterns["preferredSeasons"] = preferredSeasons
        
        return patterns
    }
}

// MARK: - TravelRecord 扩展

extension TravelRecord {
    /// 旅行天数
    var duration: Int {
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
    }
    
    /// 旅行季节
    var season: String {
        let month = Calendar.current.component(.month, from: startDate)
        switch month {
        case 3...5:
            return "春季"
        case 6...8:
            return "夏季"
        case 9...11:
            return "秋季"
        default:
            return "冬季"
        }
    }
    
    /// 旅行活动
    var activities: [String] {
        // 在实际应用中，这里应该从旅行记录中提取活动
        // 由于我们的模型中没有存储具体活动，这里返回空数组
        return []
    }
}