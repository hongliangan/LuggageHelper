import Foundation
import UIKit
import SwiftUI

/// AI 功能视图模型
/// 管理所有 AI 增强功能的状态和业务逻辑
@MainActor
final class AIViewModel: ObservableObject {
    
    // MARK: - 发布属性
    
    /// 是否正在加载
    @Published var isLoading = false
    
    /// 错误消息
    @Published var errorMessage: String?
    
    /// 物品识别结果
    @Published var identifiedItem: ItemInfo?
    
    /// 旅行建议
    @Published var travelSuggestion: TravelSuggestion?
    
    /// 装箱计划
    @Published var packingPlan: PackingPlan?
    
    /// 个性化建议
    @Published var personalizedSuggestions: [SuggestedItem] = []
    
    /// 遗漏物品警告
    @Published var missingItemAlerts: [MissingItemAlert] = []
    
    /// 重量预测结果
    @Published var weightPrediction: WeightPrediction?
    
    /// 替代品建议
    @Published var alternativeItems: [ItemInfo] = []
    
    /// 物品分类结果
    @Published var itemCategory: ItemCategory?
    
    /// 航空公司政策
    @Published var airlinePolicy: AirlineLuggagePolicy?
    
    // MARK: - 私有属性
    
    private let apiService = SiliconFlowAPIService.shared
    let aiService = AIServiceExtensions.shared
    private let configManager = APIConfigurationManager.shared
    
    // MARK: - 物品识别功能
    
    /// 识别物品信息
    /// - Parameters:
    ///   - name: 物品名称
    ///   - model: 物品型号（可选）
    ///   - brand: 品牌（可选）
    ///   - additionalInfo: 额外信息（可选）
    func identifyItem(name: String, model: String? = nil, brand: String? = nil, additionalInfo: String? = nil) async {
        guard !name.isEmpty else {
            errorMessage = "请输入物品名称"
            return
        }
        
        isLoading = true
        errorMessage = nil
        identifiedItem = nil
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.identifyItem(
                name: name,
                model: model,
                brand: brand,
                additionalInfo: additionalInfo
            )
            identifiedItem = result
        } catch {
            handleError(error, message: "物品识别失败")
        }
        
