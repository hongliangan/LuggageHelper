import Foundation
import SwiftUI

// MARK: - 撤销重做管理服务
@MainActor
class UndoRedoManager: ObservableObject {
    static let shared = UndoRedoManager()
    
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var undoActionTitle: String?
    @Published var redoActionTitle: String?
    
    private var undoStack: [UndoableAction] = []
    private var redoStack: [UndoableAction] = []
    private let maxStackSize = 50
    
    private init() {}
    
    // MARK: - 核心操作
    
    /// 执行可撤销的操作
    func execute(_ action: UndoableAction) {
        // 执行操作
        action.execute()
        
        // 添加到撤销栈
        undoStack.append(action)
        
        // 清空重做栈（执行新操作后，之前的重做历史失效）
        redoStack.removeAll()
        
        // 限制栈大小
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        updateState()
    }
    
    /// 撤销操作
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        let action = undoStack.removeLast()
        
        // 执行撤销
        action.undo()
        
        // 添加到重做栈
        redoStack.append(action)
        
        updateState()
    }
    
    /// 重做操作
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        let action = redoStack.removeLast()
        
        // 执行重做
        action.execute()
        
        // 添加回撤销栈
        undoStack.append(action)
        
        updateState()
    }
    
    // MARK: - 批量操作
    
    /// 开始批量操作组
    func beginGroup(title: String) {
        let groupAction = GroupAction(title: title)
        execute(groupAction)
    }
    
    /// 添加操作到当前组
    func addToCurrentGroup(_ action: UndoableAction) {
        guard let lastAction = undoStack.last as? GroupAction else {
            // 如果没有活动组，直接执行
            execute(action)
            return
        }
        
        action.execute()
        lastAction.addAction(action)
        updateState()
    }
    
    /// 结束批量操作组
    func endGroup() {
        // 组操作已经在beginGroup时添加到栈中
        updateState()
    }
    
    // MARK: - 便捷方法
    
    /// 添加物品操作
    func addItem(_ item: LuggageItem, to container: ItemContainer) {
        let action = AddItemAction(item: item, container: container)
        execute(action)
    }
    
    /// 删除物品操作
    func deleteItem(_ item: LuggageItem, from container: ItemContainer) {
        let action = DeleteItemAction(item: item, container: container)
        execute(action)
    }
    
    /// 修改物品操作
    func modifyItem(original: LuggageItem, modified: LuggageItem, in container: ItemContainer) {
        let action = ModifyItemAction(original: original, modified: modified, container: container)
        execute(action)
    }
    
    /// 移动物品操作
    func moveItem(_ item: LuggageItem, from source: ItemContainer, to destination: ItemContainer) {
        let action = MoveItemAction(item: item, source: source, destination: destination)
        execute(action)
    }
    
    /// 添加行李箱操作
    func addLuggage(_ luggage: Luggage) {
        let action = AddLuggageAction(luggage: luggage)
        execute(action)
    }
    
    /// 删除行李箱操作
    func deleteLuggage(_ luggage: Luggage) {
        let action = DeleteLuggageAction(luggage: luggage)
        execute(action)
    }
    
    /// 修改行李箱操作
    func modifyLuggage(original: Luggage, modified: Luggage) {
        let action = ModifyLuggageAction(original: original, modified: modified)
        execute(action)
    }
    
    /// 清单操作
    func modifyChecklist(original: [TravelChecklistItem], modified: [TravelChecklistItem]) {
        let action = ModifyChecklistAction(original: original, modified: modified)
        execute(action)
    }
    
    // MARK: - 状态管理
    
    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoActionTitle = undoStack.last?.title
        redoActionTitle = redoStack.last?.title
    }
    
    // MARK: - 栈管理
    
    /// 清空所有历史
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }
    
    /// 清空撤销栈
    func clearUndoStack() {
        undoStack.removeAll()
        updateState()
    }
    
    /// 清空重做栈
    func clearRedoStack() {
        redoStack.removeAll()
        updateState()
    }
    
    /// 获取历史统计
    func getHistoryStatistics() -> UndoRedoStatistics {
        var actionTypeCount: [String: Int] = [:]
        
        for action in undoStack {
            let typeName = String(describing: type(of: action))
            actionTypeCount[typeName, default: 0] += 1
        }
        
        return UndoRedoStatistics(
            undoStackSize: undoStack.count,
            redoStackSize: redoStack.count,
            actionTypeDistribution: actionTypeCount,
            memoryUsage: estimateMemoryUsage()
        )
    }
    
    private func estimateMemoryUsage() -> Int {
        // 简单估算内存使用量
        return (undoStack.count + redoStack.count) * 1024 // 假设每个操作1KB
    }
    
    // MARK: - 调试和监控
    
    /// 获取操作历史
    func getActionHistory() -> [ActionHistoryItem] {
        return undoStack.enumerated().map { index, action in
            ActionHistoryItem(
                index: index,
                title: action.title,
                timestamp: action.timestamp,
                type: String(describing: type(of: action))
            )
        }
    }
    
    /// 导出历史记录
    func exportHistory() -> String {
        let history = getActionHistory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(history)
            return String(data: data, encoding: .utf8) ?? "导出失败"
        } catch {
            return "导出错误：\(error.localizedDescription)"
        }
    }
}

