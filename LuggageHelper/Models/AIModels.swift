import Foundation
import UIKit

// MARK: - AI 功能相关数据模型

/// 物品信息识别结果
struct ItemInfo: Codable, Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let category: ItemCategory
    let weight: Double // 克
    let volume: Double // 立方厘米
    let dimensions: Dimensions?
    let confidence: Double // 识别置信度 0.0-1.0
    let alternatives: [ItemInfo] // 替代品建议
    let source: String // 数据来源
    
    enum CodingKeys: String, CodingKey {
        case name, category, weight, volume, dimensions, confidence, alternatives, source
    }
    
    /// 初始化方法
    init(name: String, category: ItemCategory, weight: Double, volume: Double, 
         dimensions: Dimensions? = nil, confidence: Double = 1.0, 
         alternatives: [ItemInfo] = [], source: String = "AI识别") {
        self.name = name
        self.category = category
        self.weight = weight
        self.volume = volume
        self.dimensions = dimensions
        self.confidence = confidence
        self.alternatives = alternatives
        self.source = source
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 物品类别枚举
enum ItemCategory: String, Codable, CaseIterable {
    case clothing = "clothing"           // 衣物
    case electronics = "electronics"     // 电子产品
    case toiletries = "toiletries"      // 洗漱用品
    case documents = "documents"         // 证件文件
    case medicine = "medicine"           // 药品保健
    case accessories = "accessories"     // 配饰用品
    case shoes = "shoes"                // 鞋类
    case books = "books"                // 书籍文具
    case food = "food"                  // 食品饮料
    case sports = "sports"              // 运动用品
    case beauty = "beauty"              // 美容化妆
    case other = "other"                // 其他
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .clothing: return "衣物"
        case .electronics: return "电子产品"
        case .toiletries: return "洗漱用品"
        case .documents: return "证件文件"
        case .medicine: return "药品保健"
        case .accessories: return "配饰用品"
        case .shoes: return "鞋类"
        case .books: return "书籍文具"
        case .food: return "食品饮料"
        case .sports: return "运动用品"
        case .beauty: return "美容化妆"
        case .other: return "其他"
        }
    }
    
    /// 图标
    var icon: String {
        switch self {
        case .clothing: return "👕"
        case .electronics: return "📱"
        case .toiletries: return "🧴"
        case .documents: return "📄"
        case .medicine: return "💊"
        case .accessories: return "👜"
        case .shoes: return "👟"
        case .books: return "📚"
        case .food: return "🍎"
        case .sports: return "⚽"
        case .beauty: return "💄"
        case .other: return "📦"
        }
    }
}

/// 物品尺寸
struct Dimensions: Codable, Equatable {
    let length: Double // 长度 (cm)
    let width: Double  // 宽度 (cm)
    let height: Double // 高度 (cm)
    
    /// 计算体积
    var volume: Double {
        return length * width * height
    }
    
    /// 格式化显示
    var formatted: String {
        return String(format: "%.1f×%.1f×%.1f cm", length, width, height)
    }
}

/// 装箱计划
struct PackingPlan: Codable, Identifiable {
    let id = UUID()
    let luggageId: UUID
    let items: [PackingItem]
    let totalWeight: Double
    let totalVolume: Double
    let efficiency: Double // 空间利用率 0.0-1.0
    let warnings: [PackingWarning]
    let suggestions: [String] // 装箱建议
    
    enum CodingKeys: String, CodingKey {
        case luggageId, items, totalWeight, totalVolume, efficiency, warnings, suggestions
    }
}

/// 装箱物品
struct PackingItem: Codable, Identifiable {
    let id = UUID()
    let itemId: UUID
    let position: PackingPosition
    let priority: Int // 装箱优先级 1-10
    let reason: String // 装箱建议原因
    
    enum CodingKeys: String, CodingKey {
        case itemId, position, priority, reason
    }
}

/// 装箱位置
enum PackingPosition: String, Codable {
    case bottom = "bottom"       // 底部
    case middle = "middle"       // 中部
    case top = "top"            // 顶部
    case side = "side"          // 侧面
    case corner = "corner"      // 角落
    
