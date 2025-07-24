import SwiftUI
import UIKit

/// AI 物品批量分类视图
/// 用于批量分类多个物品
struct AIItemBatchCategoryView: View {
    // MARK: - 属性
    
    /// 视图模型
    @StateObject private var viewModel = AIViewModel()
    
    /// 分类管理器
    private let categoryManager = AIItemCategoryManager.shared
    
    /// 错误提示
    @State private var errorAlert = false
    @State private var errorMessage = ""
    
    /// 物品列表
    let items: [LuggageItemProtocol]
    
    /// 分类结果
    @State private var categoryResults: [UUID: ItemCategory] = [:]
    
    /// 用户修改的分类
    @State private var userModifiedCategories: [UUID: ItemCategory] = [:]
    
    /// 选中的物品ID
    @State private var selectedItemId: UUID?
    
    /// 是否显示分类选择器
    @State private var showCategoryPicker = false
    
    /// 是否显示统计信息
    @State private var showStats = false
    
    /// 分类置信度
    @State private var confidenceScores: [UUID: Double] = [:]
    
    /// 分类完成回调
    var onCategoriesUpdated: (([UUID: ItemCategory]) -> Void)?
    
    // MARK: - 初始化
    
    init(items: [LuggageItemProtocol], onCategoriesUpdated: (([UUID: ItemCategory]) -> Void)? = nil) {
        self.items = items
        self.onCategoriesUpdated = onCategoriesUpdated
    }
    
    // MARK: - 视图
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("物品批量分类")
                    .font(.headline)
                
                Spacer()
                
                // 统计按钮
                Button(action: {
                    showStats.toggle()
                }) {
                    Label("统计", systemImage: "chart.pie")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 4)
            
