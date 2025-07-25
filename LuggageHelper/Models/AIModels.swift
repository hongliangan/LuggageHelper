import Foundation
import UIKit
import CoreImage

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
    case attention = "attention"         // 注意事项
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
        
        // 这里可以实现图片对比度增强逻辑
        return self
    }
}

// MARK: - 替代品建议相关模型

/// 替代品物品
struct AlternativeItem: Codable, Identifiable {
    let id = UUID()
    let name: String
    let category: ItemCategory
    let weight: Double // 克
    let volume: Double // 立方厘米
    let dimensions: Dimensions
    let advantages: [String] // 优势
    let disadvantages: [String] // 劣势
    let suitability: Double // 适用性评分 0.0-1.0
    let reason: String // 推荐理由
    let estimatedPrice: Double? // 预估价格（元）
    let availability: String? // 购买渠道
    let compatibilityScore: Double // 兼容性评分 0.0-1.0
    let functionalityMatch: Double? // 功能匹配度 0.0-1.0
    let versatility: Double? // 多功能性评分 0.0-1.0
    
    enum CodingKeys: String, CodingKey {
        case name, category, weight, volume, dimensions, advantages, disadvantages, 
             suitability, reason, estimatedPrice, availability, compatibilityScore,
             functionalityMatch, versatility
    }
    
    init(name: String, category: ItemCategory, weight: Double, volume: Double,
         dimensions: Dimensions, advantages: [String], disadvantages: [String],
         suitability: Double, reason: String, estimatedPrice: Double? = nil,
         availability: String? = nil, compatibilityScore: Double,
         functionalityMatch: Double? = nil, versatility: Double? = nil) {
        self.name = name
        self.category = category
        self.weight = weight
        self.volume = volume
        self.dimensions = dimensions
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.suitability = suitability
        self.reason = reason
        self.estimatedPrice = estimatedPrice
        self.availability = availability
        self.compatibilityScore = compatibilityScore
        self.functionalityMatch = functionalityMatch
        self.versatility = versatility
    }
}

/// 替代品约束条件
struct AlternativeConstraints: Codable {
    let maxWeight: Double? // 最大重量限制（克）
    let maxVolume: Double? // 最大体积限制（立方厘米）
    let maxBudget: Double? // 预算上限（元）
    let requiredFeatures: [String]? // 必需功能
    let excludedBrands: [String]? // 排除品牌
    let preferredBrands: [String]? // 偏好品牌
    let minCompatibilityScore: Double? // 最低兼容性评分
    let prioritizeWeight: Bool // 是否优先考虑重量
    let prioritizeVolume: Bool // 是否优先考虑体积
    let prioritizePrice: Bool // 是否优先考虑价格
    
    init(maxWeight: Double? = nil, maxVolume: Double? = nil, maxBudget: Double? = nil,
         requiredFeatures: [String]? = nil, excludedBrands: [String]? = nil,
         preferredBrands: [String]? = nil, minCompatibilityScore: Double? = nil,
         prioritizeWeight: Bool = false, prioritizeVolume: Bool = false,
         prioritizePrice: Bool = false) {
        self.maxWeight = maxWeight
        self.maxVolume = maxVolume
        self.maxBudget = maxBudget
        self.requiredFeatures = requiredFeatures
        self.excludedBrands = excludedBrands
        self.preferredBrands = preferredBrands
        self.minCompatibilityScore = minCompatibilityScore
        self.prioritizeWeight = prioritizeWeight
        self.prioritizeVolume = prioritizeVolume
        self.prioritizePrice = prioritizePrice
    }
    
    /// 默认约束条件
    static let `default` = AlternativeConstraints()
    
    /// 轻量化约束
    static let lightweight = AlternativeConstraints(
        prioritizeWeight: true,
        prioritizeVolume: true
    )
    
    /// 经济型约束
    static let budget = AlternativeConstraints(
        prioritizePrice: true
    )
}

/// 替代品建议场景
struct AlternativeScenario: Codable, Identifiable {
    let id = UUID()
    let scenario: String // 使用场景
    let bestAlternative: String // 最佳替代品名称
    let reason: String // 推荐理由
    let applicableConstraints: AlternativeConstraints? // 适用约束
    
    enum CodingKeys: String, CodingKey {
        case scenario, bestAlternative, reason, applicableConstraints
    }
    
    init(scenario: String, bestAlternative: String, reason: String,
         applicableConstraints: AlternativeConstraints? = nil) {
        self.scenario = scenario
        self.bestAlternative = bestAlternative
        self.reason = reason
        self.applicableConstraints = applicableConstraints
    }
}