    var displayName: String {
        switch self {
        case .bottom: return "底部"
        case .middle: return "中部"
        case .top: return "顶部"
        case .side: return "侧面"
        case .corner: return "角落"
        }
    }
}

/// 装箱警告
struct PackingWarning: Codable, Identifiable {
    let id = UUID()
    let type: WarningType
    let message: String
    let severity: WarningSeverity
    
    enum CodingKeys: String, CodingKey {
        case type, message, severity
    }
}

/// 警告类型
enum WarningType: String, Codable {
    case overweight = "overweight"       // 超重
    case oversized = "oversized"         // 超尺寸
    case fragile = "fragile"            // 易碎品
    case liquid = "liquid"              // 液体限制
    case battery = "battery"            // 电池限制
    case prohibited = "prohibited"       // 禁止携带
}

/// 警告严重程度
enum WarningSeverity: String, Codable {
    case low = "low"        // 低
    case medium = "medium"  // 中
    case high = "high"      // 高
    case critical = "critical" // 严重
    
    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
}

/// 旅行建议
struct TravelSuggestion: Codable, Identifiable {
    let id = UUID()
    let destination: String
    let duration: Int
    let season: String
    let activities: [String]
    let suggestedItems: [SuggestedItem]
    let categories: [ItemCategory]
    let tips: [String] // 旅行小贴士
    let warnings: [String] // 注意事项
    
    enum CodingKeys: String, CodingKey {
        case destination, duration, season, activities, suggestedItems, categories, tips, warnings
    }
}

/// 建议物品
struct SuggestedItem: Codable, Identifiable {
    let id = UUID()
    let name: String
    let category: ItemCategory
    let importance: ImportanceLevel
    let reason: String
    let quantity: Int
    let estimatedWeight: Double? // 预估重量
    let estimatedVolume: Double? // 预估体积
    
    enum CodingKeys: String, CodingKey {
        case name, category, importance, reason, quantity, estimatedWeight, estimatedVolume
    }
}

/// 重要程度
enum ImportanceLevel: String, Codable, CaseIterable {
    case essential = "essential"     // 必需品
    case important = "important"     // 重要
    case recommended = "recommended" // 推荐
    case optional = "optional"       // 可选
    
    var displayName: String {
        switch self {
        case .essential: return "必需品"
        case .important: return "重要"
        case .recommended: return "推荐"
        case .optional: return "可选"
        }
    }
    
    var priority: Int {
        switch self {
        case .essential: return 4
        case .important: return 3
        case .recommended: return 2
        case .optional: return 1
        }
    }
    
    var color: String {
        switch self {
        case .essential: return "red"
        case .important: return "orange"
        case .recommended: return "blue"
        case .optional: return "gray"
        }
    }
}

/// 用户档案
struct UserProfile: Codable {
    let id: UUID
    let preferences: UserPreferences
    let travelHistory: [TravelRecord]
    let itemPreferences: [ItemPreference]
    let createdAt: Date
    let updatedAt: Date
    
    init(id: UUID = UUID()) {
        self.id = id
        self.preferences = UserPreferences()
        self.travelHistory = []
        self.itemPreferences = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// 用户偏好
struct UserPreferences: Codable {
    let preferredBrands: [String]
    let avoidedItems: [String]
    let packingStyle: PackingStyle
    let budgetLevel: BudgetLevel
    let travelFrequency: TravelFrequency
    
    init() {
        self.preferredBrands = []
        self.avoidedItems = []
        self.packingStyle = .standard
        self.budgetLevel = .medium
        self.travelFrequency = .occasional
    }
}

/// 装箱风格
enum PackingStyle: String, Codable {
    case minimal = "minimal"     // 轻装
    case standard = "standard"   // 标准
    case comprehensive = "comprehensive" // 充分准备
    
    var displayName: String {
        switch self {
        case .minimal: return "轻装出行"
        case .standard: return "标准装备"
        case .comprehensive: return "充分准备"
        }
    }
}

/// 预算水平
enum BudgetLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "经济型"
        case .medium: return "中等"
        case .high: return "高端"
        }
    }
}

