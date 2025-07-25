import Foundation
import SwiftUI

/// 物品替换服务
/// 处理物品替代建议的自动应用和管理
class ItemReplacementService: ObservableObject {
    
    // MARK: - 单例模式
    
    static let shared = ItemReplacementService()
    
    private init() {}
    
    // MARK: - 可观察属性
    
    /// 待处理的替换建议
    @Published var pendingReplacements: [ReplacementSuggestion] = []
    
    /// 已应用的替换历史
    @Published var replacementHistory: [ReplacementRecord] = []
    
    /// 自动替换设置
    @Published var autoReplacementSettings = AutoReplacementSettings()
    
    // MARK: - 替换建议数据模型
    
    /// 替换建议
    struct ReplacementSuggestion: Identifiable, Codable {
        let id = UUID()
        let originalItem: LuggageItem
        let alternatives: [ItemInfo]
        let constraints: AlternativeConstraints
        let reason: String
        let priority: ReplacementPriority
        let createdAt: Date
        var status: ReplacementStatus
        
        enum ReplacementPriority: String, CaseIterable, Codable {
            case high = "high"
            case medium = "medium"
            case low = "low"
            
            var displayName: String {
                switch self {
                case .high: return "高优先级"
                case .medium: return "中优先级"
                case .low: return "低优先级"
                }
            }
            
            var color: Color {
                switch self {
                case .high: return .red
                case .medium: return .orange
                case .low: return .blue
                }
            }
        }
        
        enum ReplacementStatus: String, CaseIterable, Codable {
            case pending = "pending"
            case accepted = "accepted"
            case rejected = "rejected"
            case applied = "applied"
            
            var displayName: String {
                switch self {
                case .pending: return "待处理"
                case .accepted: return "已接受"
                case .rejected: return "已拒绝"
                case .applied: return "已应用"
                }
            }
        }
    }
    
    /// 替换记录
    struct ReplacementRecord: Identifiable, Codable {
        let id = UUID()
        let originalItem: LuggageItem
        let replacementItem: ItemInfo
        let appliedAt: Date
        let reason: String
        let weightSavings: Double
        let volumeSavings: Double
        let userInitiated: Bool
        
        var savingsDescription: String {
            var description = ""
            if weightSavings > 0 {
                description += "减重\(formatWeight(weightSavings))"
            } else if weightSavings < 0 {
                description += "增重\(formatWeight(abs(weightSavings)))"
            }
            
            if volumeSavings > 0 {
                if !description.isEmpty { description += ", " }
                description += "减少体积\(formatVolume(volumeSavings))"
            } else if volumeSavings < 0 {
                if !description.isEmpty { description += ", " }
                description += "增加体积\(formatVolume(abs(volumeSavings)))"
            }
            
            return description.isEmpty ? "无变化" : description
        }
        
        private func formatWeight(_ grams: Double) -> String {
            if grams >= 1000 {
                return String(format: "%.1fkg", grams / 1000.0)
            } else {
                return String(format: "%.0fg", grams)
            }
        }
        
        private func formatVolume(_ cm3: Double) -> String {
            if cm3 >= 1000 {
                return String(format: "%.1fL", cm3 / 1000.0)
            } else {
                return String(format: "%.0fcm³", cm3)
            }
        }
    }
    
    /// 自动替换设置
    struct AutoReplacementSettings: Codable {
        var isEnabled: Bool = false
        var autoApplyHighPriority: Bool = false
        var autoApplyMediumPriority: Bool = false
        var requireConfirmation: Bool = true
        var maxWeightIncrease: Double = 0 // 允许的最大重量增加（克）
        var maxVolumeIncrease: Double = 0 // 允许的最大体积增加（立方厘米）
        var enabledCategories: Set<ItemCategory> = Set(ItemCategory.allCases)
        var notificationEnabled: Bool = true
    }
    
    // MARK: - 核心方法
    
