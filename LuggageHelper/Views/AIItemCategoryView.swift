import SwiftUI
import UIKit

/// AI 物品分类视图
/// 显示物品的分类结果和标签
struct AIItemCategoryView: View {
    // MARK: - 属性
    
    /// 视图模型
    @StateObject private var viewModel = AIViewModel()
    
    /// 分类管理器
    private let categoryManager = AIItemCategoryManager.shared
    
    /// 错误提示
    @State private var errorAlert = false
    @State private var errorMessage = ""
    
    /// 物品
    let item: LuggageItemProtocol
    
    /// 是否显示标签
    @State private var showTags = true
    
    /// 标签列表
    @State private var tags: [String] = []
    
    /// 当前分类
    @State private var currentCategory: ItemCategory?
    
    /// 分类置信度
    @State private var confidence: Double = 0.0
    
    /// 用户选择的分类
    @State private var userSelectedCategory: ItemCategory?
    
    /// 是否显示分类选择器
    @State private var showCategoryPicker = false
    
    /// 是否显示反馈表单
    @State private var showFeedbackForm = false
    
    /// 反馈内容
    @State private var feedbackText = ""
    
    /// 分类准确性选择
    @State private var accuracySelection = "比较准确"
    
    /// 分类准确性评分
    @State private var accuracyRating: Int = 3
    
    // MARK: - 初始化
    
    init(item: LuggageItemProtocol) {
        self.item = item
    }
    
    // MARK: - 视图
    
    // 标题视图
    private var titleView: some View {
        Text("物品分类")
            .font(.headline)
            .padding(.bottom, 4)
    }
    