/// 旅行频率
enum TravelFrequency: String, Codable {
    case rare = "rare"           // 很少
    case occasional = "occasional" // 偶尔
    case frequent = "frequent"   // 经常
    case business = "business"   // 商务
    
    var displayName: String {
        switch self {
        case .rare: return "很少旅行"
        case .occasional: return "偶尔旅行"
        case .frequent: return "经常旅行"
        case .business: return "商务出行"
        }
    }
}

/// 旅行记录
struct TravelRecord: Codable, Identifiable {
    let id: UUID
    let destination: String
    let startDate: Date
    let endDate: Date
    let purpose: TravelPurpose
    let satisfaction: Int // 1-5 满意度
    let itemsUsed: [UUID] // 使用的物品ID
    let itemsUnused: [UUID] // 未使用的物品ID
    let notes: String?
    
    init(destination: String, startDate: Date, endDate: Date, purpose: TravelPurpose) {
        self.id = UUID()
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.purpose = purpose
        self.satisfaction = 3
        self.itemsUsed = []
        self.itemsUnused = []
        self.notes = nil
    }
}

/// 旅行目的
enum TravelPurpose: String, Codable {
    case leisure = "leisure"     // 休闲
    case business = "business"   // 商务
    case family = "family"       // 探亲
    case study = "study"         // 学习
    case medical = "medical"     // 医疗
    
    var displayName: String {
        switch self {
        case .leisure: return "休闲旅行"
        case .business: return "商务出行"
        case .family: return "探亲访友"
        case .study: return "学习交流"
        case .medical: return "医疗健康"
        }
    }
}

/// 物品偏好
struct ItemPreference: Codable, Identifiable {
    let id: UUID
    let itemName: String
    let category: ItemCategory
    let preference: PreferenceType
    let reason: String?
    
    init(itemName: String, category: ItemCategory, preference: PreferenceType, reason: String? = nil) {
        self.id = UUID()
        self.itemName = itemName
        self.category = category
        self.preference = preference
        self.reason = reason
    }
}

/// 偏好类型
enum PreferenceType: String, Codable {
    case love = "love"       // 喜欢
    case like = "like"       // 一般喜欢
    case neutral = "neutral" // 中性
    case dislike = "dislike" // 不喜欢
    case avoid = "avoid"     // 避免
    
    var displayName: String {
        switch self {
        case .love: return "非常喜欢"
        case .like: return "喜欢"
        case .neutral: return "中性"
        case .dislike: return "不喜欢"
        case .avoid: return "避免"
        }
    }
}

/// 旅行计划
struct TravelPlan: Codable, Identifiable {
    let id: UUID
    let destination: String
    let startDate: Date
    let endDate: Date
    let season: String
    let activities: [String]
    let airline: String?
    let weightLimit: Double?
    let companions: Int // 同行人数
    let accommodation: AccommodationType
    let climate: ClimateInfo?
    
    init(destination: String, startDate: Date, endDate: Date, season: String, activities: [String]) {
        self.id = UUID()
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.season = season
        self.activities = activities
        self.airline = nil
        self.weightLimit = nil
        self.companions = 0
        self.accommodation = .hotel
        self.climate = nil
    }
    
    /// 旅行天数
    var duration: Int {
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
    }
}

/// 住宿类型
enum AccommodationType: String, Codable {
    case hotel = "hotel"
    case hostel = "hostel"
    case airbnb = "airbnb"
    case camping = "camping"
    case family = "family"
    
    var displayName: String {
        switch self {
        case .hotel: return "酒店"
        case .hostel: return "青旅"
        case .airbnb: return "民宿"
        case .camping: return "露营"
        case .family: return "亲友家"
        }
    }
}

/// 气候信息
struct ClimateInfo: Codable {
    let temperature: TemperatureRange
    let humidity: Double // 湿度百分比
    let rainfall: Double // 降雨量
    let season: String
    
