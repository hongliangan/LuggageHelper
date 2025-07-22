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
    
    /// 筛选器分段控制器
    private var filterSegmentedControl: some View {
        Picker("筛选", selection: $selectedFilter) {
            ForEach(ItemFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                        Text("\(filteredItems.count) 件物品")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            showingAddItem = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
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