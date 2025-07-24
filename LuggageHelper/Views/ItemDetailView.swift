import SwiftUI
import UIKit

/// 物品详情视图
/// 显示物品的详细信息，包括分类和标签
struct ItemDetailView: View {
    // MARK: - 属性
    
    /// 环境对象
    @EnvironmentObject var viewModel: LuggageViewModel
    
    /// 分类管理器
    private let categoryManager = AIItemCategoryManager.shared
    
    /// 物品
    let item: LuggageItem
    
    /// 物品标签
    @State private var itemTags: [String] = []
    
    /// 物品分类
    @State private var itemCategory: ItemCategory?
    
    /// 是否显示分类视图
    @State private var showCategoryView = true
    
    /// 是否显示标签视图
    @State private var showTagsView = true
    
    /// 是否显示标签管理视图
    @State private var showTagManagement = false
    
    /// 是否显示相关物品
    @State private var showRelatedItems = true
    
    // MARK: - 视图
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 物品基本信息
                itemInfoSection
                
                // 分类信息
                if showCategoryView {
                    AIItemCategoryView(item: item)
                }
                
                // 标签信息
                if showTagsView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("物品标签")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showTagManagement = true
                            }) {
                                Label("管理", systemImage: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // 标签流布局
                        FlowLayout(spacing: 8) {
                            ForEach(itemTags, id: \.self) { tag in
                                Text(tag)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // 如果没有标签
                        if itemTags.isEmpty {
                            Text("暂无标签")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // 物品状态信息
                itemStatusSection
                
                // 相关物品建议
                relatedItemsSection
            }
            .padding()
        }
        .navigationTitle(item.name)
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle("显示分类", isOn: $showCategoryView)
                    Toggle("显示标签", isOn: $showTagsView)
                    Toggle("显示相关物品", isOn: $showRelatedItems)
                    
                    Divider()
                    
                    Button(action: {
                        showTagManagement = true
                    }) {
                        Label("管理标签和分类", systemImage: "tag")
                    }
                    
                    Button(action: {
                        // 编辑物品
                    }) {
                        Label("编辑物品", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        // 删除物品
                    }) {
                        Label("删除物品", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        })
        .onAppear {
            // 加载物品标签和分类
            loadItemTags()
            loadItemCategory()
        }
        .sheet(isPresented: $showTagManagement) {
            ItemTagManagementView(
                item: item,
                initialTags: itemTags,
                initialCategory: itemCategory,
                onTagsUpdated: { tags in
                    itemTags = tags
                    saveItemTags()
                },
                onCategoryUpdated: { category in
                    itemCategory = category
                    saveItemCategory()
                }
            )
        }
    }
    
    // MARK: - 物品基本信息部分
    
    private var itemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 物品名称和图标
            HStack {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 物品图标（可以根据类别显示不同图标）
                Image(systemName: "cube.box")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            
            // 物品基本属性
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("重量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f kg", item.weight / 1000))
                        .font(.headline)
                }
                
                VStack(alignment: .leading) {
                    Text("体积")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f L", item.volume / 1000))
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 物品状态部分
    
    private var itemStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("物品状态")
                .font(.headline)
            
            let status = viewModel.getItemStatus(for: item)
            
            if case .inLuggage(let luggage, _) = status {
                HStack {
                    Image(systemName: "suitcase")
                    Text("已装入行李: \(luggage.name)")
                }
                .foregroundColor(.green)
            } else if case .standalone = status {
                HStack {
                    Image(systemName: "house")
                    Text("独立存放")
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 相关物品部分
    
    private var relatedItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相关物品")
                .font(.headline)
            
            if showRelatedItems {
                if let category = itemCategory {
                    // 查找同类别的物品
                    let relatedItems = viewModel.allItems.filter { 
                        $0.id != item.id && 
                        getItemCategory(for: $0.id) == category 
                    }
                    
                    if relatedItems.isEmpty {
                        Text("暂无相关物品")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(relatedItems.prefix(5), id: \.id) { relatedItem in
                                    relatedItemView(for: relatedItem)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } else {
                    Text("正在加载相关物品...")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                Text("相关物品显示已关闭")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    /// 相关物品视图
    private func relatedItemView(for relatedItem: LuggageItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(relatedItem.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text("\(String(format: "%.1f", relatedItem.weight / 1000)) kg")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 120)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    /// 获取物品分类
    private func getItemCategory(for itemId: UUID) -> ItemCategory? {
        // 从 UserDefaults 加载分类
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.itemCategories),
           let encodableDict = try? JSONDecoder().decode([String: String].self, from: data),
           let categoryString = encodableDict[itemId.uuidString],
           let category = ItemCategory(rawValue: categoryString) {
            return category
        }
        return nil
    }
    
    // MARK: - 方法
    
    /// 加载物品标签
    private func loadItemTags() {
        // 从 UserDefaults 加载标签
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.itemTags(for: item.id)),
           let tags = try? JSONDecoder().decode([String].self, from: data) {
            itemTags = tags
        } else {
            // 如果没有保存的标签，生成一些默认标签
            Task {
                do {
                    itemTags = try await categoryManager.generateItemTags(for: item)
                    saveItemTags()
                } catch {
                    print("生成标签失败: \(error)")
                    
                    // 回退到搜索服务
                    let searchService = ItemSearchService()
                    itemTags = await searchService.generateItemTags(for: item)
                }
            }
        }
    }
    
    /// 保存物品标签
    private func saveItemTags() {
        if let data = try? JSONEncoder().encode(itemTags) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.itemTags(for: item.id))
        }
    }
    
    /// 加载物品分类
    private func loadItemCategory() {
        // 从 UserDefaults 加载分类
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.itemCategories),
           let encodableDict = try? JSONDecoder().decode([String: String].self, from: data) {
            if let categoryString = encodableDict[item.id.uuidString],
               let category = ItemCategory(rawValue: categoryString) {
                itemCategory = category
                return
            }
        }
        
        // 如果没有保存的分类，使用 AI 分类
        Task {
            do {
                let (category, _) = try await categoryManager.categorizeItem(item)
                itemCategory = category
                saveItemCategory()
            } catch {
                print("分类失败: \(error)")
                // 设置默认分类
                itemCategory = .other
                saveItemCategory()
            }
        }
    }
    
    /// 保存物品分类
    private func saveItemCategory() {
        guard let category = itemCategory else { return }
        
        // 从 UserDefaults 加载现有分类
        var encodableDict: [String: String] = [:]
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.itemCategories),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            encodableDict = dict
        }
        
        // 更新分类
        encodableDict[item.id.uuidString] = category.rawValue
        
        // 保存回 UserDefaults
        if let data = try? JSONEncoder().encode(encodableDict) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.itemCategories)
        }
    }
}

// MARK: - 预览

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个模拟的物品
        let mockItem = LuggageItem(
            id: UUID(),
            name: "iPhone 13",
            volume: 100,
            weight: 200
        )
        
        NavigationView {
            ItemDetailView(item: mockItem)
                .environmentObject(LuggageViewModel())
        }
    }
}