    struct TemperatureRange: Codable {
        let min: Double
        let max: Double
        let unit: String // "C" or "F"
        
        var formatted: String {
            return "\(Int(min))°-\(Int(max))°\(unit)"
        }
    }
}

/// 重量预测结果
struct WeightPrediction: Codable {
    let totalWeight: Double
    let breakdown: [CategoryWeight]
    let warnings: [String]
    let suggestions: [String]
    let confidence: Double
    
    struct CategoryWeight: Codable {
        let category: ItemCategory
        let weight: Double
        let percentage: Double
    }
}

/// 遗漏物品警告
struct MissingItemAlert: Codable, Identifiable {
    let id = UUID()
    let itemName: String
    let category: ItemCategory
    let importance: ImportanceLevel
    let reason: String
    let suggestion: String?
    
    enum CodingKeys: String, CodingKey {
        case itemName, category, importance, reason, suggestion
    }
}

/// 装箱约束条件
struct PackingConstraints: Codable {
    let maxWeight: Double
    let maxVolume: Double
    let restrictions: [String] // 限制条件
    let priorities: [ItemCategory] // 优先级类别
    
    /// 默认约束条件
    static let `default` = PackingConstraints(
        maxWeight: 23000, // 23kg
        maxVolume: 100000, // 100L
        restrictions: [],
        priorities: [.documents, .medicine, .electronics]
    )
}

// MARK: - 航空公司相关模型

/// 航空公司行李政策
struct AirlineLuggagePolicy: Codable, Identifiable {
    let id = UUID()
    let airline: String
    let carryOnWeight: Double // 手提行李重量限制 (kg)
    let carryOnDimensions: Dimensions // 手提行李尺寸限制
    let checkedWeight: Double // 托运行李重量限制 (kg)
    let checkedDimensions: Dimensions // 托运行李尺寸限制
    let restrictions: [String] // 限制条件
    let lastUpdated: Date // 最后更新时间
    let source: String // 数据来源
    
    enum CodingKeys: String, CodingKey {
        case airline, carryOnWeight, carryOnDimensions, checkedWeight, checkedDimensions, restrictions, lastUpdated, source
    }
    
    /// 检查是否符合手提行李要求
    func isCarryOnCompliant(weight: Double, dimensions: Dimensions) -> Bool {
        return weight <= carryOnWeight && 
               dimensions.length <= carryOnDimensions.length &&
               dimensions.width <= carryOnDimensions.width &&
               dimensions.height <= carryOnDimensions.height
    }
    
    /// 检查是否符合托运行李要求
    func isCheckedCompliant(weight: Double, dimensions: Dimensions) -> Bool {
        let totalDimension = dimensions.length + dimensions.width + dimensions.height
        let maxTotalDimension = checkedDimensions.length
        return weight <= checkedWeight && totalDimension <= maxTotalDimension
    }
}

// MARK: - 智能建议相关模型

/// 智能建议
struct SmartSuggestion: Codable, Identifiable {
    let id: UUID
    let type: SuggestionType
    let title: String
    let description: String
    let priority: Int // 1-10
    let category: ItemCategory?
    let actionable: Bool // 是否可操作
    let metadata: [String: String] // 额外元数据
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, description, priority, category, actionable, metadata, createdAt
    }
    
    init(type: SuggestionType, title: String, description: String, priority: Int = 5, category: ItemCategory? = nil, actionable: Bool = true, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.actionable = actionable
        self.metadata = metadata
        self.createdAt = Date()
    }
}

/// 建议类型
enum SuggestionType: String, Codable {
    case itemRecommendation = "itemRecommendation"   // 物品推荐
    case packingOptimization = "packingOptimization" // 装箱优化
    case weightReduction = "weightReduction"         // 减重建议
    case spaceOptimization = "spaceOptimization"     // 空间优化
    case safetyWarning = "safetyWarning"            // 安全警告
    case travelTip = "travelTip"                    // 旅行贴士
    case weatherAlert = "weatherAlert"              // 天气提醒
    case culturalNote = "culturalNote"              // 文化提醒
    
