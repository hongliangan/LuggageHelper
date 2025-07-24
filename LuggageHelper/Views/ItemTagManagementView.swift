import SwiftUI
import UIKit

/// 物品标签管理视图
/// 用于管理物品的标签和分类
struct ItemTagManagementView: View {
    // MARK: - 属性
    
    /// 物品
    let item: LuggageItemProtocol
    
    /// 分类管理器
    private let categoryManager = AIItemCategoryManager.shared
    
    /// 错误提示
    @State private var errorAlert = false
    @State private var errorAlertMessage = ""
    
    /// 标签列表
    @State private var tags: [String] = []
    
    /// 新标签输入
    @State private var newTag = ""
    
    /// 是否显示添加标签输入框
    @State private var showAddTag = false
    
    /// 是否正在加载
    @State private var isLoading = false
    
    /// 错误消息
    @State private var errorMessage: String?
    
    /// 当前分类
    @State private var currentCategory: ItemCategory?
    
    /// 是否显示分类选择器
    @State private var showCategoryPicker = false
    
    /// 标签更新回调
    var onTagsUpdated: (([String]) -> Void)?
    
    /// 分类更新回调
    var onCategoryUpdated: ((ItemCategory) -> Void)?
    
    // MARK: - 初始化
    
    init(item: LuggageItemProtocol, initialTags: [String] = [], initialCategory: ItemCategory? = nil, onTagsUpdated: (([String]) -> Void)? = nil, onCategoryUpdated: ((ItemCategory) -> Void)? = nil) {
        self.item = item
        self.onTagsUpdated = onTagsUpdated
        self.onCategoryUpdated = onCategoryUpdated
        _tags = State(initialValue: initialTags)
        _currentCategory = State(initialValue: initialCategory)
    }
    
    // MARK: - 视图
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类部分
                categorySection
                    .padding()
                    .background(Color(.secondarySystemBackground))
                
                // 标签部分
                tagSection
                    .padding()
            }
            .navigationTitle("标签管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 保存更改并关闭
                        if let category = currentCategory {
                            onCategoryUpdated?(category)
                        }
                        onTagsUpdated?(tags)
                    }
                }
            })
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerView
            }
            .alert("错误", isPresented: $errorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorAlertMessage)
            }
            .onAppear {
                if tags.isEmpty {
                    loadTags()
                }
                
                if currentCategory == nil {
                    categorizeItem()
                }
            }
        }
    }
    
    // MARK: - 分类部分
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("物品分类")
                .font(.headline)
            
            HStack {
                if let category = currentCategory {
                    HStack {
                        Text(category.icon)
                            .font(.title2)
                        
                        Text(category.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(categoryColor(for: category).opacity(0.2))
                    .cornerRadius(8)
                } else {
                    Text("未分类")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showCategoryPicker = true
                }) {
                    Text("更改")
                        .font(.body)
                }
                .buttonStyle(.bordered)
            }
            
            Text("选择合适的分类可以帮助更好地组织和查找物品")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 标签部分
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("物品标签")
                    .font(.headline)
                
                Spacer()
                
                // 生成标签按钮
                Button(action: {
                    loadTags()
                }) {
                    Label("生成", systemImage: "wand.and.stars")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                    Text("生成标签中...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
            } else {
                // 标签流布局
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        tagView(tag)
                    }
                    
                    // 添加标签按钮
                    addTagButton
                }
                
                // 如果没有标签
                if tags.isEmpty && !isLoading && !showAddTag {
                    Text("暂无标签")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                
                // 添加标签输入框
                if showAddTag {
                    addTagInputView
                }
                
                Text("标签可以帮助您更快地找到物品，建议添加描述物品特征的关键词")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - 标签视图
    
    private func tagView(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 5)
            
            // 删除按钮
            Button(action: {
                withAnimation {
                    removeTag(tag)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .padding(.trailing, 6)
            }
            .buttonStyle(.plain)
        }
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - 添加标签按钮
    
    private var addTagButton: some View {
        Button(action: {
            withAnimation {
                showAddTag = true
            }
        }) {
            HStack {
                Image(systemName: "plus")
                Text("添加标签")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 添加标签输入视图
    
    private var addTagInputView: some View {
        HStack {
            TextField("新标签", text: $newTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
                .onSubmit {
                    addNewTag()
                }
            
            Button("添加") {
                addNewTag()
            }
            .disabled(newTag.isEmpty)
            
            Button("取消") {
                withAnimation {
                    showAddTag = false
                    newTag = ""
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - 分类选择器视图
    
    private var categoryPickerView: some View {
        NavigationView {
            List {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectCategory(category)
                        showCategoryPicker = false
                    }) {
                        HStack {
                            Text(category.icon)
                                .font(.title2)
                                .frame(width: 40)
                            
                            Text(category.displayName)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if category == currentCategory {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("选择物品类别")
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
    
    // MARK: - 方法
    
    /// 加载标签
    private func loadTags() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let generatedTags = try await categoryManager.generateItemTags(for: item)
                
                // 合并生成的标签和现有标签，去重
                let combinedTags = Set(tags + generatedTags)
                tags = Array(combinedTags).sorted()
                
                isLoading = false
            } catch {
                let errorDesc = error.localizedDescription
                errorMessage = "生成标签失败: \(errorDesc)"
                errorAlertMessage = "生成标签失败: \(errorDesc)"
                errorAlert = true
                isLoading = false
            }
        }
    }
    
    /// 分类物品
    private func categorizeItem() {
        isLoading = true
        
        Task {
            do {
                let (category, _) = try await categoryManager.categorizeItem(item)
                currentCategory = category
                isLoading = false
            } catch {
                let errorDesc = error.localizedDescription
                print("分类失败: \(errorDesc)")
                errorAlertMessage = "分类失败: \(errorDesc)"
                errorAlert = true
                isLoading = false
                // 设置默认分类
                currentCategory = .other
            }
        }
    }
    
    /// 添加新标签
    private func addNewTag() {
        guard !newTag.isEmpty else { return }
        
        withAnimation {
            // 检查标签是否已存在
            if !tags.contains(newTag) {
                tags.append(newTag)
                tags.sort()
            }
            
            // 重置状态
            newTag = ""
            showAddTag = false
        }
    }
    
    /// 移除标签
    private func removeTag(_ tag: String) {
        withAnimation {
            tags.removeAll { $0 == tag }
        }
    }
    
    /// 选择类别
    private func selectCategory(_ category: ItemCategory) {
        // 如果用户选择了与当前不同的类别，记录这个偏好
        if let originalCategory = currentCategory, category != originalCategory {
            categoryManager.learnUserCategoryPreference(
                item: item,
                userCategory: category,
                originalCategory: originalCategory
            )
        }
        
        currentCategory = category
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
}

// MARK: - 预览

struct ItemTagManagementView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个模拟的物品
        let mockItem = MockLuggageItem(
            id: UUID(),
            name: "iPhone 13",
            weight: 200,
            volume: 100
        )
        
        return ItemTagManagementView(
            item: mockItem,
            initialTags: ["电子设备", "苹果产品", "通讯工具"],
            initialCategory: .electronics
        )
    }
    
    // 模拟物品
    struct MockLuggageItem: LuggageItemProtocol {
        var id: UUID
        var name: String
        var weight: Double
        var volume: Double
    }
}