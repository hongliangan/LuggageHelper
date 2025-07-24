import Foundation
import Combine
import UIKit

/// AI 物品分类管理器
/// 负责物品分类、学习用户偏好和分类准确性评估
final class AIItemCategoryManager {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = AIItemCategoryManager()
    
    /// 私有初始化
    private init() {
        loadUserPreferences()
        loadCategoryRules()
    }
    
    // MARK: - 属性
    
    /// AI 服务
    private let aiService = AIServiceExtensions.shared
    
    /// 用户分类偏好
    private var userCategoryPreferences: [String: ItemCategory] = [:]
    
    /// 分类规则
    private var categoryRules: [CategoryRule] = []
    
    /// 分类历史
    private var categoryHistory: [CategoryHistoryEntry] = []
    
    /// 分类准确性统计
    private var accuracyStats = CategoryAccuracyStats()
    
    /// 分类变更发布者
    let categoryChangesPublisher = PassthroughSubject<[UUID: ItemCategory], Never>()
    
    // MARK: - 数据模型
    
    /// 分类规则
    struct CategoryRule: Codable {
        let keywords: [String]
        let category: ItemCategory
        let priority: Int // 优先级，数字越大优先级越高
        let source: RuleSource
        
        enum RuleSource: String, Codable {
            case system // 系统预定义
            case ai     // AI 生成
            case user   // 用户定义
        }
    }
    
    /// 分类历史记录
    struct CategoryHistoryEntry: Codable {
        let itemName: String
        let originalCategory: ItemCategory?
        let aiCategory: ItemCategory
        let userCategory: ItemCategory?
        let timestamp: Date
        let confidence: Double
        
        var wasCorrect: Bool {
            guard let userCategory = userCategory else { return true }
            return aiCategory == userCategory
        }
    }
    
    /// 分类准确性统计
    struct CategoryAccuracyStats: Codable {
        var totalClassifications: Int = 0
        var correctClassifications: Int = 0
        var userCorrections: Int = 0
        var categoryCorrections: [ItemCategory: Int] = [:]
        
        var accuracy: Double {
            guard totalClassifications > 0 else { return 0 }
            return Double(correctClassifications) / Double(totalClassifications)
        }
        
        /// 最常被纠正的类别
        var mostCorrectedCategories: [(ItemCategory, Int)] {
            return categoryCorrections.sorted { $0.value > $1.value }
        }
        
        /// 更新统计
        mutating func update(wasCorrect: Bool, category: ItemCategory? = nil) {
            totalClassifications += 1
            
            if wasCorrect {
                correctClassifications += 1
            } else {
                userCorrections += 1
                if let category = category {
                    categoryCorrections[category, default: 0] += 1
                }
            }
        }
    }
    
    // MARK: - 公共方法
    
    /// 分类物品
    /// - Parameter item: 物品
    /// - Returns: 物品类别和置信度
    func categorizeItem(_ item: LuggageItemProtocol) async throws -> (category: ItemCategory, confidence: Double) {
        // 1. 检查用户偏好
        if let userPreferredCategory = userCategoryPreferences[item.name.lowercased()] {
            // 发布分类变更
            categoryChangesPublisher.send([item.id: userPreferredCategory])
            return (userPreferredCategory, 1.0)
        }
        
        // 2. 应用规则匹配
        if let (ruleCategory, confidence) = applyRules(to: item) {
            // 如果规则匹配的置信度高，直接返回
            if confidence > 0.8 {
                // 发布分类变更
                categoryChangesPublisher.send([item.id: ruleCategory])
                return (ruleCategory, confidence)
            }
        }
        
        // 3. 使用 AI 服务
        do {
            let luggageItem = LuggageItem(id: item.id, name: item.name, volume: item.volume, weight: item.weight)
            let aiCategory = try await aiService.categorizeItem(luggageItem)
            
            // 记录分类历史
            let historyEntry = CategoryHistoryEntry(
                itemName: item.name,
                originalCategory: nil,
                aiCategory: aiCategory,
                userCategory: nil,
                timestamp: Date(),
                confidence: 0.9
            )
            addToHistory(historyEntry)
            
            // 发布分类变更
            categoryChangesPublisher.send([item.id: aiCategory])
            
            return (aiCategory, 0.9)
        } catch {
            // 4. 如果 AI 服务失败，回退到规则匹配
            if let (ruleCategory, confidence) = applyRules(to: item) {
                // 发布分类变更
                categoryChangesPublisher.send([item.id: ruleCategory])
                return (ruleCategory, confidence)
            }
            
            // 5. 最后回退到默认类别
            let defaultCategory = getDefaultCategory(for: item)
            // 发布分类变更
            categoryChangesPublisher.send([item.id: defaultCategory])
            return (defaultCategory, 0.5)
        }
    }
    