    /// 添加替换建议
    /// - Parameters:
    ///   - originalItem: 原始物品
    ///   - alternatives: 替代品列表
    ///   - constraints: 约束条件
    ///   - reason: 建议理由
    ///   - priority: 优先级
    func addReplacementSuggestion(
        originalItem: LuggageItem,
        alternatives: [ItemInfo],
        constraints: AlternativeConstraints,
        reason: String,
        priority: ReplacementSuggestion.ReplacementPriority = .medium
    ) {
        let suggestion = ReplacementSuggestion(
            originalItem: originalItem,
            alternatives: alternatives,
            constraints: constraints,
            reason: reason,
            priority: priority,
            createdAt: Date(),
            status: .pending
        )
        
        pendingReplacements.append(suggestion)
        
        // 如果启用了自动替换，尝试自动应用
        if autoReplacementSettings.isEnabled {
            tryAutoApply(suggestion)
        }
        
        // 发送通知
        if autoReplacementSettings.notificationEnabled {
            sendReplacementNotification(suggestion)
        }
    }
    
    /// 接受替换建议
    /// - Parameters:
    ///   - suggestionId: 建议ID
    ///   - selectedAlternativeIndex: 选择的替代品索引
    func acceptReplacementSuggestion(
        suggestionId: UUID,
        selectedAlternativeIndex: Int = 0
    ) {
        guard let index = pendingReplacements.firstIndex(where: { $0.id == suggestionId }),
              selectedAlternativeIndex < pendingReplacements[index].alternatives.count else {
            return
        }
        
        pendingReplacements[index].status = .accepted
        
        let suggestion = pendingReplacements[index]
        let selectedAlternative = suggestion.alternatives[selectedAlternativeIndex]
        
        // 应用替换
        applyReplacement(
            originalItem: suggestion.originalItem,
            replacementItem: selectedAlternative,
            reason: suggestion.reason,
            userInitiated: true
        )
        
        // 从待处理列表中移除
        pendingReplacements.remove(at: index)
    }
    
    /// 拒绝替换建议
    /// - Parameter suggestionId: 建议ID
    func rejectReplacementSuggestion(suggestionId: UUID) {
        guard let index = pendingReplacements.firstIndex(where: { $0.id == suggestionId }) else {
            return
        }
        
        pendingReplacements[index].status = .rejected
        
        // 从待处理列表中移除
        pendingReplacements.remove(at: index)
    }
    
    /// 批量处理替换建议
    /// - Parameter decisions: 决策字典 [建议ID: (是否接受, 选择的替代品索引)]
    func batchProcessReplacements(_ decisions: [UUID: (accept: Bool, alternativeIndex: Int)]) {
        for (suggestionId, decision) in decisions {
            if decision.accept {
                acceptReplacementSuggestion(
                    suggestionId: suggestionId,
                    selectedAlternativeIndex: decision.alternativeIndex
                )
            } else {
                rejectReplacementSuggestion(suggestionId: suggestionId)
            }
        }
    }
    
    /// 撤销替换
    /// - Parameter recordId: 替换记录ID
    func undoReplacement(recordId: UUID) {
        guard let record = replacementHistory.first(where: { $0.id == recordId }) else {
            return
        }
        
        // 这里需要与数据存储层集成，恢复原始物品
        // 暂时只从历史记录中移除
        replacementHistory.removeAll { $0.id == recordId }
        
        // 发送撤销通知
        NotificationCenter.default.post(
            name: .itemReplacementUndone,
            object: record
        )
    }
    
    /// 清理过期的建议
    /// - Parameter maxAge: 最大保留时间（秒）
    func cleanupExpiredSuggestions(maxAge: TimeInterval = 24 * 60 * 60) { // 默认24小时
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        pendingReplacements.removeAll { $0.createdAt < cutoffDate }
    }
    
    /// 获取替换统计信息
    func getReplacementStatistics() -> ReplacementStatistics {
        let totalReplacements = replacementHistory.count
        let totalWeightSavings = replacementHistory.reduce(0) { $0 + $1.weightSavings }
        let totalVolumeSavings = replacementHistory.reduce(0) { $0 + $1.volumeSavings }
        
        let categoryStats = Dictionary(grouping: replacementHistory) { $0.originalItem.category }
            .mapValues { records in
                (
                    count: records.count,
                    weightSavings: records.reduce(0) { $0 + $1.weightSavings },
                    volumeSavings: records.reduce(0) { $0 + $1.volumeSavings }
                )
            }
        
        return ReplacementStatistics(
            totalReplacements: totalReplacements,
            totalWeightSavings: totalWeightSavings,
            totalVolumeSavings: totalVolumeSavings,
            categoryStatistics: categoryStats,
            averageWeightSavings: totalReplacements > 0 ? totalWeightSavings / Double(totalReplacements) : 0,
            averageVolumeSavings: totalReplacements > 0 ? totalVolumeSavings / Double(totalReplacements) : 0
        )
    }
    
