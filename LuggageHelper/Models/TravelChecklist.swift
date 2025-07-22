import Foundation

/// 出行清单模型
/// 用于管理出行准备事项的清单
struct TravelChecklist: Identifiable, Codable, Equatable {
    let id = UUID()
    var title: String
    var items: [TravelChecklistItem]
    var createdAt: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case title, items, createdAt
    }
    
    /// 已完成项目数量
    var completedCount: Int {
        items.filter { $0.checked }.count
    }
    
    /// 完成进度 (0.0 - 1.0)
    var progress: Double {
        guard !items.isEmpty else { return 0.0 }
        return Double(completedCount) / Double(items.count)
    }
    
    /// 是否所有项目都已完成
    var isAllChecked: Bool {
        guard !items.isEmpty else { return true }
        return items.allSatisfy { $0.checked }
    }
}

/// 清单项目模型
struct TravelChecklistItem: Identifiable, Codable, Equatable {
    let id = UUID()
    var name: String
    var checked: Bool = false
    var note: String?
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case name, checked, note, createdAt
    }
}