// MARK: - 撤销操作协议

protocol UndoableAction {
    var title: String { get }
    var timestamp: Date { get }
    
    func execute()
    func undo()
}

// MARK: - 具体操作实现

/// 添加物品操作
class AddItemAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let item: LuggageItem
    private let container: ItemContainer
    
    init(item: LuggageItem, container: ItemContainer) {
        self.item = item
        self.container = container
        self.title = "添加物品：\(item.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        container.addItem(item)
    }
    
    func undo() {
        container.removeItem(item)
    }
}

/// 删除物品操作
class DeleteItemAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let item: LuggageItem
    private let container: ItemContainer
    
    init(item: LuggageItem, container: ItemContainer) {
        self.item = item
        self.container = container
        self.title = "删除物品：\(item.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        container.removeItem(item)
    }
    
    func undo() {
        container.addItem(item)
    }
}

/// 修改物品操作
class ModifyItemAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let original: LuggageItem
    private let modified: LuggageItem
    private let container: ItemContainer
    
    init(original: LuggageItem, modified: LuggageItem, container: ItemContainer) {
        self.original = original
        self.modified = modified
        self.container = container
        self.title = "修改物品：\(original.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        container.replaceItem(original, with: modified)
    }
    
    func undo() {
        container.replaceItem(modified, with: original)
    }
}

/// 移动物品操作
class MoveItemAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let item: LuggageItem
    private let source: ItemContainer
    private let destination: ItemContainer
    
    init(item: LuggageItem, source: ItemContainer, destination: ItemContainer) {
        self.item = item
        self.source = source
        self.destination = destination
        self.title = "移动物品：\(item.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        source.removeItem(item)
        destination.addItem(item)
    }
    
    func undo() {
        destination.removeItem(item)
        source.addItem(item)
    }
}

/// 添加行李箱操作
class AddLuggageAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let luggage: Luggage
    
    init(luggage: Luggage) {
        self.luggage = luggage
        self.title = "添加行李箱：\(luggage.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        // 这里需要调用实际的数据管理服务
        LuggageDataManager.shared.addLuggage(luggage)
    }
    
    func undo() {
        LuggageDataManager.shared.removeLuggage(luggage)
    }
}

/// 删除行李箱操作
class DeleteLuggageAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let luggage: Luggage
    
    init(luggage: Luggage) {
        self.luggage = luggage
        self.title = "删除行李箱：\(luggage.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        LuggageDataManager.shared.removeLuggage(luggage)
    }
    
    func undo() {
        LuggageDataManager.shared.addLuggage(luggage)
    }
}

/// 修改行李箱操作
class ModifyLuggageAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let original: Luggage
    private let modified: Luggage
    
    init(original: Luggage, modified: Luggage) {
        self.original = original
        self.modified = modified
        self.title = "修改行李箱：\(original.name)"
        self.timestamp = Date()
    }
    
    func execute() {
        LuggageDataManager.shared.replaceLuggage(original, with: modified)
    }
    
    func undo() {
        LuggageDataManager.shared.replaceLuggage(modified, with: original)
    }
}

/// 修改清单操作
class ModifyChecklistAction: UndoableAction {
    let title: String
    let timestamp: Date
    private let original: [TravelChecklistItem]
    private let modified: [TravelChecklistItem]
    
    init(original: [TravelChecklistItem], modified: [TravelChecklistItem]) {
        self.original = original
        self.modified = modified
        self.title = "修改清单"
        self.timestamp = Date()
    }
    
    func execute() {
        ChecklistManager.shared.updateChecklist(modified)
    }
    
    func undo() {
        ChecklistManager.shared.updateChecklist(original)
    }
}

/// 组操作（批量操作）
class GroupAction: UndoableAction {
    let title: String
    let timestamp: Date
    private var actions: [UndoableAction] = []
    
    init(title: String) {
        self.title = title
        self.timestamp = Date()
    }
    
    func addAction(_ action: UndoableAction) {
        actions.append(action)
    }
    
    func execute() {
        for action in actions {
            action.execute()
        }
    }
    
    func undo() {
        // 反向执行撤销
        for action in actions.reversed() {
            action.undo()
        }
    }
}

// MARK: - 数据容器协议

protocol ItemContainer {
    func addItem(_ item: LuggageItem)
    func removeItem(_ item: LuggageItem)
    func replaceItem(_ original: LuggageItem, with modified: LuggageItem)
}

// MARK: - 数据管理器占位符

class LuggageDataManager {
    static let shared = LuggageDataManager()
    
    func addLuggage(_ luggage: Luggage) {
        // 实际实现
    }
    
    func removeLuggage(_ luggage: Luggage) {
        // 实际实现
    }
    
    func replaceLuggage(_ original: Luggage, with modified: Luggage) {
        // 实际实现
    }
}

class ChecklistManager {
    static let shared = ChecklistManager()
    
    func updateChecklist(_ items: [TravelChecklistItem]) {
        // 实际实现
    }
}

// MARK: - 数据模型

struct UndoRedoStatistics {
    let undoStackSize: Int
    let redoStackSize: Int
    let actionTypeDistribution: [String: Int]
    let memoryUsage: Int
}

struct ActionHistoryItem: Codable, Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let timestamp: Date
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case index, title, timestamp, type
    }
}