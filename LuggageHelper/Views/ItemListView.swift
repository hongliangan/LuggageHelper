import SwiftUI

/// 物品总览页面
/// 展示所有物品，支持按行李筛选和搜索
struct ItemListView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @State private var searchText = ""
    @State private var selectedFilter: ItemFilter = .all
    @State private var showingAddItem = false
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
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
            .sheet(isPresented: $showingAddItem) {
                AddStandaloneItemView()
            }
        }
    }
}