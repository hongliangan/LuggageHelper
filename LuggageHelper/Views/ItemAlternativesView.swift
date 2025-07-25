import SwiftUI

/// 物品替代建议视图
struct ItemAlternativesView: View {
    let originalItem: LuggageItem
    let constraints: PackingConstraints
    let onItemReplaced: ((LuggageItem, ItemInfo) -> Void)?
    
    @StateObject private var llmService = LLMAPIService.shared
    @StateObject private var configManager = LLMConfigurationManager.shared
    
    @State private var alternatives: [ItemInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAlternative: ItemInfo?
    @State private var showingReplaceConfirmation = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 原物品信息
                originalItemSection
                
                // 约束条件显示
                constraintsSection
                
                // 替代品列表
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if alternatives.isEmpty {
                    emptyStateView
                } else {
                    alternativesContent
                }
                
                Spacer()
            }
            .navigationTitle("替代品建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        loadAlternatives()
                    }
                    .disabled(isLoading || !configManager.isConfigValid)
                }
            }
            .onAppear {
                if alternatives.isEmpty {
                    loadAlternatives()
                }
            }
            .alert("替换物品", isPresented: $showingReplaceConfirmation) {
                Button("取消", role: .cancel) { }
                Button("替换") {
                    replaceItem()
                }
            } message: {
                if let alternative = selectedAlternative {
                    Text("确定要用 \"\(alternative.name)\" 替换 \"\(originalItem.name)\" 吗？")
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var originalItemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("原物品")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Text(originalItem.category.icon)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(originalItem.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        Label(formatWeight(originalItem.weight), systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(formatVolume(originalItem.volume), systemImage: "cube")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if originalItem.quantity > 1 {
                            Label("×\(originalItem.quantity)", systemImage: "number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("需要替代")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("约束条件")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(.blue)
                    Text("最大重量：\(formatWeight(constraints.maxWeight))")
                        .font(.body)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "cube.fill")
                        .foregroundColor(.green)
                    Text("最大体积：\(formatVolume(constraints.maxVolume))")
                        .font(.body)
                    Spacer()
                }
                
                if !constraints.restrictions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("限制条件：")
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        ForEach(constraints.restrictions, id: \.self) { restriction in
                            Text("• \(restriction)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在寻找替代品...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("AI正在根据约束条件为您推荐合适的替代品")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("获取替代建议")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("AI将根据您的约束条件推荐合适的替代品，帮助您优化行李配置。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("开始搜索") {
                loadAlternatives()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("搜索失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                loadAlternatives()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var alternativesContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(alternatives, id: \.name) { alternative in
                    AlternativeItemCard(
                        alternative: alternative,
                        originalItem: originalItem,
                        constraints: constraints,
                        onSelectTapped: {
                            selectedAlternative = alternative
                            showingReplaceConfirmation = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - 方法
    
    private func loadAlternatives() {
        guard configManager.isConfigValid else {
            errorMessage = "请先配置LLM API"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 转换约束条件
                let alternativeConstraints = AlternativeConstraints(
                    maxWeight: constraints.maxWeight,
                    maxVolume: constraints.maxVolume,
                    requiredFeatures: constraints.restrictions
                )
                
                // 创建ItemInfo从LuggageItem
                let itemInfo = ItemInfo(
                    name: originalItem.name,
                    category: originalItem.category,
                    weight: originalItem.weight,
                    volume: originalItem.volume,
                    confidence: 1.0,
                    source: "用户输入"
                )
                
                let alternativeItems = try await llmService.suggestAlternatives(
                    for: itemInfo,
                    constraints: alternativeConstraints
                )
                
                // 转换AlternativeItem为ItemInfo
                let alternatives = alternativeItems.map { alt in
                    ItemInfo(
                        name: alt.name,
                        category: alt.category,
                        weight: alt.weight,
                        volume: alt.volume,
                        dimensions: alt.dimensions,
                        confidence: alt.suitability,
                        source: alt.reason
                    )
                }
                
                await MainActor.run {
                    self.alternatives = alternatives
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func replaceItem() {
        guard let alternative = selectedAlternative else { return }
        
        // 通过回调通知父视图进行替换
        onItemReplaced?(originalItem, alternative)
        
        dismiss()
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
    
    private func formatVolume(_ cm3: Double) -> String {
        if cm3 >= 1000 {
            return String(format: "%.1fL", cm3 / 1000.0)
        } else {
            return String(format: "%.0fcm³", cm3)
        }
    }
}

// MARK: - 替代品卡片

struct AlternativeItemCard: View {
    let alternative: ItemInfo
    let originalItem: LuggageItem
    let constraints: PackingConstraints
    let onSelectTapped: () -> Void
    
    private var weightSavings: Double {
        originalItem.weight - alternative.weight
    }
    
    private var volumeSavings: Double {
        originalItem.volume - alternative.volume
    }
    
    private var meetsConstraints: Bool {
        alternative.weight <= constraints.maxWeight && alternative.volume <= constraints.maxVolume
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 替代品基本信息
            HStack(spacing: 12) {
                Text(alternative.category.icon)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alternative.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        Label(formatWeight(alternative.weight), systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(formatVolume(alternative.volume), systemImage: "cube")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 约束符合状态
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: meetsConstraints ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(meetsConstraints ? .green : .red)
                        .font(.title2)
                    
                    Text(meetsConstraints ? "符合约束" : "超出限制")
                        .font(.caption)
                        .foregroundColor(meetsConstraints ? .green : .red)
                }
            }
            
            // 对比信息
            comparisonSection
            
            // 推荐理由
            if !alternative.alternatives.isEmpty, let reason = alternative.alternatives.first?.source {
                reasonSection(reason)
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("查看详情") {
                    // 显示详细信息
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("选择此替代品") {
                    onSelectTapped()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!meetsConstraints)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(meetsConstraints ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var comparisonSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("对比原物品")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // 重量对比
                VStack(alignment: .leading, spacing: 4) {
                    Text("重量变化")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: weightSavings > 0 ? "arrow.down" : weightSavings < 0 ? "arrow.up" : "minus")
                            .foregroundColor(weightSavings > 0 ? .green : weightSavings < 0 ? .red : .gray)
                            .font(.caption)
                        
                        Text(formatWeight(abs(weightSavings)))
                            .font(.caption)
                            .foregroundColor(weightSavings > 0 ? .green : weightSavings < 0 ? .red : .gray)
                    }
                }
                
                // 体积对比
                VStack(alignment: .leading, spacing: 4) {
                    Text("体积变化")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: volumeSavings > 0 ? "arrow.down" : volumeSavings < 0 ? "arrow.up" : "minus")
                            .foregroundColor(volumeSavings > 0 ? .green : volumeSavings < 0 ? .red : .gray)
                            .font(.caption)
                        
                        Text(formatVolume(abs(volumeSavings)))
                            .font(.caption)
                            .foregroundColor(volumeSavings > 0 ? .green : volumeSavings < 0 ? .red : .gray)
                    }
                }
                
                Spacer()
                
                // 置信度
                VStack(alignment: .trailing, spacing: 4) {
                    Text("推荐度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(index < Int(alternative.confidence * 5) ? .yellow : .gray.opacity(0.3))
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func reasonSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("推荐理由")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(reason)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
    
    private func formatVolume(_ cm3: Double) -> String {
        if cm3 >= 1000 {
            return String(format: "%.1fL", cm3 / 1000.0)
        } else {
            return String(format: "%.0fcm³", cm3)
        }
    }
}

// MARK: - 批量替代建议视图

struct BatchAlternativesView: View {
    let items: [LuggageItem]
    let constraints: PackingConstraints
    let onItemsReplaced: (([LuggageItem: ItemInfo]) -> Void)?
    
    @StateObject private var llmService = LLMAPIService.shared
    @State private var alternativeResults: [String: [ItemInfo]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItems: Set<String> = []
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if alternativeResults.isEmpty {
                    emptyStateView
                } else {
                    resultsContent
                }
            }
            .navigationTitle("批量替代建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用选择") {
                        applySelectedAlternatives()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
            .onAppear {
                if alternativeResults.isEmpty {
                    loadBatchAlternatives()
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在为\(items.count)件物品寻找替代品...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("批量替代建议")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("为多个物品同时寻找替代品，优化整体配置")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("开始搜索") {
                loadBatchAlternatives()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("搜索失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                loadBatchAlternatives()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(items, id: \.id) { item in
                    if let alternatives = alternativeResults[item.name], !alternatives.isEmpty {
                        BatchAlternativeSection(
                            originalItem: item,
                            alternatives: alternatives,
                            isSelected: selectedItems.contains(item.name),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedItems.insert(item.name)
                                } else {
                                    selectedItems.remove(item.name)
                                }
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private func loadBatchAlternatives() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 转换约束条件
                let alternativeConstraints = AlternativeConstraints(
                    maxWeight: constraints.maxWeight,
                    maxVolume: constraints.maxVolume,
                    requiredFeatures: constraints.restrictions
                )
                
                // 转换物品列表
                let itemInfos = items.map { item in
                    ItemInfo(
                        name: item.name,
                        category: item.category,
                        weight: item.weight,
                        volume: item.volume,
                        confidence: 1.0,
                        source: "用户输入"
                    )
                }
                
                let batchResults = try await llmService.batchSuggestAlternatives(
                    for: itemInfos,
                    constraints: alternativeConstraints
                )
                
                // 转换结果
                var results: [String: [ItemInfo]] = [:]
                for (itemName, alternativeItems) in batchResults {
                    let alternatives = alternativeItems.map { alt in
                        ItemInfo(
                            name: alt.name,
                            category: alt.category,
                            weight: alt.weight,
                            volume: alt.volume,
                            dimensions: alt.dimensions,
                            confidence: alt.suitability,
                            source: alt.reason
                        )
                    }
                    results[itemName] = alternatives
                }
                
                await MainActor.run {
                    self.alternativeResults = results
                    self.isLoading = false
                    
                    if results.isEmpty {
                        self.errorMessage = "未找到任何替代品建议"
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func applySelectedAlternatives() {
        var replacements: [LuggageItem: ItemInfo] = [:]
        
        for itemName in selectedItems {
            if let originalItem = items.first(where: { $0.name == itemName }),
               let alternatives = alternativeResults[itemName],
               !alternatives.isEmpty {
                // 使用第一个替代品作为默认选择
                replacements[originalItem] = alternatives[0]
            }
        }
        
        if !replacements.isEmpty {
            onItemsReplaced?(replacements)
        }
        
        dismiss()
    }
}

// MARK: - 批量替代品区域

struct BatchAlternativeSection: View {
    let originalItem: LuggageItem
    let alternatives: [ItemInfo]
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    @State private var selectedAlternativeIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 原物品信息
            HStack {
                Button(action: {
                    onSelectionChanged(!isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                Text(originalItem.category.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(originalItem.name)
                        .font(.headline)
                    
                    Text("重量: \(formatWeight(originalItem.weight))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(alternatives.count)个替代品")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if isSelected && !alternatives.isEmpty {
                // 替代品选择器
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择替代品:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("替代品", selection: $selectedAlternativeIndex) {
                        ForEach(alternatives.indices, id: \.self) { index in
                            Text(alternatives[index].name).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // 选中替代品的详细信息
                    let selectedAlternative = alternatives[selectedAlternativeIndex]
                    HStack {
                        Text("重量: \(formatWeight(selectedAlternative.weight))")
                            .font(.caption)
                        
                        Spacer()
                        
                        let weightSavings = originalItem.weight - selectedAlternative.weight
                        if weightSavings > 0 {
                            Text("减重 \(formatWeight(weightSavings))")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if weightSavings < 0 {
                            Text("增重 \(formatWeight(abs(weightSavings)))")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBlue).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
}

// MARK: - 预览

struct ItemAlternativesView_Previews: PreviewProvider {
    static var previews: some View {
        ItemAlternativesView(
            originalItem: LuggageItem(
                id: UUID(),
                name: "厚重毛衣",
                volume: 1200,
                weight: 800,
                category: .clothing,
                imagePath: nil,
                location: nil,
                note: nil
            ),
            constraints: PackingConstraints(
                maxWeight: 500,
                maxVolume: 800,
                restrictions: ["轻便", "保暖"],
                priorities: []
            ),
            onItemReplaced: { original, alternative in
                print("替换 \(original.name) 为 \(alternative.name)")
            }
        )
    }
}