    var displayName: String {
        switch self {
        case .itemRecommendation: return "物品推荐"
        case .packingOptimization: return "装箱优化"
        case .weightReduction: return "减重建议"
        case .spaceOptimization: return "空间优化"
        case .safetyWarning: return "安全警告"
        case .travelTip: return "旅行贴士"
        case .weatherAlert: return "天气提醒"
        case .culturalNote: return "文化提醒"
        }
    }
    
    var icon: String {
        switch self {
        case .itemRecommendation: return "💡"
        case .packingOptimization: return "📦"
        case .weightReduction: return "⚖️"
        case .spaceOptimization: return "📏"
        case .safetyWarning: return "⚠️"
        case .travelTip: return "💭"
        case .weatherAlert: return "🌤️"
        case .culturalNote: return "🌍"
        }
    }
}

// MARK: - 分析和统计模型

/// 装箱分析结果
struct PackingAnalysis: Codable, Identifiable {
    let id: UUID
    let luggageId: UUID
    let totalItems: Int
    let totalWeight: Double
    let totalVolume: Double
    let utilizationRate: Double // 利用率
    let categoryBreakdown: [CategoryAnalysis]
    let recommendations: [SmartSuggestion]
    let warnings: [PackingWarning]
    let score: Double // 装箱评分 0-100
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, luggageId, totalItems, totalWeight, totalVolume, utilizationRate, categoryBreakdown, recommendations, warnings, score, createdAt
    }
    
    init(luggageId: UUID, totalItems: Int, totalWeight: Double, totalVolume: Double, utilizationRate: Double, categoryBreakdown: [CategoryAnalysis], recommendations: [SmartSuggestion], warnings: [PackingWarning], score: Double) {
        self.id = UUID()
        self.luggageId = luggageId
        self.totalItems = totalItems
        self.totalWeight = totalWeight
        self.totalVolume = totalVolume
        self.utilizationRate = utilizationRate
        self.categoryBreakdown = categoryBreakdown
        self.recommendations = recommendations
        self.warnings = warnings
        self.score = score
        self.createdAt = Date()
    }
}

/// 类别分析
struct CategoryAnalysis: Codable {
    let category: ItemCategory
    let itemCount: Int
    let totalWeight: Double
    let totalVolume: Double
    let weightPercentage: Double
    let volumePercentage: Double
    let averageItemWeight: Double
    let averageItemVolume: Double
}

// MARK: - 用户行为分析模型

/// 用户行为数据
struct UserBehaviorData: Codable {
    let userId: UUID
    let itemUsageStats: [ItemUsageStats]
    let packingPatterns: [PackingPattern]
    let travelPreferences: TravelPreferenceStats
    let lastUpdated: Date
    
    init(userId: UUID) {
        self.userId = userId
        self.itemUsageStats = []
        self.packingPatterns = []
        self.travelPreferences = TravelPreferenceStats()
        self.lastUpdated = Date()
    }
}

/// 物品使用统计
struct ItemUsageStats: Codable {
    let itemName: String
    let category: ItemCategory
    let timesPackaged: Int
    let timesUsed: Int
    let usageRate: Double // 使用率
    let averageWeight: Double
    let averageVolume: Double
    let lastUsed: Date?
    
    /// 计算使用率
    var calculatedUsageRate: Double {
        guard timesPackaged > 0 else { return 0 }
        return Double(timesUsed) / Double(timesPackaged)
    }
}

/// 装箱模式
struct PackingPattern: Codable {
    let patternId: UUID
    let destination: String
    let season: String
    let duration: Int
    let activities: [String]
    let itemCategories: [ItemCategory]
    let totalWeight: Double
    let totalVolume: Double
    let satisfaction: Int // 1-5
    let frequency: Int // 使用频率
    let lastUsed: Date
    
