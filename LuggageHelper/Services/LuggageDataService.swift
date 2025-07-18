import Foundation

/// 本地数据持久化服务
/// 负责行李、物品、出行清单的存储和读取
class LuggageDataService {
    
    // MARK: - 文件路径
    
    private var luggagesFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("luggages.json")
    }
    
    private var checklistsFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("checklists.json")
    }
    
    // MARK: - 行李数据
    
    /// 保存行李数据到本地
    func saveLuggages(_ luggages: [Luggage]) {
        do {
            let data = try JSONEncoder().encode(luggages)
            try data.write(to: luggagesFileURL)
        } catch {
            print("保存行李数据失败: \(error)")
        }
    }
    
    /// 从本地加载行李数据
    func loadLuggages() -> [Luggage] {
        do {
            let data = try Data(contentsOf: luggagesFileURL)
            return try JSONDecoder().decode([Luggage].self, from: data)
        } catch {
            print("加载行李数据失败: \(error)")
            return []
        }
    }
    
    // MARK: - 出行清单数据
    
    /// 保存出行清单数据到本地
    func saveChecklists(_ checklists: [TravelChecklist]) {
        do {
            let data = try JSONEncoder().encode(checklists)
            try data.write(to: checklistsFileURL)
        } catch {
            print("保存清单数据失败: \(error)")
        }
    }
    
    /// 从本地加载出行清单数据
    func loadChecklists() -> [TravelChecklist] {
        do {
            let data = try Data(contentsOf: checklistsFileURL)
            return try JSONDecoder().decode([TravelChecklist].self, from: data)
        } catch {
            print("加载清单数据失败: \(error)")
            return []
        }
    }
}