    /// 批量分类物品
    /// - Parameter items: 物品列表
    /// - Returns: 物品ID到类别的映射
    func batchCategorizeItems(_ items: [LuggageItemProtocol]) async -> [UUID: ItemCategory] {
        var results: [UUID: ItemCategory] = [:]
        
        // 限制并发数量
        let maxConcurrentTasks = 5
        var activeTasks = 0
        let semaphore = DispatchSemaphore(value: maxConcurrentTasks)
        
        // 并行处理多个分类请求
        await withTaskGroup(of: (UUID, ItemCategory, Double).self) { group in
            for item in items {
                // 等待信号量
                _ = semaphore.wait(timeout: .distantFuture)
                
                group.addTask {
                    defer {
                        // 释放信号量
                        semaphore.signal()
                    }
                    
                    do {
                        let (category, confidence) = try await self.categorizeItem(item)
                        return (item.id, category, confidence)
                    } catch {
                        // 失败时使用默认类别
                        let defaultCategory = self.getDefaultCategory(for: item)
                        return (item.id, defaultCategory, 0.5)
                    }
                }
            }
            
            for await (itemId, category, _) in group {
                results[itemId] = category
            }
        }
        
        // 批量发布分类变更
        if !results.isEmpty {
            categoryChangesPublisher.send(results)
        }
        
        return results
    }
    
    /// 学习用户分类偏好
    /// - Parameters:
    ///   - item: 物品
    ///   - userCategory: 用户指定的类别
    ///   - originalCategory: 原始类别
    func learnUserCategoryPreference(item: LuggageItemProtocol, userCategory: ItemCategory, originalCategory: ItemCategory) {
        // 记录用户偏好
        userCategoryPreferences[item.name.lowercased()] = userCategory
        
        // 记录分类历史
        let historyEntry = CategoryHistoryEntry(
            itemName: item.name,
            originalCategory: originalCategory,
            aiCategory: originalCategory,
            userCategory: userCategory,
            timestamp: Date(),
            confidence: 1.0
        )
        addToHistory(historyEntry)
        
        // 更新统计
        accuracyStats.update(wasCorrect: originalCategory == userCategory, category: originalCategory)
        
        // 如果用户多次将相似物品分到同一类别，创建新规则
        createRuleIfNeeded(for: item.name, category: userCategory)
        
        // 保存用户偏好
        saveUserPreferences()
    }
    
    /// 添加自定义分类规则
    /// - Parameters:
    ///   - keywords: 关键词列表
    ///   - category: 物品类别
    ///   - priority: 优先级
    func addCustomRule(keywords: [String], category: ItemCategory, priority: Int = 10) {
        let rule = CategoryRule(
            keywords: keywords,
            category: category,
            priority: priority,
            source: .user
        )
        
        // 添加规则
        categoryRules.append(rule)
        
        // 按优先级排序
        categoryRules.sort { $0.priority > $1.priority }
        
        // 保存规则
        saveCategoryRules()
    }
    
