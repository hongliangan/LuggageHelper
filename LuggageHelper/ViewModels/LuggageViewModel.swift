import SwiftUI

/// 行李数据管理视图模型
/// 统一管理行李、物品、出行清单的数据和状态
class LuggageViewModel: ObservableObject {
    @Published var luggages: [Luggage] = []
    @Published var checklists: [TravelChecklist] = []
    @Published var airlines: [Airline] = []
    @Published var standaloneItems: [LuggageItem] = [] // 独立物品列表
    
    private let dataService = LuggageDataService()
    
    init() {
        loadData()
        loadPresetAirlines()
    }
    
    // MARK: - 行李管理
    
    /// 添加新行李
    func addLuggage(_ luggage: Luggage) {
        luggages.append(luggage)
        saveData()
    }
    
    /// 删除行李
    func removeLuggage(_ luggage: Luggage) {
        luggages.removeAll { $0.id == luggage.id }
        saveData()
    }
    
    /// 更新行李信息
    func updateLuggage(_ luggage: Luggage) {
        if let index = luggages.firstIndex(where: { $0.id == luggage.id }) {
            luggages[index] = luggage
            saveData()
        }
    }
    
    /// 根据ID获取行李
    func luggage(by id: UUID) -> Luggage? {
        return luggages.first { $0.id == id }
    }
    
    // MARK: - 物品管理
    
    /// 获取所有物品（包括独立物品和行李中的物品）
    var allItems: [LuggageItem] {
        let luggageItems = luggages.flatMap { $0.items }
        return standaloneItems + luggageItems
    }
    
    /// 添加独立物品
    func addStandaloneItem(_ item: LuggageItem) {
        standaloneItems.append(item)
        saveData()
    }
    
    /// 删除独立物品
    func removeStandaloneItem(_ item: LuggageItem) {
        standaloneItems.removeAll { $0.id == item.id }
        saveData()
    }
    
    /// 获取物品状态
    func getItemStatus(for item: LuggageItem) -> ItemStatus {
        // 检查物品是否在某个行李中
        for luggage in luggages {
            if luggage.items.contains(where: { $0.id == item.id }) {
                return .inLuggage(luggage: luggage, userLocation: item.location)
            }
        }
        // 如果不在行李中，则为独立物品
        return .standalone(location: item.location)
    }
    
    /// 将独立物品移动到行李中
    func moveItemToLuggage(_ item: LuggageItem, to luggageId: UUID) {
        // 从独立物品列表中移除
        removeStandaloneItem(item)
        // 添加到指定行李中
        addItem(item, to: luggageId)
    }
    
    /// 将物品从行李中移出，变为独立物品
    func moveItemFromLuggage(_ item: LuggageItem, from luggageId: UUID) {
        // 从行李中移除
        removeItem(item.id, from: luggageId)
        // 添加到独立物品列表
        addStandaloneItem(item)
    }
    
    // 在 LuggageViewModel 类中添加以下方法
    
    /// 添加物品到指定行李
    func addItem(_ item: LuggageItem, to luggageId: UUID) {
        if let index = luggages.firstIndex(where: { $0.id == luggageId }) {
            luggages[index].items.append(item)
            saveData()
        }
    }
    
    /// 更新物品信息
    func updateItem(_ item: LuggageItem, in luggageId: UUID) {
        if let luggageIndex = luggages.firstIndex(where: { $0.id == luggageId }),
           let itemIndex = luggages[luggageIndex].items.firstIndex(where: { $0.id == item.id }) {
            luggages[luggageIndex].items[itemIndex] = item
            saveData()
        }
    }
    
    /// 删除物品
    func removeItem(_ itemId: UUID, from luggageId: UUID) {
        if let luggageIndex = luggages.firstIndex(where: { $0.id == luggageId }) {
            luggages[luggageIndex].items.removeAll { $0.id == itemId }
            saveData()
        }
    }
    
    // MARK: - 出行清单管理
    
    /// 添加新清单
    func addChecklist(_ checklist: TravelChecklist) {
        checklists.append(checklist)
        saveData()
    }
    
    /// 删除清单
    func removeChecklist(_ checklist: TravelChecklist) {
        checklists.removeAll { $0.id == checklist.id }
        saveData()
    }
    
    /// 更新清单
    func updateChecklist(_ checklist: TravelChecklist) {
        if let index = checklists.firstIndex(where: { $0.id == checklist.id }) {
            checklists[index] = checklist
            saveData()
        }
    }
    
    /// 切换清单项目完成状态
    func toggleChecklistItem(_ itemId: UUID, in checklistId: UUID) {
        if let checklistIndex = checklists.firstIndex(where: { $0.id == checklistId }),
           let itemIndex = checklists[checklistIndex].items.firstIndex(where: { $0.id == itemId }) {
            checklists[checklistIndex].items[itemIndex].checked.toggle()
            saveData()
        }
    }
    
    // MARK: - 数据持久化
    
    // MARK: - 航空公司管理
    
    /// 加载预设航空公司数据
    private func loadPresetAirlines() {
        airlines = Airline.presetAirlines
    }
    
    /// 根据ID获取航空公司
    func airline(by id: UUID) -> Airline? {
        return airlines.first { $0.id == id }
    }
    
    /// 获取行李的超重警告信息
    func getOverweightWarning(for luggage: Luggage) -> String? {
        guard let airlineId = luggage.selectedAirlineId,
              let airline = airline(by: airlineId),
              luggage.isOverweight(airline: airline) else {
            return nil
        }
        
        let weightLimit = luggage.getWeightLimit(airline: airline) ?? 0
        let overweight = luggage.totalWeight - weightLimit
        return "超重 \(String(format: "%.1f", overweight))kg，限重 \(String(format: "%.1f", weightLimit))kg"
    }
    
    private func loadData() {
        luggages = dataService.loadLuggages()
        checklists = dataService.loadChecklists()
        standaloneItems = dataService.loadStandaloneItems()
    }
    
    private func saveData() {
        dataService.saveLuggages(luggages)
        dataService.saveChecklists(checklists)
        dataService.saveStandaloneItems(standaloneItems)
    }
}