            // 加载状态
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                    Text("正在批量分类物品...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if let error = viewModel.errorMessage {
                // 错误信息
                Text("分类失败: \(error)")
                    .foregroundColor(.red)
                    .padding()
                
                Button("重试") {
                    Task {
                        await categorizeItems()
                    }
                }
                .buttonStyle(.bordered)
            } else {
                // 分类结果列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items, id: \.id) { item in
                            itemRow(for: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedItemId = item.id
                                    showCategoryPicker = true
                                }
                        }
                    }
                }
                
                // 统计信息
                if showStats {
                    categoryStatsView
                        .padding(.vertical, 8)
                }
                
                // 操作按钮
                HStack {
                    Button("全部重新分类") {
                        Task {
                            await categorizeItems()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("应用分类") {
                        applyCategories()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            Task {
                await categorizeItems()
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            if let itemId = selectedItemId, let item = items.first(where: { $0.id == itemId }) {
                categoryPickerView(for: item)
            }
        }
        .alert("分类错误", isPresented: $errorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            // 清理资源
            viewModel.resetAllStates()
        }
    }
    
    // MARK: - 物品行视图
    
    private func itemRow(for item: LuggageItemProtocol) -> some View {
        HStack {
            // 物品名称
            Text(item.name)
                .fontWeight(.medium)
            
            Spacer()
            
            // 分类结果
            if let category = effectiveCategory(for: item.id) {
                HStack {
                    Text(category.icon)
                    Text(category.displayName)
                        .fontWeight(.medium)
                    
                    // 显示置信度指示器
                    if let confidence = confidenceScores[item.id], !isUserModified(item.id) {
                        confidenceIndicator(confidence)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(categoryColor(for: category).opacity(0.2))
                .cornerRadius(8)
                
                // 编辑按钮
                Button(action: {
                    selectedItemId = item.id
                    showCategoryPicker = true
                }) {
                    Image(systemName: "pencil.circle")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            } else {
                Text("未分类")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    /// 置信度指示器
    private func confidenceIndicator(_ confidence: Double) -> some View {
        ZStack {
            Circle()
                .fill(confidenceColor(confidence))
                .frame(width: 8, height: 8)
        }
        .padding(.leading, 4)
    }
    
    /// 获取置信度颜色
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .yellow
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// 检查是否是用户修改的
    private func isUserModified(_ itemId: UUID) -> Bool {
        return userModifiedCategories[itemId] != nil
    }
    
    // MARK: - 分类统计视图
    
    private var categoryStatsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类统计")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // 分类统计图表
            HStack(spacing: 0) {
                ForEach(categoryStats.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                    if count > 0 {
                        categoryBar(category: category, count: count, total: items.count)
                    }
                }
            }
            .frame(height: 24)
            .cornerRadius(6)
            
            // 图例
            FlowLayout(spacing: 8) {
                ForEach(categoryStats.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                    if count > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(categoryColor(for: category))
                                .frame(width: 8, height: 8)
                            
                            Text("\(category.displayName): \(count)")
                                .font(.caption)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    // MARK: - 分类选择器视图
    
    private func categoryPickerView(for item: LuggageItemProtocol) -> some View {
        NavigationView {
            List {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectCategory(category, for: item.id)
                        showCategoryPicker = false
                    }) {
                        HStack {
                            Text(category.icon)
                                .font(.title2)
                                .frame(width: 40)
                            
                            Text(category.displayName)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if category == effectiveCategory(for: item.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("为\(item.name)选择类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showCategoryPicker = false
                    }
                }
            })
        }
    }
    
    // MARK: - 分类统计条形图
    
    private func categoryBar(category: ItemCategory, count: Int, total: Int) -> some View {
        let ratio = Double(count) / Double(total)
        
        return GeometryReader { geometry in
            Rectangle()
                .fill(categoryColor(for: category))
                .frame(width: geometry.size.width * ratio)
        }
    }
    
    // MARK: - 方法
    
    /// 批量分类物品
    private func categorizeItems() async {
        // 使用分类管理器进行批量分类
        var results: [UUID: ItemCategory] = [:]
        var scores: [UUID: Double] = [:]
        
        // 显示加载状态
        viewModel.isLoading = true
        
        do {
            // 对每个物品进行分类
            for item in items {
                do {
                    let (category, confidence) = try await categoryManager.categorizeItem(item)
                    results[item.id] = category
                    scores[item.id] = confidence
                } catch {
                    print("分类物品 \(item.name) 失败: \(error)")
                    
                    // 回退到视图模型方法
                    await viewModel.categorizeItem(item)
                    if let category = viewModel.itemCategory {
                        results[item.id] = category
                        scores[item.id] = 0.7 // 默认置信度
                    } else {
                        // 设置默认分类
                        results[item.id] = .other
                        scores[item.id] = 0.5
                    }
                }
            }
            
            categoryResults = results
            confidenceScores = scores
            
            // 清除用户修改的分类
            userModifiedCategories = [:]
            
            viewModel.isLoading = false
        } catch {
            let errorDesc = error.localizedDescription
            viewModel.errorMessage = "批量分类失败: \(errorDesc)"
            errorMessage = "批量分类失败: \(errorDesc)"
            errorAlert = true
            viewModel.isLoading = false
        }
    }
    
    /// 选择类别
    private func selectCategory(_ category: ItemCategory, for itemId: UUID) {
        // 记录用户修改的分类
        userModifiedCategories[itemId] = category
        
        // 如果用户选择了与AI不同的类别，记录这个偏好
        if let originalCategory = categoryResults[itemId],
           let item = items.first(where: { $0.id == itemId }),
           category != originalCategory {
            // 使用分类管理器记录用户偏好
            categoryManager.learnUserCategoryPreference(
                item: item,
                userCategory: category,
                originalCategory: originalCategory
            )
        }
    }
    
    /// 应用分类
    private func applyCategories() {
        // 合并AI分类结果和用户修改的分类
        var finalCategories = categoryResults
        
        // 用户修改的分类覆盖AI分类结果
        for (itemId, category) in userModifiedCategories {
            finalCategories[itemId] = category
        }
        
        // 通知分类变更
        categoryManager.categoryChangesPublisher.send(finalCategories)
        
        // 调用回调
        onCategoriesUpdated?(finalCategories)
    }
    
    /// 获取有效的类别（用户修改的或AI分类的）
    private func effectiveCategory(for itemId: UUID) -> ItemCategory? {
        return userModifiedCategories[itemId] ?? categoryResults[itemId]
    }
    
    /// 获取类别颜色
    private func categoryColor(for category: ItemCategory) -> Color {
        switch category {
        case .clothing:
            return .blue
        case .electronics:
            return .gray
        case .toiletries:
            return .green
        case .documents:
            return .orange
        case .medicine:
            return .red
        case .accessories:
            return .purple
        case .shoes:
            return .brown
        case .books:
            return .indigo
        case .food:
            return .yellow
        case .sports:
            return .mint
        case .beauty:
            return .pink
        case .other:
            return .gray
        }
    }
    
    /// 计算分类统计
    private var categoryStats: [ItemCategory: Int] {
        var stats: [ItemCategory: Int] = [:]
        
        // 初始化所有类别为0
        for category in ItemCategory.allCases {
            stats[category] = 0
        }
        
        // 统计每个类别的数量
        for item in items {
            if let category = effectiveCategory(for: item.id) {
                stats[category, default: 0] += 1
            }
        }
        
        return stats
    }
}

// MARK: - 预览

struct AIItemBatchCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一些模拟的物品
        let mockItems = [
            MockLuggageItem(id: UUID(), name: "iPhone 13", weight: 200, volume: 100),
            MockLuggageItem(id: UUID(), name: "MacBook Pro", weight: 1600, volume: 2200),
            MockLuggageItem(id: UUID(), name: "T恤", weight: 150, volume: 500),
            MockLuggageItem(id: UUID(), name: "牙刷", weight: 20, volume: 20),
            MockLuggageItem(id: UUID(), name: "护照", weight: 50, volume: 10)
        ]
        
        return AIItemBatchCategoryView(items: mockItems)
            .padding()
            .previewLayout(.sizeThatFits)
    }
    
    // 模拟物品
    struct MockLuggageItem: LuggageItemProtocol {
        var id: UUID
        var name: String
        var weight: Double
        var volume: Double
    }
}