    /// 获取分类准确性统计
    /// - Returns: 分类准确性统计
    func getCategoryAccuracyStats() -> [String: Any] {
        return [
            "totalClassifications": accuracyStats.totalClassifications,
            "correctClassifications": accuracyStats.correctClassifications,
            "accuracy": accuracyStats.accuracy,
            "userCorrections": accuracyStats.userCorrections,
            "mostCorrectedCategories": accuracyStats.mostCorrectedCategories.prefix(5).map {
                [$0.0.rawValue: $0.1]
            }
        ]
    }
    
    /// 生成物品标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    func generateItemTags(for item: LuggageItemProtocol) async throws -> [String] {
        // 首先尝试使用 AI 服务
        do {
            let luggageItem = LuggageItem(id: item.id, name: item.name, volume: item.volume, weight: item.weight)
            return try await aiService.generateItemTags(for: luggageItem)
        } catch {
            // 如果 AI 服务失败，生成基本标签
            return generateBasicTags(for: item)
        }
    }
    
    /// 重置学习数据
    func resetLearningData() {
        userCategoryPreferences.removeAll()
        categoryHistory.removeAll()
        accuracyStats = CategoryAccuracyStats()
        
        // 只保留系统规则
        categoryRules = categoryRules.filter { $0.source == .system }
        
        saveUserPreferences()
        saveCategoryRules()
    }
    
    // MARK: - 私有方法
    
    /// 应用规则匹配
    /// - Parameter item: 物品
    /// - Returns: 匹配的类别和置信度
    private func applyRules(to item: LuggageItemProtocol) -> (ItemCategory, Double)? {
        let itemName = item.name.lowercased()
        
        // 按优先级应用规则
        for rule in categoryRules {
            // 检查是否有关键词匹配
            let matchingKeywords = rule.keywords.filter { keyword in
                itemName.contains(keyword.lowercased())
            }
            
            if !matchingKeywords.isEmpty {
                // 计算匹配度
                let matchRatio = Double(matchingKeywords.count) / Double(rule.keywords.count)
                let confidence = 0.6 + (matchRatio * 0.4) // 最高1.0，最低0.6
                
                return (rule.category, confidence)
            }
        }
        
        return nil
    }
    
    /// 获取默认类别
    /// - Parameter item: 物品
    /// - Returns: 默认类别
    private func getDefaultCategory(for item: LuggageItemProtocol) -> ItemCategory {
        // 基于物品名称的简单启发式规则
        let name = item.name.lowercased()
        
        if name.contains("手机") || name.contains("电脑") || name.contains("充电器") || name.contains("相机") {
            return .electronics
        } else if name.contains("衣") || name.contains("裤") || name.contains("袜") || name.contains("衫") {
            return .clothing
        } else if name.contains("鞋") {
            return .shoes
        } else if name.contains("洗") || name.contains("牙刷") || name.contains("毛巾") {
            return .toiletries
        } else if name.contains("护照") || name.contains("证") || name.contains("票") {
            return .documents
        } else if name.contains("药") || name.contains("膏") {
            return .medicine
        } else if name.contains("书") || name.contains("笔") {
            return .books
        } else if name.contains("食") || name.contains("水") || name.contains("饮料") {
            return .food
        } else if name.contains("球") || name.contains("运动") {
            return .sports
        } else if name.contains("化妆") || name.contains("口红") || name.contains("粉底") {
            return .beauty
        } else if name.contains("包") || name.contains("帽") || name.contains("眼镜") || name.contains("手表") {
            return .accessories
        }
        
        return .other
    }
    
    /// 生成基本标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    private func generateBasicTags(for item: LuggageItemProtocol) -> [String] {
        var tags: [String] = []
        let name = item.name
        
        // 添加物品名称作为标签
        tags.append(name)
        
        // 添加类别作为标签
        let category = getDefaultCategory(for: item)
        tags.append(category.displayName)
        
        // 根据物品名称添加一些常见标签
        if name.contains("手机") || name.contains("iPhone") || name.contains("iPad") {
            tags.append("电子")
            tags.append("设备")
            tags.append("充电")
        } else if name.contains("衣") || name.contains("裤") || name.contains("鞋") {
            tags.append("穿着")
            tags.append("服装")
        } else if name.contains("书") || name.contains("笔") {
            tags.append("阅读")
            tags.append("文具")
        }
        
        return Array(Set(tags)) // 去重
    }
    
    /// 添加到历史记录
    /// - Parameter entry: 历史记录条目
    private func addToHistory(_ entry: CategoryHistoryEntry) {
        categoryHistory.append(entry)
        
        // 限制历史记录数量
        if categoryHistory.count > 1000 {
            categoryHistory.removeFirst(categoryHistory.count - 1000)
        }
    }
    
    /// 创建规则（如果需要）
    /// - Parameters:
    ///   - itemName: 物品名称
    ///   - category: 类别
    private func createRuleIfNeeded(for itemName: String, category: ItemCategory) {
        // 分析历史记录，查找相似物品的模式
        let similarItems = categoryHistory.filter { entry in
            entry.userCategory == category &&
            entry.aiCategory != category &&
            hasSimilarName(entry.itemName, to: itemName)
        }
        
        // 如果有足够多的相似物品被用户分到同一类别，创建新规则
        if similarItems.count >= 3 {
            // 提取共同关键词
            let commonKeywords = extractCommonKeywords(from: similarItems.map { $0.itemName } + [itemName])
            
            if !commonKeywords.isEmpty {
                addCustomRule(keywords: commonKeywords, category: category, priority: 15)
            }
        }
    }
    
    /// 检查名称是否相似
    /// - Parameters:
    ///   - name1: 名称1
    ///   - name2: 名称2
    /// - Returns: 是否相似
    private func hasSimilarName(_ name1: String, to name2: String) -> Bool {
        let name1Words = name1.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let name2Words = name2.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // 检查是否有共同单词
        let commonWords = Set(name1Words).intersection(Set(name2Words))
        return !commonWords.isEmpty
    }
    
    /// 提取共同关键词
    /// - Parameter names: 名称列表
    /// - Returns: 共同关键词
    private func extractCommonKeywords(from names: [String]) -> [String] {
        guard !names.isEmpty else { return [] }
        
        // 分词
        let allWords = names.flatMap { name in
            name.lowercased().components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count >= 2 } // 过滤掉太短的词
        }
        
        // 统计词频
        var wordCounts: [String: Int] = [:]
        for word in allWords {
            wordCounts[word, default: 0] += 1
        }
        
        // 选择出现频率高的词作为关键词
        let threshold = max(2, names.count / 2)
        let keywords = wordCounts.filter { $0.value >= threshold }.keys.sorted()
        
        return Array(keywords)
    }
    
    // MARK: - 持久化
    
    /// 保存用户偏好
    private func saveUserPreferences() {
        let data: [String: Any] = [
            "userCategoryPreferences": userCategoryPreferences.mapValues { $0.rawValue },
            "categoryHistory": categoryHistory.prefix(100).map { entry in
                [
                    "itemName": entry.itemName,
                    "originalCategory": entry.originalCategory?.rawValue ?? "",
                    "aiCategory": entry.aiCategory.rawValue,
                    "userCategory": entry.userCategory?.rawValue ?? "",
                    "timestamp": entry.timestamp.timeIntervalSince1970,
                    "confidence": entry.confidence
                ]
            },
            "accuracyStats": [
                "totalClassifications": accuracyStats.totalClassifications,
                "correctClassifications": accuracyStats.correctClassifications,
                "userCorrections": accuracyStats.userCorrections,
                "categoryCorrections": accuracyStats.categoryCorrections.mapValues { $0 }
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
            UserDefaults.standard.set(jsonData, forKey: UserDefaultsKeys.userCategoryPreferences)
        }
    }
    
    /// 加载用户偏好
    private func loadUserPreferences() {
        guard let jsonData = UserDefaults.standard.data(forKey: UserDefaultsKeys.userCategoryPreferences),
              let data = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }
        
        // 加载用户分类偏好
        if let preferences = data["userCategoryPreferences"] as? [String: String] {
            for (key, value) in preferences {
                if let category = ItemCategory(rawValue: value) {
                    userCategoryPreferences[key] = category
                }
            }
        }
        
        // 加载分类历史
        if let history = data["categoryHistory"] as? [[String: Any]] {
            categoryHistory = history.compactMap { entry in
                guard let itemName = entry["itemName"] as? String,
                      let aiCategoryString = entry["aiCategory"] as? String,
                      let aiCategory = ItemCategory(rawValue: aiCategoryString),
                      let timestamp = entry["timestamp"] as? TimeInterval,
                      let confidence = entry["confidence"] as? Double else {
                    return nil
                }
                
                let originalCategoryString = entry["originalCategory"] as? String
                let originalCategory = originalCategoryString.flatMap { ItemCategory(rawValue: $0) }
                
                let userCategoryString = entry["userCategory"] as? String
                let userCategory = userCategoryString.flatMap { ItemCategory(rawValue: $0) }
                
                return CategoryHistoryEntry(
                    itemName: itemName,
                    originalCategory: originalCategory,
                    aiCategory: aiCategory,
                    userCategory: userCategory,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    confidence: confidence
                )
            }
        }
        
        // 加载准确性统计
        if let stats = data["accuracyStats"] as? [String: Any] {
            accuracyStats.totalClassifications = stats["totalClassifications"] as? Int ?? 0
            accuracyStats.correctClassifications = stats["correctClassifications"] as? Int ?? 0
            accuracyStats.userCorrections = stats["userCorrections"] as? Int ?? 0
            
            if let corrections = stats["categoryCorrections"] as? [String: Int] {
                for (key, value) in corrections {
                    if let category = ItemCategory(rawValue: key) {
                        accuracyStats.categoryCorrections[category] = value
                    }
                }
            }
        }
    }
    
    /// 保存分类规则
    private func saveCategoryRules() {
        let rulesData = categoryRules.map { rule in
            [
                "keywords": rule.keywords,
                "category": rule.category.rawValue,
                "priority": rule.priority,
                "source": rule.source.rawValue
            ]
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: rulesData) {
            UserDefaults.standard.set(jsonData, forKey: UserDefaultsKeys.categoryRules)
        }
    }
    
    /// 加载分类规则
    private func loadCategoryRules() {
        // 首先加载预定义规则
        categoryRules = predefinedCategoryRules()
        
        // 然后加载用户自定义规则
        guard let jsonData = UserDefaults.standard.data(forKey: UserDefaultsKeys.categoryRules),
              let rulesData = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return
        }
        
        let loadedRules = rulesData.compactMap { ruleData -> CategoryRule? in
            guard let keywordsArray = ruleData["keywords"] as? [String],
                  let categoryString = ruleData["category"] as? String,
                  let category = ItemCategory(rawValue: categoryString),
                  let priority = ruleData["priority"] as? Int,
                  let sourceString = ruleData["source"] as? String,
                  let source = CategoryRule.RuleSource(rawValue: sourceString) else {
                return nil
            }
            
            return CategoryRule(
                keywords: keywordsArray,
                category: category,
                priority: priority,
                source: source
            )
        }
        
        // 只添加用户和 AI 规则，系统规则已经在 predefinedCategoryRules 中添加
        let customRules = loadedRules.filter { $0.source != .system }
        categoryRules.append(contentsOf: customRules)
        
        // 按优先级排序
        categoryRules.sort { $0.priority > $1.priority }
    }
    
    /// 预定义分类规则
    /// - Returns: 预定义规则列表
    private func predefinedCategoryRules() -> [CategoryRule] {
        return [
            // 电子产品
            CategoryRule(
                keywords: ["手机", "电话", "iphone", "android", "smartphone"],
                category: .electronics,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["电脑", "笔记本", "laptop", "macbook", "notebook"],
                category: .electronics,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["平板", "ipad", "tablet"],
                category: .electronics,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["充电器", "电源", "适配器", "charger", "adapter"],
                category: .electronics,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["相机", "摄像机", "camera", "gopro"],
                category: .electronics,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["耳机", "耳麦", "airpods", "headphone"],
                category: .electronics,
                priority: 10,
                source: .system
            ),
            
            // 衣物
            CategoryRule(
                keywords: ["衬衫", "shirt", "衬衣"],
                category: .clothing,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["t恤", "tshirt", "短袖"],
                category: .clothing,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["裤子", "裤", "pants", "trousers", "牛仔裤", "短裤"],
                category: .clothing,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["外套", "夹克", "jacket", "coat"],
                category: .clothing,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["内衣", "内裤", "bra", "underwear"],
                category: .clothing,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["袜子", "袜", "socks"],
                category: .clothing,
                priority: 10,
                source: .system
            ),
            
            // 鞋类
            CategoryRule(
                keywords: ["鞋", "shoes", "运动鞋", "皮鞋", "靴子", "凉鞋"],
                category: .shoes,
                priority: 10,
                source: .system
            ),
            
            // 洗漱用品
            CategoryRule(
                keywords: ["牙刷", "牙膏", "toothbrush", "toothpaste"],
                category: .toiletries,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["洗发水", "沐浴露", "香皂", "shampoo", "soap", "shower gel"],
                category: .toiletries,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["毛巾", "towel", "洗脸巾"],
                category: .toiletries,
                priority: 10,
                source: .system
            ),
            
            // 证件文件
            CategoryRule(
                keywords: ["护照", "passport", "身份证", "id card"],
                category: .documents,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["机票", "车票", "ticket", "boarding pass"],
                category: .documents,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["证", "license", "permit", "card"],
                category: .documents,
                priority: 10,
                source: .system
            ),
            
            // 药品保健
            CategoryRule(
                keywords: ["药", "medicine", "药片", "药水"],
                category: .medicine,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["创可贴", "绷带", "bandage", "band-aid"],
                category: .medicine,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["维生素", "vitamin", "保健品", "supplement"],
                category: .medicine,
                priority: 10,
                source: .system
            ),
            
            // 配饰用品
            CategoryRule(
                keywords: ["帽子", "hat", "cap", "头巾"],
                category: .accessories,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["眼镜", "墨镜", "glasses", "sunglasses"],
                category: .accessories,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["手表", "watch", "腕表"],
                category: .accessories,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["包", "bag", "背包", "钱包", "wallet"],
                category: .accessories,
                priority: 10,
                source: .system
            ),
            
            // 书籍文具
            CategoryRule(
                keywords: ["书", "book", "杂志", "magazine"],
                category: .books,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["笔", "pen", "铅笔", "钢笔", "记事本", "notebook"],
                category: .books,
                priority: 10,
                source: .system
            ),
            
            // 食品饮料
            CategoryRule(
                keywords: ["食品", "零食", "snack", "food"],
                category: .food,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["水", "饮料", "water", "drink", "beverage"],
                category: .food,
                priority: 10,
                source: .system
            ),
            
            // 运动用品
            CategoryRule(
                keywords: ["运动", "sport", "健身", "fitness"],
                category: .sports,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["球", "ball", "拍", "racket"],
                category: .sports,
                priority: 10,
                source: .system
            ),
            
            // 美容化妆
            CategoryRule(
                keywords: ["化妆品", "makeup", "cosmetics"],
                category: .beauty,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["口红", "lipstick", "粉底", "foundation"],
                category: .beauty,
                priority: 10,
                source: .system
            ),
            CategoryRule(
                keywords: ["面膜", "mask", "护肤", "skincare"],
                category: .beauty,
                priority: 10,
                source: .system
            )
        ]
    }
}