    // MARK: - 私有方法
    
    /// 尝试自动应用替换建议
    private func tryAutoApply(_ suggestion: ReplacementSuggestion) {
        // 检查是否符合自动应用条件
        guard shouldAutoApply(suggestion) else { return }
        
        // 选择最佳替代品
        guard let bestAlternative = selectBestAlternative(
            from: suggestion.alternatives,
            for: suggestion.originalItem,
            constraints: suggestion.constraints
        ) else { return }
        
        // 应用替换
        applyReplacement(
            originalItem: suggestion.originalItem,
            replacementItem: bestAlternative,
            reason: suggestion.reason + " (自动应用)",
            userInitiated: false
        )
        
        // 更新建议状态
        if let index = pendingReplacements.firstIndex(where: { $0.id == suggestion.id }) {
            pendingReplacements[index].status = .applied
            pendingReplacements.remove(at: index)
        }
    }
    
    /// 判断是否应该自动应用
    private func shouldAutoApply(_ suggestion: ReplacementSuggestion) -> Bool {
        // 检查全局设置
        guard autoReplacementSettings.isEnabled else { return false }
        
        // 检查类别设置
        guard autoReplacementSettings.enabledCategories.contains(suggestion.originalItem.category) else {
            return false
        }
        
        // 检查优先级设置
        switch suggestion.priority {
        case .high:
            return autoReplacementSettings.autoApplyHighPriority
        case .medium:
            return autoReplacementSettings.autoApplyMediumPriority
        case .low:
            return false // 低优先级不自动应用
        }
    }
    
    /// 选择最佳替代品
    private func selectBestAlternative(
        from alternatives: [ItemInfo],
        for originalItem: LuggageItem,
        constraints: AlternativeConstraints
    ) -> ItemInfo? {
        // 过滤符合约束条件的替代品
        let validAlternatives = alternatives.filter { alternative in
            let weightIncrease = alternative.weight - originalItem.weight
            let volumeIncrease = alternative.volume - originalItem.volume
            
            return weightIncrease <= autoReplacementSettings.maxWeightIncrease &&
                   volumeIncrease <= autoReplacementSettings.maxVolumeIncrease
        }
        
        // 按置信度排序，选择最佳的
        return validAlternatives.max { $0.confidence < $1.confidence }
    }
    
    /// 应用替换
    private func applyReplacement(
        originalItem: LuggageItem,
        replacementItem: ItemInfo,
        reason: String,
        userInitiated: Bool
    ) {
        let weightSavings = originalItem.weight - replacementItem.weight
        let volumeSavings = originalItem.volume - replacementItem.volume
        
        let record = ReplacementRecord(
            originalItem: originalItem,
            replacementItem: replacementItem,
            appliedAt: Date(),
            reason: reason,
            weightSavings: weightSavings,
            volumeSavings: volumeSavings,
            userInitiated: userInitiated
        )
        
        replacementHistory.append(record)
        
        // 发送替换通知
        NotificationCenter.default.post(
            name: .itemReplacementApplied,
            object: record
        )
    }
    
    /// 发送替换建议通知
    private func sendReplacementNotification(_ suggestion: ReplacementSuggestion) {
        NotificationCenter.default.post(
            name: .itemReplacementSuggestionAdded,
            object: suggestion
        )
    }
}

// MARK: - 替换统计信息

struct ReplacementStatistics {
    let totalReplacements: Int
    let totalWeightSavings: Double
    let totalVolumeSavings: Double
    let categoryStatistics: [ItemCategory: (count: Int, weightSavings: Double, volumeSavings: Double)]
    let averageWeightSavings: Double
    let averageVolumeSavings: Double
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let itemReplacementSuggestionAdded = Notification.Name("itemReplacementSuggestionAdded")
    static let itemReplacementApplied = Notification.Name("itemReplacementApplied")
    static let itemReplacementUndone = Notification.Name("itemReplacementUndone")
}