    init(destination: String, season: String, duration: Int, activities: [String], itemCategories: [ItemCategory], totalWeight: Double, totalVolume: Double, satisfaction: Int) {
        self.patternId = UUID()
        self.destination = destination
        self.season = season
        self.duration = duration
        self.activities = activities
        self.itemCategories = itemCategories
        self.totalWeight = totalWeight
        self.totalVolume = totalVolume
        self.satisfaction = satisfaction
        self.frequency = 1
        self.lastUsed = Date()
    }
}

/// 旅行偏好统计
struct TravelPreferenceStats: Codable {
    let favoriteDestinations: [String]
    let preferredSeasons: [String]
    let commonActivities: [String]
    let averageTripDuration: Double
    let packingStyleDistribution: [PackingStyle: Int]
    let categoryPreferences: [ItemCategory: Double] // 偏好权重
    
    init() {
        self.favoriteDestinations = []
        self.preferredSeasons = []
        self.commonActivities = []
        self.averageTripDuration = 7.0
        self.packingStyleDistribution = [:]
        self.categoryPreferences = [:]
    }
}

// MARK: - 缓存和性能模型

/// AI 请求缓存
struct AIRequestCache: Codable {
    let requestId: UUID
    let requestType: String
    let requestHash: String
    let responseData: Data
    let createdAt: Date
    let expiresAt: Date
    let hitCount: Int
    
    init(requestType: String, requestHash: String, responseData: Data, expiryHours: Int = 24) {
        self.requestId = UUID()
        self.requestType = requestType
        self.requestHash = requestHash
        self.responseData = responseData
        self.createdAt = Date()
        self.expiresAt = Calendar.current.date(byAdding: .hour, value: expiryHours, to: Date()) ?? Date()
        self.hitCount = 0
    }
    
    /// 检查是否过期
    var isExpired: Bool {
        return Date() > expiresAt
    }
}

/// 性能指标
struct PerformanceMetrics: Codable {
    let requestType: String
    let averageResponseTime: Double // 毫秒
    let successRate: Double // 成功率
    let cacheHitRate: Double // 缓存命中率
    let totalRequests: Int
    let failedRequests: Int
    let lastUpdated: Date
    
    init(requestType: String) {
        self.requestType = requestType
        self.averageResponseTime = 0
        self.successRate = 1.0
        self.cacheHitRate = 0
        self.totalRequests = 0
        self.failedRequests = 0
        self.lastUpdated = Date()
    }
}

// MARK: - 协议定义

/// 行李项目协议
protocol LuggageItemProtocol {
    var id: UUID { get }
    var name: String { get }
    var weight: Double { get }
    var volume: Double { get }
}

/// 行李箱协议
protocol LuggageProtocol {
    var id: UUID { get }
    var name: String { get }
    var capacity: Double { get }
    var emptyWeight: Double { get }
}

/// AI 可识别项目协议
protocol AIIdentifiable {
    var name: String { get }
    var category: ItemCategory { get }
    var confidence: Double { get }
    var source: String { get }
}

// MARK: - 扩展方法

extension ItemInfo: AIIdentifiable {}

extension Array where Element == SuggestedItem {
    /// 按重要性排序
    func sortedByImportance() -> [SuggestedItem] {
        return self.sorted { $0.importance.priority > $1.importance.priority }
    }
    
    /// 按类别分组
    func groupedByCategory() -> [ItemCategory: [SuggestedItem]] {
        return Dictionary(grouping: self) { $0.category }
    }
    
    /// 筛选必需品
    func essentialItems() -> [SuggestedItem] {
        return self.filter { $0.importance == .essential }
    }
}

extension Array where Element == PackingWarning {
    /// 按严重程度排序
    func sortedBySeverity() -> [PackingWarning] {
        let severityOrder: [WarningSeverity] = [.critical, .high, .medium, .low]
        return self.sorted { warning1, warning2 in
            let index1 = severityOrder.firstIndex(of: warning1.severity) ?? severityOrder.count
            let index2 = severityOrder.firstIndex(of: warning2.severity) ?? severityOrder.count
            return index1 < index2
        }
    }
    
    /// 获取严重警告
    func criticalWarnings() -> [PackingWarning] {
        return self.filter { $0.severity == .critical || $0.severity == .high }
    }
}

