import SwiftUI
import UIKit

/// AI 物品标签视图
/// 用于显示和管理物品标签
struct AIItemTagsView: View {
    // MARK: - 属性
    
    /// 视图模型
    @StateObject private var viewModel = AIViewModel()
    
    /// 物品
    let item: LuggageItemProtocol
    
    /// 标签列表
    @State private var tags: [String] = []
    
    /// 新标签输入
    @State private var newTag = ""
    
    /// 是否显示添加标签输入框
    @State private var showAddTag = false
    
    /// 是否正在编辑
    @State private var isEditing = false
    
    /// 标签更新回调
    var onTagsUpdated: (([String]) -> Void)?
    
    // MARK: - 初始化
    
    init(item: LuggageItemProtocol, initialTags: [String] = [], onTagsUpdated: (([String]) -> Void)? = nil) {
        self.item = item
        self.onTagsUpdated = onTagsUpdated
        _tags = State(initialValue: initialTags)
    }
    
    // MARK: - 视图
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("物品标签")
                    .font(.headline)
                
                Spacer()
                
                // 编辑/完成按钮
                Button(action: {
                    withAnimation {
                        isEditing.toggle()
                        if !isEditing {
                            // 退出编辑模式时调用回调
                            onTagsUpdated?(tags)
                        }
                    }
                }) {
                    Text(isEditing ? "完成" : "编辑")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                // 生成标签按钮
                if !isEditing {
                    Button(action: {
                        Task {
                            await generateTags()
                        }
                    }) {
                        Label("生成", systemImage: "wand.and.stars")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 加载状态
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("生成标签中...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                // 标签流布局
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        tagView(tag)
                    }
                    
                    // 添加标签按钮
                    if isEditing {
                        addTagButton
                    }
                }
                
                // 如果没有标签
                if tags.isEmpty && !viewModel.isLoading && !showAddTag {
                    Text("暂无标签")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                
                // 添加标签输入框
                if showAddTag {
                    addTagInputView
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            if tags.isEmpty {
                Task {
                    await generateTags()
                }
            }
        }
    }
    
    // MARK: - 标签视图
    
    private func tagView(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .padding(.leading, 10)
                .padding(.trailing, isEditing ? 4 : 10)
                .padding(.vertical, 5)
            
            // 删除按钮
            if isEditing {
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
    
    // MARK: - 方法
    
    /// 生成标签
    private func generateTags() async {
        let generatedTags = await viewModel.generateItemTags(for: item)
        
        // 合并生成的标签和现有标签，去重
        let combinedTags = Set(tags + generatedTags)
        tags = Array(combinedTags).sorted()
        
        // 调用回调
        onTagsUpdated?(tags)
    }
    
    /// 添加新标签
    private func addNewTag() {
        guard !newTag.isEmpty else { return }
        
        withAnimation {
            // 检查标签是否已存在
            if !tags.contains(newTag) {
                tags.append(newTag)
                tags.sort()
                
                // 调用回调
                onTagsUpdated?(tags)
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
            
            // 调用回调
            onTagsUpdated?(tags)
        }
    }
}

// MARK: - 预览

struct AIItemTagsView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个模拟的物品
        let mockItem = MockLuggageItem(
            id: UUID(),
            name: "iPhone 13",
            weight: 200,
            volume: 100
        )
        
        return AIItemTagsView(
            item: mockItem,
            initialTags: ["电子设备", "苹果产品", "通讯工具"]
        )
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