    // 加载状态视图
    private var loadingView: some View {
        HStack {
            ProgressView()
            Text("正在分析物品...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
    
    // 错误视图
    private func errorView(_ error: String) -> some View {
        VStack {
            Text("分类失败: \(error)")
                .foregroundColor(.red)
                .padding()
            
            Button("重试") {
                Task {
                    await categorizeItem()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // 内容视图
    private var contentView: some View {
        Group {
            // 分类结果
            categorySection
            
            // 标签
            if showTags {
                tagSection
            }
            
            // 操作按钮
            actionButtons
        }
    }
    
    // 主体视图
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            titleView
            
            // 内容
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            Task {
                await categorizeItem()
                await generateTags()
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            categoryPickerView
        }
        .sheet(isPresented: $showFeedbackForm) {
            feedbackFormView
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
    
    // MARK: - 分类部分
    
    // 分类标签视图
    private func categoryLabelView(for category: ItemCategory) -> some View {
        HStack {
            Text(category.icon)
            Text(category.displayName)
                .fontWeight(.semibold)
            
            // 显示置信度指示器
            if userSelectedCategory == nil && confidence > 0 {
                confidenceIndicator(confidence)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(categoryColor(for: category).opacity(0.2))
        .cornerRadius(8)
    }
    
    // 编辑按钮视图
    private var editButtonView: some View {
        Button(action: {
            showCategoryPicker = true
        }) {
            Image(systemName: "pencil.circle")
                .imageScale(.large)
        }
    }
    
    // 分类修改信息视图
    private var categoryModificationInfoView: some View {
        Group {
            if userSelectedCategory != nil, let originalCategory = currentCategory, userSelectedCategory != originalCategory {
                Text("已从\(originalCategory.displayName)修改为\(userSelectedCategory!.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 置信度信息视图
    private var confidenceInfoView: some View {
        Group {
            if userSelectedCategory == nil && confidence > 0 {
                HStack {
                    Text("分类置信度:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(confidenceColor(confidence))
                }
            }
        }
    }
    
    // 分类部分
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("类别:")
                    .fontWeight(.medium)
                
                if let category = userSelectedCategory ?? currentCategory {
                    categoryLabelView(for: category)
                } else {
                    Text("未分类")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                editButtonView
            }
            
            categoryModificationInfoView
            
            confidenceInfoView
        }
    }
    
    /// 置信度指示器
    private func confidenceIndicator(_ confidence: Double) -> some View {
        ZStack {
            Circle()
                .fill(confidenceColor(confidence))
                .frame(width: 8, height: 8)
        }
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
    
    // MARK: - 标签部分
    
    // 刷新标签按钮
    private var refreshTagsButton: some View {
        Button(action: {
            Task {
                await generateTags()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .imageScale(.medium)
        }
    }
    
    // 标签项视图
    private func tagItemView(for tag: String) -> some View {
        Text(tag)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
    }
    
    // 标签流布局视图
    private var tagsFlowLayoutView: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                tagItemView(for: tag)
            }
        }
    }
    
    // 空标签提示视图
    private var emptyTagsView: some View {
        Group {
            if tags.isEmpty && !viewModel.isLoading {
                Text("暂无标签")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }
    
    // 标签部分
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("标签:")
                    .fontWeight(.medium)
                
                Spacer()
                
                refreshTagsButton
            }
            
            tagsFlowLayoutView
            
            emptyTagsView
        }
        .padding(.top, 8)
    }
    
    // MARK: - 操作按钮
    
    // 切换标签显示按钮
    private var toggleTagsButton: some View {
        Button(action: {
            withAnimation {
                showTags.toggle()
            }
        }) {
            Label(
                showTags ? "隐藏标签" : "显示标签",
                systemImage: showTags ? "tag.slash" : "tag"
            )
            .font(.caption)
        }
        .buttonStyle(.bordered)
    }
    
    // 提供反馈按钮
    private var feedbackButton: some View {
        Button(action: {
            showFeedbackForm = true
        }) {
            Label("提供反馈", systemImage: "hand.thumbsup")
                .font(.caption)
        }
        .buttonStyle(.bordered)
    }
    
    // 操作按钮
    private var actionButtons: some View {
        HStack {
            toggleTagsButton
            
            Spacer()
            
            feedbackButton
        }
        .padding(.top, 8)
    }
    
    // MARK: - 分类选择器视图
    
    // 分类按钮内容视图
    private func categoryButtonContent(for category: ItemCategory) -> some View {
        HStack {
            Text(category.icon)
                .font(.title2)
                .frame(width: 40)
            
            Text(category.displayName)
                .fontWeight(.medium)
            
            Spacer()
            
            let isSelected = category == userSelectedCategory
            let isCurrentDefault = userSelectedCategory == nil && category == currentCategory
            
            if isSelected || isCurrentDefault {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
    
    // 分类选择器视图
    private var categoryPickerView: some View {
        NavigationView {
            List {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectCategory(category)
                        showCategoryPicker = false
                    }) {
                        categoryButtonContent(for: category)
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
    
    // MARK: - 反馈表单视图
    
    // 星级评分视图组件
    private var ratingStarsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类准确性评分")
                .font(.subheadline)
            
            HStack {
                ForEach(1...5, id: \.self) { rating in
                    Button(action: {
                        accuracyRating = rating
                    }) {
                        starView(for: rating)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // 准确性选择器
    private var accuracyPickerView: some View {
        Picker("分类准确性", selection: $accuracySelection) {
            Text("非常准确").tag("非常准确")
            Text("比较准确").tag("比较准确")
            Text("不太准确").tag("不太准确")
            Text("完全不准确").tag("完全不准确")
        }
    }
    
    // 提交按钮
    private var submitButtonView: some View {
        Button("提交反馈") {
            submitFeedback()
            showFeedbackForm = false
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .foregroundColor(.accentColor)
    }
    
    // 反馈表单视图
    private var feedbackFormView: some View {
        NavigationView {
            Form {
                Section(header: Text("分类准确性反馈")) {
                    if let category = userSelectedCategory ?? currentCategory {
                        Text("当前分类: \(category.icon) \(category.displayName)")
                            .fontWeight(.medium)
                    }
                    
                    ratingStarsView
                    
                    accuracyPickerView
                    
                    TextField("其他反馈 (可选)", text: $feedbackText)
                }
                
                Section {
                    submitButtonView
                }
            }
            .navigationTitle("分类反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showFeedbackForm = false
                    }
                }
            })
        }
    }
    
    /// 星级评分视图
    private func starView(for rating: Int) -> some View {
        Image(systemName: rating <= accuracyRating ? "star.fill" : "star")
            .foregroundColor(rating <= accuracyRating ? .yellow : .gray)
            .font(.system(size: 24))
            .padding(4)
    }
    
    /// 提交反馈
    private func submitFeedback() {
        // 这里可以添加反馈提交逻辑
        // 例如，记录用户对分类准确性的评分
        print("用户对分类准确性的评分: \(accuracyRating)/5")
        print("用户准确性选择: \(accuracySelection)")
        print("用户反馈: \(feedbackText)")
        
        // 如果评分较低，可以提示用户修改分类
        if accuracyRating <= 2 && !feedbackText.isEmpty {
            // 可以将反馈发送到服务器或记录到本地
        }
    }
    
    // MARK: - 方法
    
    /// 分类物品
    private func categorizeItem() async {
        do {
            // 使用分类管理器进行分类
            let (category, confidenceScore) = try await categoryManager.categorizeItem(item)
            currentCategory = category
            confidence = confidenceScore
        } catch {
            print("分类失败: \(error)")
            
            // 显示错误提示
            errorMessage = "分类失败: \(error.localizedDescription)"
            errorAlert = true
            
            // 回退到视图模型方法
            await viewModel.categorizeItem(item)
            currentCategory = viewModel.itemCategory ?? .other // 确保有默认值
            confidence = 0.7 // 默认置信度
        }
    }
    
    /// 生成标签
    private func generateTags() async {
        do {
            // 使用分类管理器生成标签
            tags = try await categoryManager.generateItemTags(for: item)
        } catch {
            print("生成标签失败: \(error)")
            
            // 回退到视图模型方法
            tags = await viewModel.generateItemTags(for: item)
        }
    }
    
    /// 选择类别
    private func selectCategory(_ category: ItemCategory) {
        userSelectedCategory = category
        
        // 如果用户选择了与AI不同的类别，记录这个偏好
        if let originalCategory = currentCategory, category != originalCategory {
            // 使用分类管理器记录用户偏好
            categoryManager.learnUserCategoryPreference(
                item: item,
                userCategory: category,
                originalCategory: originalCategory
            )
        }
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

// MARK: - 流布局视图

/// 流布局视图
/// 用于标签的流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width > width {
                // 换行
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
            height = max(height, y + maxHeight)
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width > bounds.maxX {
                // 换行
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: viewSize.width, height: viewSize.height))
            
            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
        }
    }
}

// MARK: - 预览

struct AIItemCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个模拟的物品
        let mockItem = MockLuggageItem(
            id: UUID(),
            name: "iPhone 13",
            weight: 200,
            volume: 100
        )
        
        return AIItemCategoryView(item: mockItem)
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