/// 替代品比较结果
struct AlternativeComparison: Codable, Identifiable {
    let id = UUID()
    let originalItem: String // 原物品名称
    let alternatives: [AlternativeItem] // 替代品列表
    let comparisonMatrix: [ComparisonCriteria: [String: Double]] // 比较矩阵
    let recommendations: [AlternativeScenario] // 场景推荐
    let overallBest: String? // 总体最佳选择
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case originalItem, alternatives, comparisonMatrix, recommendations, overallBest, createdAt
    }
    
    init(originalItem: String, alternatives: [AlternativeItem],
         comparisonMatrix: [ComparisonCriteria: [String: Double]] = [:],
         recommendations: [AlternativeScenario] = [], overallBest: String? = nil) {
        self.originalItem = originalItem
        self.alternatives = alternatives
        self.comparisonMatrix = comparisonMatrix
        self.recommendations = recommendations
        self.overallBest = overallBest
        self.createdAt = Date()
    }
}

/// 比较标准
enum ComparisonCriteria: String, Codable, CaseIterable {
    case weight = "weight"
    case volume = "volume"
    case price = "price"
    case functionality = "functionality"
    case durability = "durability"
    case portability = "portability"
    case versatility = "versatility"
    case availability = "availability"
    
    var displayName: String {
        switch self {
        case .weight: return "重量"
        case .volume: return "体积"
        case .price: return "价格"
        case .functionality: return "功能性"
        case .durability: return "耐用性"
        case .portability: return "便携性"
        case .versatility: return "多功能性"
        case .availability: return "可获得性"
        }
    }
    
    var unit: String {
        switch self {
        case .weight: return "g"
        case .volume: return "cm³"
        case .price: return "元"
        case .functionality, .durability, .portability, .versatility, .availability: return "分"
        }
    }
}

/// 批量替代品建议结果
struct BatchAlternativeResult: Codable, Identifiable {
    let id = UUID()
    let originalItems: [String] // 原物品列表
    let alternativesByItem: [String: [AlternativeItem]] // 按物品分组的替代品
    let globalRecommendations: [GlobalRecommendation] // 全局建议
    let potentialSavings: PotentialSavings // 潜在节省
    let processingTime: TimeInterval // 处理时间
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case originalItems, alternativesByItem, globalRecommendations, 
             potentialSavings, processingTime, createdAt
    }
    
    init(originalItems: [String], alternativesByItem: [String: [AlternativeItem]],
         globalRecommendations: [GlobalRecommendation] = [],
         potentialSavings: PotentialSavings = PotentialSavings(),
         processingTime: TimeInterval = 0) {
        self.originalItems = originalItems
        self.alternativesByItem = alternativesByItem
        self.globalRecommendations = globalRecommendations
        self.potentialSavings = potentialSavings
        self.processingTime = processingTime
        self.createdAt = Date()
    }
}

/// 全局建议
struct GlobalRecommendation: Codable, Identifiable {
    let id = UUID()
    let category: ItemCategory
    let suggestion: String
    let affectedItems: [String] // 影响的物品
    let potentialSavings: PotentialSavings
    let priority: Int // 优先级 1-10
    
    enum CodingKeys: String, CodingKey {
        case category, suggestion, affectedItems, potentialSavings, priority
    }
    
    init(category: ItemCategory, suggestion: String, affectedItems: [String],
         potentialSavings: PotentialSavings, priority: Int = 5) {
        self.category = category
        self.suggestion = suggestion
        self.affectedItems = affectedItems
        self.potentialSavings = potentialSavings
        self.priority = priority
    }
}

/// 潜在节省
struct PotentialSavings: Codable {
    let weight: Double // 重量节省（克）
    let volume: Double // 体积节省（立方厘米）
    let cost: Double? // 成本节省（元）
    let spaceUtilization: Double? // 空间利用率提升
    
    init(weight: Double = 0, volume: Double = 0, cost: Double? = nil,
         spaceUtilization: Double? = nil) {
        self.weight = weight
        self.volume = volume
        self.cost = cost
        self.spaceUtilization = spaceUtilization
    }
    
    /// 格式化显示重量节省
    var formattedWeightSaving: String {
        if weight >= 1000 {
            return String(format: "%.1fkg", weight / 1000)
        } else {
            return String(format: "%.0fg", weight)
        }
    }
    
    /// 格式化显示体积节省
    var formattedVolumeSaving: String {
        if volume >= 1000 {
            return String(format: "%.1fL", volume / 1000)
        } else {
            return String(format: "%.0fcm³", volume)
        }
    }
}

// MARK: - 航空公司政策相关扩展模型

/// 航班类型
enum FlightType: String, Codable, CaseIterable {
    case domestic = "domestic"
    case international = "international"
    case regional = "regional"
    
    var displayName: String {
        switch self {
        case .domestic: return "国内航班"
        case .international: return "国际航班"
        case .regional: return "地区航班"
        }
    }
}

