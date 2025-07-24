import SwiftUI
import Combine
import UIKit

/// 物品总览页面
/// 展示所有物品，支持按行李筛选和搜索
struct ItemListView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @StateObject private var aiViewModel = AIViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: ItemFilter = .all
    @State private var selectedCategory: ItemCategory?
    @State private var showingAddItem = false
    @State private var showingCategoryFilter = false
    @State private var showingBatchCategory = false
    @State private var itemCategories: [UUID: ItemCategory] = [:]
    @State private var showingCategoryStats = false
    @State private var categoryAccuracyStats: [String: Any] = [:]
    @State private var errorAlert = false
    @State private var errorMessage = ""
    
    // 分类管理器
    private let categoryManager = AIItemCategoryManager.shared
    
    enum ItemFilter: String, CaseIterable {
        case all = "全部"
        case inLuggage = "已装入行李"
        case standalone = "独立存放"
    }
    
    /// 获取过滤后的物品列表
    private var filteredItems: [LuggageItem] {
        var items = viewModel.allItems
        
        // 搜索过滤
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 类型过滤
        switch selectedFilter {
        case .all:
            break
        case .inLuggage:
            items = items.filter { item in
                let status = viewModel.getItemStatus(for: item)
                return status.isInLuggage
            }
        case .standalone:
            items = items.filter { item in
                let status = viewModel.getItemStatus(for: item)
                return !status.isInLuggage
            }
        }
        
        // 类别过滤
        if let category = selectedCategory {
            items = items.filter { item in
                itemCategories[item.id] == category
            }
        }
        
        return items
    }
    
    /// 筛选器分段控制器
    private var filterSegmentedControl: some View {
        VStack(spacing: 0) {
            Picker("筛选", selection: $selectedFilter) {
                ForEach(ItemFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 类别筛选器
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 全部类别按钮
                        Button(action: {
                            selectedCategory = nil
                        }) {
                            HStack {
                                Image(systemName: "tag")
                                Text("全部")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == nil ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        
                        // 类别按钮
                        ForEach(ItemCategory.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                HStack {
                                    Text(category.icon)
                                    Text(category.displayName)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // 类别统计
                if !itemCategories.isEmpty {
                    HStack {
                        Text("类别统计:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(getCategoryStats().prefix(3), id: \.category) { stat in
                            HStack(spacing: 2) {
                                Text(stat.category.icon)
                                    .font(.caption)
                                Text("\(stat.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(categoryColor(for: stat.category)).opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if getCategoryStats().count > 3 {
                            Button(action: {
                                showingCategoryStats = true
                            }) {
                                Text("更多...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: getEmptyStateIcon())
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(getEmptyStateTitle())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(getEmptyStateMessage())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if selectedFilter == .all && searchText.isEmpty {
                Button("添加第一个物品") {
                    showingAddItem = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    /// 获取空状态图标
    private func getEmptyStateIcon() -> String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        }
        
        switch selectedFilter {
        case .all:
            return "cube.box"
        case .inLuggage:
            return "suitcase"
        case .standalone:
            return "house"
        }
    }
    
    /// 获取空状态标题
    private func getEmptyStateTitle() -> String {
        if !searchText.isEmpty {
            return "未找到物品"
        }
        
        switch selectedFilter {
        case .all:
            return "暂无物品"
        case .inLuggage:
            return "暂无已装入行李的物品"
        case .standalone:
            return "暂无独立存放的物品"
        }
    }
    
    /// 获取空状态消息
    private func getEmptyStateMessage() -> String {
        if !searchText.isEmpty {
            return "没有找到包含 \"\(searchText)\" 的物品，请尝试其他关键词"
        }
        
        switch selectedFilter {
        case .all:
            return "开始添加您的物品，更好地管理您的行李"
        case .inLuggage:
            return "您还没有将任何物品装入行李中"
        case .standalone:
            return "您还没有添加任何独立存放的物品"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选器标签栏
                filterSegmentedControl
                
                // 物品列表或空状态
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            ItemRowView(item: item, compact: false)
                                .contextMenu {
                                    // AI 分类按钮
                                    Button(action: {
                                        Task {
                                            await categorizeItem(item)
                                        }
                                    }) {
                                        Label("AI 分类", systemImage: "tag")
                                    }
                                    
                                    // 设置类别菜单
                                    categorySelectionMenu(for: item)
                                    
                                    // 生成标签按钮
                                    Button(action: {
                                        Task {
                                            await generateTags(for: item)
                                        }
                                    }) {
                                        Label("生成标签", systemImage: "tag.circle")
                                    }
                                }
                                .listRowBackground(getRowBackgroundColor(for: item))
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("物品管理")
            .searchable(text: $searchText, prompt: "搜索物品名称...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // 物品计数
                        Text("\(filteredItems.count) 件物品")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 批量分类按钮
                        if !filteredItems.isEmpty {
                            categoryToolbarMenu
                        }
                        
                        // 添加物品按钮
                        addItemButton
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddStandaloneItemView()
            }
            .sheet(isPresented: $showingBatchCategory) {
                AIItemBatchCategoryView(items: filteredItems) { categories in
                    // 更新物品类别
                    for (itemId, category) in categories {
                        itemCategories[itemId] = category
                    }
                    saveItemCategories()
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingCategoryStats) {
                CategoryStatsView(
                    stats: getCategoryStats(),
                    accuracyStats: categoryAccuracyStats
                )
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                // 如果类别为空，尝试加载或初始化
                if itemCategories.isEmpty {
                    loadItemCategories()
                }
                
                // 获取分类准确性统计
                categoryAccuracyStats = categoryManager.getCategoryAccuracyStats()
                
                // 订阅分类变更 - 使用 onReceive 替代 sink
                // 不再需要手动管理 cancellables
            }
            .alert("错误", isPresented: $errorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onReceive(categoryManager.categoryChangesPublisher) { newCategories in
                // 更新类别
                for (itemId, category) in newCategories {
                    itemCategories[itemId] = category
                }
                saveItemCategories()
            }
            // 不再需要 onDisappear 清理订阅，因为我们使用 onReceive 自动管理
        }
    }
    
    /// 分类单个物品
    private func categorizeItem(_ item: LuggageItemProtocol) async {
        do {
            let (category, _) = try await categoryManager.categorizeItem(item)
            itemCategories[item.id] = category
            saveItemCategories()
        } catch {
            let errorDesc = error.localizedDescription
            print("分类失败: \(errorDesc)")
            errorMessage = "分类失败: \(errorDesc)"
            errorAlert = true
            
            // 回退到 ViewModel 方法
            await aiViewModel.categorizeItem(item)
            if let category = aiViewModel.itemCategory {
                itemCategories[item.id] = category
                saveItemCategories()
            } else {
                // 设置默认分类
                itemCategories[item.id] = .other
                saveItemCategories()
            }
        }
    }
    
    /// 批量分类物品
    private func batchCategorizeItems() async {
        let items = filteredItems
        if items.isEmpty { return }
        
        // 显示加载指示器
        // 这里可以添加一个加载状态
        
        let newCategories = await categoryManager.batchCategorizeItems(items)
        
        // 更新类别
        for (itemId, category) in newCategories {
            itemCategories[itemId] = category
        }
        
        saveItemCategories()
    }
    
    /// 手动设置物品类别
    private func setCategory(_ category: ItemCategory, for item: LuggageItemProtocol) {
        // 获取原始类别
        let originalCategory = itemCategories[item.id]
        
        // 更新类别
        itemCategories[item.id] = category
        saveItemCategories()
        
        // 如果有原始类别，记录用户偏好
        if let originalCategory = originalCategory, originalCategory != category {
            categoryManager.learnUserCategoryPreference(
                item: item,
                userCategory: category,
                originalCategory: originalCategory
            )
        }
    }
    
    /// 生成物品标签
    private func generateTags(for item: LuggageItemProtocol) async {
        do {
            let tags = try await categoryManager.generateItemTags(for: item)
            print("生成标签: \(tags)")
            
            // 这里可以添加一个显示标签的弹窗或者导航到标签编辑页面
        } catch {
            let errorDesc = error.localizedDescription
            print("生成标签失败: \(errorDesc)")
            errorMessage = "生成标签失败: \(errorDesc)"
            errorAlert = true
        }
    }
    
    /// 获取类别统计
    private func getCategoryStats() -> [CategoryStat] {
        var stats: [ItemCategory: Int] = [:]
        
        // 统计每个类别的物品数量
        for (_, category) in itemCategories {
            stats[category, default: 0] += 1
        }
        
        // 转换为数组并排序
        return stats.map { CategoryStat(category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    /// 类别统计数据
    struct CategoryStat: Identifiable {
        let id = UUID()
        let category: ItemCategory
        let count: Int
    }
    
    /// 获取类别颜色
    private func categoryColor(for category: ItemCategory) -> UIColor {
        switch category {
        case .clothing:
            return UIColor.systemBlue.withAlphaComponent(0.7)
        case .electronics:
            return UIColor.systemGray.withAlphaComponent(0.7)
        case .toiletries:
            return UIColor.systemGreen.withAlphaComponent(0.7)
        case .documents:
            return UIColor.systemOrange.withAlphaComponent(0.7)
        case .medicine:
            return UIColor.systemRed.withAlphaComponent(0.7)
        case .accessories:
            return UIColor.systemPurple.withAlphaComponent(0.7)
        case .shoes:
            return UIColor.systemBrown.withAlphaComponent(0.7)
        case .books:
            return UIColor.systemIndigo.withAlphaComponent(0.7)
        case .food:
            return UIColor.systemYellow.withAlphaComponent(0.7)
        case .sports:
            return UIColor.systemMint.withAlphaComponent(0.7)
        case .beauty:
            return UIColor.systemPink.withAlphaComponent(0.7)
        case .other:
            return UIColor.systemGray.withAlphaComponent(0.7)
        }
    }
    
    /// 保存物品类别到 UserDefaults
    private func saveItemCategories() {
        let encodableDict = Dictionary(uniqueKeysWithValues: itemCategories.map { (key, value) in
            (key.uuidString, value.rawValue)
        })
        
        if let data = try? JSONEncoder().encode(encodableDict) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.itemCategories)
        }
    }
    
    /// 从 UserDefaults 加载物品类别
    private func loadItemCategories() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.itemCategories),
           let encodableDict = try? JSONDecoder().decode([String: String].self, from: data) {
            var loadedCategories: [UUID: ItemCategory] = [:]
            for (key, value) in encodableDict {
                if let uuid = UUID(uuidString: key), let category = ItemCategory(rawValue: value) {
                    loadedCategories[uuid] = category
                }
            }
            itemCategories = loadedCategories
        }
    }
    
    /// 获取行背景颜色
    private func getRowBackgroundColor(for item: LuggageItemProtocol) -> Color {
        if let category = itemCategories[item.id] {
            return Color(categoryColor(for: category)).opacity(0.1)
        } else {
            return Color(.systemBackground)
        }
    }
    
    /// 类别选择菜单
    private func categorySelectionMenu(for item: LuggageItemProtocol) -> some View {
        Menu("设置类别") {
            ForEach(ItemCategory.allCases, id: \.self) { category in
                Button(action: {
                    setCategory(category, for: item)
                }) {
                    Label(category.displayName, systemImage: "tag.fill")
                }
            }
        }
    }
    
    /// 类别工具栏菜单
    private var categoryToolbarMenu: some View {
        Menu {
            Button(action: {
                showingBatchCategory = true
            }) {
                Label("批量分类", systemImage: "tag.circle")
            }
            
            Button(action: {
                Task {
                    await batchCategorizeItems()
                }
            }) {
                Label("AI 自动分类", systemImage: "wand.and.stars")
            }
            
            Button(action: {
                showingCategoryStats = true
            }) {
                Label("分类统计", systemImage: "chart.pie")
            }
        } label: {
            Image(systemName: "tag.circle")
                .foregroundColor(.blue)
        }
    }
    
    /// 添加物品按钮
    private var addItemButton: some View {
        Button {
            showingAddItem = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.blue)
        }
    }
}