import SwiftUI

/// 物品总览页面
/// 展示所有物品，支持按行李筛选和搜索
struct ItemListView: View {
    @ObservedObject var viewModel: LuggageViewModel
    @State private var searchText = ""
    @State private var selectedFilter: ItemFilter = .all
    
    enum ItemFilter: String, CaseIterable {
        case all = "全部"
        case packed = "已装箱"
        case unpacked = "未装箱"
        case home = "家中"
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
        case .packed:
            items = items.filter { 
                guard let location = $0.location else { return false }
                return location != "未装箱" && location != "家中"
            }
        case .unpacked:
            items = items.filter { $0.location == "未装箱" }
        case .home:
            items = items.filter { $0.location == "家中" }
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredItems) { item in
                    ItemRowView(item: item, compact: false)
                }
            }
            .navigationTitle("物品管理")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("筛选") {
                        Picker("筛选", selection: $selectedFilter) {
                            ForEach(ItemFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    }
                }
            }
        }
    }
}