extension TravelSuggestion {
    /// 获取必需品数量
    var essentialItemsCount: Int {
        return suggestedItems.filter { $0.importance == .essential }.count
    }
    
    /// 获取总预估重量
    var totalEstimatedWeight: Double {
        return suggestedItems.compactMap { $0.estimatedWeight }.reduce(0, +)
    }
    
    /// 获取总预估体积
    var totalEstimatedVolume: Double {
        return suggestedItems.compactMap { $0.estimatedVolume }.reduce(0, +)
    }
}

extension UserProfile {
    /// 更新用户档案
    mutating func updateProfile(with newPreferences: UserPreferences) {
        // 这里需要创建一个新的 UserProfile 实例，因为属性是 let
        // 在实际使用中，可能需要使用 class 而不是 struct
    }
    
    /// 添加旅行记录
    mutating func addTravelRecord(_ record: TravelRecord) {
        // 同样需要处理不可变性问题
    }
}

// MARK: - 工厂方法

extension ItemInfo {
    /// 创建默认物品信息
    static func defaultItem(name: String) -> ItemInfo {
        return ItemInfo(
            name: name,
            category: .other,
            weight: 100.0,
            volume: 100.0,
            confidence: 0.5,
            source: "默认值"
        )
    }
    
    /// 从 AI 响应创建
    static func fromAIResponse(_ response: [String: Any], originalName: String) -> ItemInfo {
        let name = response["name"] as? String ?? originalName
        let categoryString = response["category"] as? String ?? "other"
        let category = ItemCategory(rawValue: categoryString) ?? .other
        let weight = response["weight"] as? Double ?? 100.0
        let volume = response["volume"] as? Double ?? 100.0
        let confidence = response["confidence"] as? Double ?? 0.8
        
        return ItemInfo(
            name: name,
            category: category,
            weight: weight,
            volume: volume,
            confidence: confidence,
            source: "AI识别"
        )
    }
}
// MARK: - 照片识别相关模型

/// 照片识别策略
enum PhotoRecognitionStrategy: String, Codable, CaseIterable {
    case aiVision = "aiVision"           // AI 视觉识别
    case textExtraction = "textExtraction" // 文字提取识别
    case colorAnalysis = "colorAnalysis"   // 颜色分析
    case shapeAnalysis = "shapeAnalysis"   // 形状分析
    
    var displayName: String {
        switch self {
        case .aiVision: return "AI 视觉识别"
        case .textExtraction: return "文字识别"
        case .colorAnalysis: return "颜色分析"
        case .shapeAnalysis: return "形状分析"
        }
    }
    
    var description: String {
        switch self {
        case .aiVision: return "使用 AI 模型直接识别图片中的物品"
        case .textExtraction: return "提取图片中的文字信息进行识别"
        case .colorAnalysis: return "分析图片主要颜色推测物品类型"
        case .shapeAnalysis: return "分析物品形状特征进行识别"
        }
    }
}

/// 照片识别结果
struct PhotoRecognitionResult: Codable, Identifiable {
    let id = UUID()
    let primaryResult: ItemInfo
    let alternativeResults: [ItemInfo]
    let confidence: Double
    let usedStrategies: [PhotoRecognitionStrategy]
    let processingTime: TimeInterval
    let imageMetadata: ImageMetadata?
    
    enum CodingKeys: String, CodingKey {
        case primaryResult, alternativeResults, confidence, usedStrategies, processingTime, imageMetadata
    }
    
    init(primaryResult: ItemInfo, alternativeResults: [ItemInfo], confidence: Double, usedStrategies: [PhotoRecognitionStrategy], processingTime: TimeInterval, imageMetadata: ImageMetadata? = nil) {
        self.primaryResult = primaryResult
        self.alternativeResults = alternativeResults
        self.confidence = confidence
        self.usedStrategies = usedStrategies
        self.processingTime = processingTime
        self.imageMetadata = imageMetadata
    }
}

