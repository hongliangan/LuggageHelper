import Foundation

/// 出行清单项数据模型
struct TravelChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var checked: Bool
    var note: String?
    
    init(id: UUID = UUID(), name: String, checked: Bool = false, note: String? = nil) {
        self.id = id
        self.name = name
        self.checked = checked
        self.note = note
    }
}

/// 出行清单数据模型
struct TravelChecklist: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var items: [TravelChecklistItem]
    var createdAt: Date
    var note: String?
    
    /// 获取未勾选项
    var uncheckedItems: [TravelChecklistItem] {
        items.filter { !$0.checked }
    }
    
    /// 判断清单是否全部勾选
    var isAllChecked: Bool {
        items.allSatisfy { $0.checked }
    }
    /// 已完成项目数量
    var completedCount: Int {
        items.filter { $0.checked }.count
    }
    
    /// 已完成项目占比（进度）
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count)
    }
    
    init(id: UUID = UUID(), title: String, items: [TravelChecklistItem] = [], createdAt: Date = Date(), note: String? = nil) {
        self.id = id
        self.title = title
        self.items = items
        self.createdAt = createdAt
        self.note = note
    }
}