        isLoading = false
    }
    
    /// 从照片识别物品
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - hint: 识别提示（可选）
    func identifyItemFromPhoto(_ imageData: Data, hint: String? = nil) async {
        isLoading = true
        errorMessage = nil
        identifiedItem = nil
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.identifyItemFromPhoto(imageData, hint: hint)
            identifiedItem = result
        } catch {
            handleError(error, message: "照片识别失败")
        }
        
        isLoading = false
    }
    
    /// 批量识别物品
    /// - Parameter items: 物品名称列表
    func batchIdentifyItems(_ items: [String]) async {
        guard !items.isEmpty else {
            errorMessage = "请提供物品列表"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await aiService.batchIdentifyItems(items)
            // 这里可以根据需要处理批量结果
            // 目前只设置最后一个结果作为示例
            if let lastResult = results.last {
                identifiedItem = lastResult
            }
        } catch {
            handleError(error, message: "批量识别失败")
        }
        
        isLoading = false
    }
    
    /// 检查是否支持照片识别
    var supportsPhotoRecognition: Bool {
        return aiService.supportsPhotoRecognition()
    }
    
    /// 自动分类物品
    /// - Parameter item: 物品
    func categorizeItem(_ item: LuggageItemProtocol) async {
        isLoading = true
        errorMessage = nil
        itemCategory = nil
        
        do {
            // 使用增强的 AI 服务
            let category = try await aiService.categorizeItem(item as! LuggageItem)
            itemCategory = category
        } catch {
            handleError(error, message: "物品分类失败")
        }
        
        isLoading = false
    }
    
    /// 批量分类物品
    /// - Parameter items: 物品列表
    /// - Returns: 物品ID到类别的映射
    func batchCategorizeItems(_ items: [LuggageItemProtocol]) async -> [UUID: ItemCategory] {
        guard !items.isEmpty else {
            return [:]
        }
        
        isLoading = true
        errorMessage = nil
        
        var results: [UUID: ItemCategory] = [:]
        
        do {
            // 使用增强的 AI 服务
            results = try await aiService.batchCategorizeItems(items as! [LuggageItem])
        } catch {
            handleError(error, message: "批量分类失败")
        }
        
        isLoading = false
        return results
    }
    
    /// 生成物品标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    func generateItemTags(for item: LuggageItemProtocol) async -> [String] {
        isLoading = true
        errorMessage = nil
        
        var tags: [String] = []
        
        do {
            // 使用增强的 AI 服务
            tags = try await aiService.generateItemTags(for: item as! LuggageItem)
        } catch {
            handleError(error, message: "生成标签失败")
        }
        
        isLoading = false
        return tags
    }
    
    /// 学习用户分类偏好
    /// - Parameters:
    ///   - item: 物品
    ///   - userCategory: 用户指定的类别
    ///   - originalCategory: 原始类别
    func learnUserCategoryPreference(item: LuggageItemProtocol, userCategory: ItemCategory, originalCategory: ItemCategory) {
        aiService.learnUserCategoryPreference(item: item as! LuggageItem, userCategory: userCategory, originalCategory: originalCategory)
    }
    
    /// 获取分类准确性统计
    /// - Returns: 分类准确性统计
    func getCategoryAccuracyStats() -> [String: Any] {
        return aiService.getCategoryAccuracyStats()
    }
    
    // MARK: - 旅行建议功能
    
    /// 生成旅行物品清单
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 旅行天数
    ///   - season: 季节
    ///   - activities: 活动列表
    ///   - userPreferences: 用户偏好（可选）
    func generateTravelSuggestions(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userPreferences: UserPreferences? = nil
    ) async {
        guard !destination.isEmpty else {
            errorMessage = "请输入目的地"
            return
        }
        
        isLoading = true
        errorMessage = nil
        travelSuggestion = nil
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.generateTravelChecklist(
                destination: destination,
                duration: duration,
                season: season,
                activities: activities,
                userPreferences: userPreferences
            )
            travelSuggestion = result
        } catch {
            handleError(error, message: "生成旅行建议失败")
        }
        
        isLoading = false
    }
    
    /// 生成个性化旅行建议
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 旅行天数
    ///   - season: 季节
    ///   - activities: 活动列表
    ///   - userProfile: 用户档案
    func generateComprehensiveTravelAdvice(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userProfile: UserProfile
    ) async {
        guard !destination.isEmpty else {
            errorMessage = "请输入目的地"
            return
        }
        
        isLoading = true
        errorMessage = nil
        travelSuggestion = nil
        personalizedSuggestions = []
        
        do {
            // 创建旅行计划
            let travelPlan = TravelPlan(
                destination: destination,
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: duration, to: Date()) ?? Date(),
                season: season,
                activities: activities
            )
            
            // 并行执行多个 AI 请求
            async let travelSuggestionTask = aiService.generateTravelChecklist(
                destination: destination,
                duration: duration,
                season: season,
                activities: activities,
                userPreferences: userProfile.preferences
            )
            
            async let personalizedSuggestionsTask = aiService.getPersonalizedSuggestions(
                userProfile: userProfile,
                travelPlan: travelPlan
            )
            
            // 等待所有请求完成
            let (travelResult, personalizedResult) = try await (travelSuggestionTask, personalizedSuggestionsTask)
            
            // 更新状态
            travelSuggestion = travelResult
            personalizedSuggestions = personalizedResult
            
        } catch {
            handleError(error, message: "生成个性化旅行建议失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 装箱优化功能
    
    /// 优化装箱方案
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱信息
    func optimizePacking(items: [LuggageItemProtocol], luggage: LuggageProtocol) async {
        guard !items.isEmpty else {
            errorMessage = "请先添加物品"
            return
        }
        
        isLoading = true
        errorMessage = nil
        packingPlan = nil
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.optimizePacking(items: items as! [LuggageItem], luggage: luggage as! Luggage)
            packingPlan = result
        } catch {
            handleError(error, message: "装箱优化失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 个性化建议功能
    
    /// 获取个性化建议
    /// - Parameters:
    ///   - userProfile: 用户档案
    ///   - travelPlan: 旅行计划
    func getPersonalizedSuggestions(userProfile: UserProfile, travelPlan: TravelPlan) async {
        isLoading = true
        errorMessage = nil
        personalizedSuggestions = []
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.getPersonalizedSuggestions(
                userProfile: userProfile,
                travelPlan: travelPlan
            )
            personalizedSuggestions = result
        } catch {
            handleError(error, message: "获取个性化建议失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 遗漏检查功能
    
    /// 检查遗漏物品
    /// - Parameters:
    ///   - checklist: 当前清单
    ///   - travelPlan: 旅行计划
    func checkMissingItems(checklist: [LuggageItemProtocol], travelPlan: TravelPlan) async {
        isLoading = true
        errorMessage = nil
        missingItemAlerts = []
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.checkMissingItems(
                checklist: checklist as! [LuggageItem],
                travelPlan: travelPlan
            )
            missingItemAlerts = result
        } catch {
            handleError(error, message: "检查遗漏物品失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 重量预测功能
    
    /// 预测行李重量
    /// - Parameter items: 物品列表
    func predictWeight(items: [LuggageItemProtocol]) async {
        guard !items.isEmpty else {
            errorMessage = "请先添加物品"
            return
        }
        
        isLoading = true
        errorMessage = nil
        weightPrediction = nil
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.predictWeight(items: items as! [LuggageItem])
            weightPrediction = result
        } catch {
            handleError(error, message: "重量预测失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 替代品建议功能
    
    /// 建议替代品
    /// - Parameters:
    ///   - item: 原物品
    ///   - constraints: 约束条件
    func suggestAlternatives(for item: LuggageItemProtocol, constraints: PackingConstraints) async {
        isLoading = true
        errorMessage = nil
        alternativeItems = []
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.suggestAlternatives(
                for: item as! LuggageItem,
                constraints: constraints
            )
            alternativeItems = result
        } catch {
            handleError(error, message: "获取替代品建议失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 航空公司政策查询
    
    /// 查询航空公司行李政策
    /// - Parameter airline: 航空公司名称
    func queryAirlinePolicy(airline: String) async {
        guard !airline.isEmpty else {
            errorMessage = "请输入航空公司名称"
            return
        }
        
        isLoading = true
        errorMessage = nil
        airlinePolicy = nil
        
        do {
            // 使用增强的 AI 服务
            let result = try await aiService.queryAirlinePolicy(airline: airline)
            airlinePolicy = result
        } catch {
            handleError(error, message: "查询航空公司政策失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 错误处理
    
    /// 处理错误
    /// - Parameters:
    ///   - error: 错误
    ///   - message: 错误前缀消息
    private func handleError(_ error: Error, message: String) {
        if let aiError = error as? AIServiceExtensions.AIServiceError {
            errorMessage = "\(message): \(aiError.localizedDescription)"
        } else {
            errorMessage = "\(message): \(error.localizedDescription)"
        }
    }
    
    // MARK: - 调试功能
    
    /// 启用调试模式
    func enableDebugMode(_ enabled: Bool) {
        aiService.enableDebugMode = enabled
    }
    
    /// 清除缓存
    func clearCache() {
        aiService.clearAllCache()
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> [String: Any] {
        return aiService.getCacheStats()
    }
    
    // MARK: - 状态管理
    
    /// 重置所有状态
    func resetAllStates() {
        isLoading = false
        errorMessage = nil
        identifiedItem = nil
        travelSuggestion = nil
        packingPlan = nil
        personalizedSuggestions = []
        missingItemAlerts = []
        weightPrediction = nil
        alternativeItems = []
        itemCategory = nil
        airlinePolicy = nil
    }
    
    /// 重置错误状态
    func clearError() {
        errorMessage = nil
    }
    
    /// 检查是否有任何结果
    var hasAnyResults: Bool {
        return identifiedItem != nil ||
               travelSuggestion != nil ||
               packingPlan != nil ||
               !personalizedSuggestions.isEmpty ||
               !missingItemAlerts.isEmpty ||
               weightPrediction != nil ||
               !alternativeItems.isEmpty ||
               itemCategory != nil ||
               airlinePolicy != nil
    }
    
    /// 获取当前状态摘要
    var statusSummary: String {
        if isLoading {
            return "正在处理中..."
        } else if let error = errorMessage {
            return "错误: \(error)"
        } else if hasAnyResults {
            return "已完成"
        } else {
            return "就绪"
        }
    }
    
    // MARK: - 批量操作
    
    /// 批量识别物品名称
    /// - Parameter items: 物品名称列表
    func batchIdentifyItemNames(_ items: [String]) async {
        guard !items.isEmpty else {
            errorMessage = "请提供物品列表"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var results: [ItemInfo] = []
        
        for itemName in items {
            do {
                let result = try await aiService.identifyItem(name: itemName)
                results.append(result)
            } catch {
                // 继续处理其他物品，但记录错误
                print("识别物品 \(itemName) 失败: \(error)")
            }
        }
        
        // 这里可以添加批量结果的处理逻辑
        // 目前只设置最后一个结果
        if let lastResult = results.last {
            identifiedItem = lastResult
        }
        
        isLoading = false
    }
    
    /// 生成综合旅行建议
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 天数
    ///   - season: 季节
    ///   - activities: 活动
    ///   - userProfile: 用户档案
    func generateComprehensiveTravelAdvice(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userProfile: UserProfile? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        // 并行执行多个 AI 请求
        async let travelSuggestionTask = aiService.generateTravelChecklist(
            destination: destination,
            duration: duration,
            season: season,
            activities: activities,
            userPreferences: userProfile?.preferences
        )
        
        async let personalizedSuggestionsTask: [SuggestedItem] = {
            if let profile = userProfile {
                let travelPlan = TravelPlan(
                    destination: destination,
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: duration, to: Date()) ?? Date(),
                    season: season,
                    activities: activities
                )
                return try await aiService.getPersonalizedSuggestions(
                    userProfile: profile,
                    travelPlan: travelPlan
                )
            } else {
                return []
            }
        }()
        
        do {
            let (travelResult, personalizedResult) = try await (travelSuggestionTask, personalizedSuggestionsTask)
            
            travelSuggestion = travelResult
            personalizedSuggestions = personalizedResult
            
        } catch {
            handleError(error, message: "生成综合旅行建议失败")
        }
        
        isLoading = false
    }
    
    // MARK: - 智能建议
    
    /// 获取智能建议
    func getSmartSuggestions() -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // 基于当前状态生成建议
        if let prediction = weightPrediction {
            if prediction.totalWeight > 20000 { // 20kg
                suggestions.append(SmartSuggestion(
                    type: .weightReduction,
                    title: "行李超重提醒",
                    description: "您的行李重量为 \(String(format: "%.1f", prediction.totalWeight/1000))kg，建议减少一些物品",
                    priority: 8
                ))
            }
        }
        
        if let plan = packingPlan {
            if plan.efficiency < 0.7 {
                suggestions.append(SmartSuggestion(
                    type: .spaceOptimization,
                    title: "空间利用率偏低",
                    description: "当前空间利用率为 \(String(format: "%.1f", plan.efficiency * 100))%，可以优化装箱方案",
                    priority: 6
                ))
            }
        }
        
        if !missingItemAlerts.isEmpty {
            let essentialMissing = missingItemAlerts.filter { $0.importance == .essential }
            if !essentialMissing.isEmpty {
                suggestions.append(SmartSuggestion(
                    type: .safetyWarning,
                    title: "缺少必需品",
                    description: "您可能遗漏了 \(essentialMissing.count) 个必需品",
                    priority: 9
                ))
            }
        }
        
        return suggestions.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - 数据导出
    
    /// 导出所有 AI 建议数据
    func exportAllData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let item = identifiedItem {
            data["identifiedItem"] = [
                "name": item.name,
                "category": item.category.rawValue,
                "weight": item.weight,
                "volume": item.volume,
                "confidence": item.confidence
            ]
        }
        
        if let suggestion = travelSuggestion {
            data["travelSuggestion"] = [
                "destination": suggestion.destination,
                "duration": suggestion.duration,
                "itemsCount": suggestion.suggestedItems.count,
                "essentialItemsCount": suggestion.essentialItemsCount
            ]
        }
        
        if let plan = packingPlan {
            data["packingPlan"] = [
                "totalWeight": plan.totalWeight,
                "totalVolume": plan.totalVolume,
                "efficiency": plan.efficiency,
                "warningsCount": plan.warnings.count
            ]
        }
        
        data["personalizedSuggestionsCount"] = personalizedSuggestions.count
        data["missingItemAlertsCount"] = missingItemAlerts.count
        data["alternativeItemsCount"] = alternativeItems.count
        
        return data
    }
}