/// 图片元数据
struct ImageMetadata: Codable {
    let width: Int
    let height: Int
    let fileSize: Int
    let format: String
    let dominantColors: [String]
    let brightness: Double
    let contrast: Double
    let hasText: Bool
    let estimatedObjects: Int
}

// MARK: - UIImage 扩展

extension UIImage {
    /// 修正图片方向
    func fixOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
    
    /// 为 AI 识别调整尺寸
    func resizeForAI(maxDimension: CGFloat = 1024) -> UIImage {
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }
        
        if scale >= 1 {
            return self
        }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
    
    /// 增强对比度
    func enhanceContrast(factor: Float = 1.2) -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(factor, forKey: kCIInputContrastKey)
        
        guard let outputImage = filter?.outputImage,
              let cgOutput = context.createCGImage(outputImage, from: outputImage.extent) else {
            return self
        }
        
        return UIImage(cgImage: cgOutput)
    }
    
    /// 获取主要颜色
    func getDominantColors(count: Int = 5) -> [UIColor] {
        guard let cgImage = self.cgImage else { return [] }
        
        // 简化实现：返回一些基本颜色
        // 实际实现需要颜色聚类算法
        return [
            UIColor.systemBlue,
            UIColor.systemRed,
            UIColor.systemGreen,
            UIColor.black,
            UIColor.white
        ].prefix(count).map { $0 }
    }
    
    /// 获取图片元数据
    func getMetadata() -> ImageMetadata {
        let dominantColors = getDominantColors().map { $0.hexString }
        
        return ImageMetadata(
            width: Int(size.width),
            height: Int(size.height),
            fileSize: jpegData(compressionQuality: 1.0)?.count ?? 0,
            format: "JPEG",
            dominantColors: dominantColors,
            brightness: calculateBrightness(),
            contrast: calculateContrast(),
            hasText: detectText(),
            estimatedObjects: estimateObjectCount()
        )
    }
    
    /// 计算亮度
    private func calculateBrightness() -> Double {
        // 简化实现
        return 0.5
    }
    
    /// 计算对比度
    private func calculateContrast() -> Double {
        // 简化实现
        return 0.7
    }
    
    /// 检测是否包含文字
    private func detectText() -> Bool {
        // 简化实现
        return false
    }
    
    /// 估算物体数量
    private func estimateObjectCount() -> Int {
        // 简化实现
        return 1
    }
}

extension UIColor {
    /// 转换为十六进制字符串
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
    
    /// 检查是否接近某个颜色
    func isCloseToColor(_ color: UIColor, threshold: CGFloat = 0.3) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let distance = sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2))
        return distance < threshold
    }
}

// MARK: - 照片识别配置

/// 照片识别配置
struct PhotoRecognitionConfig: Codable {
    let enabledStrategies: [PhotoRecognitionStrategy]
    let maxImageSize: Int // 字节
    let compressionQuality: Double
    let enhanceContrast: Bool
    let extractText: Bool
    let analyzeColors: Bool
    let confidenceThreshold: Double
    
    static let `default` = PhotoRecognitionConfig(
        enabledStrategies: [.aiVision, .colorAnalysis],
        maxImageSize: 5 * 1024 * 1024, // 5MB
        compressionQuality: 0.8,
        enhanceContrast: true,
        extractText: false,
        analyzeColors: true,
        confidenceThreshold: 0.5
    )
}

/// 照片识别统计
struct PhotoRecognitionStats: Codable {
    let totalRecognitions: Int
    let successfulRecognitions: Int
    let averageConfidence: Double
    let averageProcessingTime: TimeInterval
    let strategyUsage: [PhotoRecognitionStrategy: Int]
    let lastUpdated: Date
    
    init() {
        self.totalRecognitions = 0
        self.successfulRecognitions = 0
        self.averageConfidence = 0.0
        self.averageProcessingTime = 0.0
        self.strategyUsage = [:]
        self.lastUpdated = Date()
    }
    
    /// 成功率
    var successRate: Double {
        guard totalRecognitions > 0 else { return 0.0 }
        return Double(successfulRecognitions) / Double(totalRecognitions)
    }
}