/// 舱位等级
enum CabinClass: String, Codable, CaseIterable {
    case economy = "economy"
    case premiumEconomy = "premiumEconomy"
    case business = "business"
    case first = "first"
    
    var displayName: String {
        switch self {
        case .economy: return "经济舱"
        case .premiumEconomy: return "超级经济舱"
        case .business: return "商务舱"
        case .first: return "头等舱"
        }
    }
}

/// 行李尺寸
struct LuggageDimensions: Codable {
    let length: Double // 长度（厘米）
    let width: Double  // 宽度（厘米）
    let height: Double // 高度（厘米）
    
    /// 计算总尺寸（长+宽+高）
    var totalDimension: Double {
        return length + width + height
    }
    
    /// 计算体积
    var volume: Double {
        return length * width * height
    }
    
    /// 格式化显示
    var formatted: String {
        return String(format: "%.0f×%.0f×%.0f cm", length, width, height)
    }
}

/// 政策违规类型
enum ViolationType: String, Codable, CaseIterable {
    case overweight = "overweight"
    case oversized = "oversized"
    case prohibited = "prohibited"
    case restricted = "restricted"
    case liquid = "liquid"
    case battery = "battery"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .overweight: return "超重"
        case .oversized: return "超尺寸"
        case .prohibited: return "禁止携带"
        case .restricted: return "限制携带"
        case .liquid: return "液体限制"
        case .battery: return "电池限制"
        case .other: return "其他"
        }
    }
    
    var icon: String {
        switch self {
        case .overweight: return "⚖️"
        case .oversized: return "📏"
        case .prohibited: return "🚫"
        case .restricted: return "⚠️"
        case .liquid: return "💧"
        case .battery: return "🔋"
        case .other: return "❓"
        }
    }
}

/// 违规严重程度
enum ViolationSeverity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "轻微"
        case .medium: return "中等"
        case .high: return "严重"
        case .critical: return "严重违规"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
}

/// 政策违规
struct PolicyViolation: Codable, Identifiable {
    let id = UUID()
    let itemName: String
    let violationType: ViolationType
    let description: String
    let severity: ViolationSeverity
    let suggestion: String
    
    enum CodingKeys: String, CodingKey {
        case itemName, violationType, description, severity, suggestion
    }
    
    init(itemName: String, violationType: ViolationType, description: String,
         severity: ViolationSeverity, suggestion: String) {
        self.itemName = itemName
        self.violationType = violationType
        self.description = description
        self.severity = severity
        self.suggestion = suggestion
    }
}

/// 政策警告
struct PolicyWarning: Codable, Identifiable {
    let id = UUID()
    let itemName: String
    let warningType: WarningType
    let message: String
    let suggestion: String
    
    enum CodingKeys: String, CodingKey {
        case itemName, warningType, message, suggestion
    }
    
    init(itemName: String, warningType: WarningType, message: String, suggestion: String) {
        self.itemName = itemName
        self.warningType = warningType
        self.message = message
        self.suggestion = suggestion
    }
}

/// 预估费用
struct EstimatedFees: Codable {
    let overweightFee: Double // 超重费用
    let oversizeFee: Double // 超尺寸费用
    let currency: String // 货币单位
    
    /// 总费用
    var totalFee: Double {
        return overweightFee + oversizeFee
    }
    
    /// 格式化显示
    var formatted: String {
        return String(format: "%.2f %@", totalFee, currency)
    }
}

/// 政策检查结果
struct PolicyCheckResult: Codable, Identifiable {
    let id = UUID()
    let overallCompliance: Bool // 总体合规性
    let violations: [PolicyViolation] // 违规项目
    let warnings: [PolicyWarning] // 警告项目
    let recommendations: [String] // 建议
    let estimatedFees: EstimatedFees? // 预估费用
    let checkedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case overallCompliance, violations, warnings, recommendations, estimatedFees, checkedAt
    }
    
    init(overallCompliance: Bool, violations: [PolicyViolation], warnings: [PolicyWarning],
         recommendations: [String], estimatedFees: EstimatedFees? = nil) {
        self.overallCompliance = overallCompliance
        self.violations = violations
        self.warnings = warnings
        self.recommendations = recommendations
        self.estimatedFees = estimatedFees
        self.checkedAt = Date()
    }
    
    /// 是否有严重违规
    var hasCriticalViolations: Bool {
        return violations.contains { $0.severity == .critical || $0.severity == .high }
    }
    
    /// 违规数量
    var violationCount: Int {
        return violations.count
    }
    
    /// 警告数量
    var warningCount: Int {
        return warnings.count
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// 调整对比度
    func adjustContrast(factor: Float) -> UIImage {
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