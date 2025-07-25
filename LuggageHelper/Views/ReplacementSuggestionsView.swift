import SwiftUI

/// 替换建议管理视图
struct ReplacementSuggestionsView: View {
    @StateObject private var replacementService = ItemReplacementService.shared
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var selectedSuggestions: Set<UUID> = []
    @State private var showingBatchActions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标签页选择器
                Picker("视图", selection: $selectedTab) {
                    Text("待处理 (\(replacementService.pendingReplacements.count))").tag(0)
                    Text("历史记录 (\(replacementService.replacementHistory.count))").tag(1)
                    Text("统计信息").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    pendingSuggestionsView
                        .tag(0)
                    
                    replacementHistoryView
                        .tag(1)
                    
                    statisticsView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("替换建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedTab == 0 && !replacementService.pendingReplacements.isEmpty {
                        Button(selectedSuggestions.isEmpty ? "全选" : "取消选择") {
                            if selectedSuggestions.isEmpty {
                                selectedSuggestions = Set(replacementService.pendingReplacements.map { $0.id })
                            } else {
                                selectedSuggestions.removeAll()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("设置") {
                            showingSettings = true
                        }
                        
                        Button("清理过期建议") {
                            replacementService.cleanupExpiredSuggestions()
                        }
                        
                        if selectedTab == 0 && !selectedSuggestions.isEmpty {
                            Button("批量操作") {
                                showingBatchActions = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ReplacementSettingsView()
            }
            .actionSheet(isPresented: $showingBatchActions) {
                ActionSheet(
                    title: Text("批量操作"),
                    message: Text("选择了 \(selectedSuggestions.count) 个建议"),
                    buttons: [
                        .default(Text("全部接受")) {
                            batchAcceptSuggestions()
                        },
                        .destructive(Text("全部拒绝")) {
                            batchRejectSuggestions()
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    // MARK: - 待处理建议视图
    
    private var pendingSuggestionsView: some View {
        Group {
            if replacementService.pendingReplacements.isEmpty {
                emptyPendingView
            } else {
                List {
                    ForEach(replacementService.pendingReplacements) { suggestion in
                        ReplacementSuggestionRow(
                            suggestion: suggestion,
                            isSelected: selectedSuggestions.contains(suggestion.id),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedSuggestions.insert(suggestion.id)
                                } else {
                                    selectedSuggestions.remove(suggestion.id)
                                }
                            },
                            onAccept: { alternativeIndex in
                                replacementService.acceptReplacementSuggestion(
                                    suggestionId: suggestion.id,
                                    selectedAlternativeIndex: alternativeIndex
                                )
                            },
                            onReject: {
                                replacementService.rejectReplacementSuggestion(suggestionId: suggestion.id)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyPendingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("没有待处理的建议")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("当前没有需要处理的替换建议。AI会根据您的行李配置自动生成优化建议。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 历史记录视图
    
    private var replacementHistoryView: some View {
        Group {
            if replacementService.replacementHistory.isEmpty {
                emptyHistoryView
            } else {
                List {
                    ForEach(replacementService.replacementHistory.sorted { $0.appliedAt > $1.appliedAt }) { record in
                        ReplacementHistoryRow(
                            record: record,
                            onUndo: {
                                replacementService.undoReplacement(recordId: record.id)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("暂无替换记录")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("您还没有应用过任何替换建议。接受建议后，记录会显示在这里。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 统计信息视图
    
    private var statisticsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let stats = replacementService.getReplacementStatistics()
                
                // 总体统计
                StatisticsCard(
                    title: "总体统计",
                    items: [
                        ("总替换次数", "\(stats.totalReplacements)次"),
                        ("总重量节省", formatWeight(stats.totalWeightSavings)),
                        ("总体积节省", formatVolume(stats.totalVolumeSavings)),
                        ("平均重量节省", formatWeight(stats.averageWeightSavings)),
                        ("平均体积节省", formatVolume(stats.averageVolumeSavings))
                    ]
                )
                
                // 类别统计
                if !stats.categoryStatistics.isEmpty {
                    StatisticsCard(
                        title: "类别统计",
                        items: stats.categoryStatistics.map { category, data in
                            (category.displayName, "\(data.count)次 | \(formatWeight(data.weightSavings))")
                        }
                    )
                }
                
                // 设置状态
                SettingsStatusCard(settings: replacementService.autoReplacementSettings)
            }
            .padding()
        }
    }
    
    // MARK: - 批量操作方法
    
    private func batchAcceptSuggestions() {
        var decisions: [UUID: (accept: Bool, alternativeIndex: Int)] = [:]
        
        for suggestionId in selectedSuggestions {
            decisions[suggestionId] = (accept: true, alternativeIndex: 0)
        }
        
        replacementService.batchProcessReplacements(decisions)
        selectedSuggestions.removeAll()
    }
    
    private func batchRejectSuggestions() {
        var decisions: [UUID: (accept: Bool, alternativeIndex: Int)] = [:]
        
        for suggestionId in selectedSuggestions {
            decisions[suggestionId] = (accept: false, alternativeIndex: 0)
        }
        
        replacementService.batchProcessReplacements(decisions)
        selectedSuggestions.removeAll()
    }
    
    // MARK: - 格式化方法
    
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

// MARK: - 替换建议行

struct ReplacementSuggestionRow: View {
    let suggestion: ItemReplacementService.ReplacementSuggestion
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onAccept: (Int) -> Void
    let onReject: () -> Void
    
    @State private var selectedAlternativeIndex = 0
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                Button(action: {
                    onSelectionChanged(!isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.originalItem.category.icon)
                            .font(.title2)
                        
                        Text(suggestion.originalItem.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 优先级标签
                        Text(suggestion.priority.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(suggestion.priority.color.opacity(0.2))
                            .foregroundColor(suggestion.priority.color)
                            .cornerRadius(4)
                    }
                    
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // 替代品选择
            if !suggestion.alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("替代品选择 (\(suggestion.alternatives.count)个)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if suggestion.alternatives.count > 1 {
                        Picker("替代品", selection: $selectedAlternativeIndex) {
                            ForEach(suggestion.alternatives.indices, id: \.self) { index in
                                Text(suggestion.alternatives[index].name).tag(index)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 选中替代品的信息
                    let selectedAlternative = suggestion.alternatives[selectedAlternativeIndex]
                    AlternativePreview(
                        original: suggestion.originalItem,
                        alternative: selectedAlternative
                    )
                }
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("查看详情") {
                    showingDetails = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("拒绝") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button("接受") {
                    onAccept(selectedAlternativeIndex)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetails) {
            ReplacementSuggestionDetailView(suggestion: suggestion)
        }
    }
}

// MARK: - 替代品预览

struct AlternativePreview: View {
    let original: LuggageItem
    let alternative: ItemInfo
    
    private var weightChange: Double {
        alternative.weight - original.weight
    }
    
    private var volumeChange: Double {
        alternative.volume - original.volume
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 替代品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(alternative.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Text(formatWeight(alternative.weight))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatVolume(alternative.volume))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 变化指示
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: weightChange > 0 ? "arrow.up" : weightChange < 0 ? "arrow.down" : "minus")
                        .foregroundColor(weightChange > 0 ? .red : weightChange < 0 ? .green : .gray)
                        .font(.caption)
                    
                    Text(formatWeight(abs(weightChange)))
                        .font(.caption)
                        .foregroundColor(weightChange > 0 ? .red : weightChange < 0 ? .green : .gray)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: volumeChange > 0 ? "arrow.up" : volumeChange < 0 ? "arrow.down" : "minus")
                        .foregroundColor(volumeChange > 0 ? .red : volumeChange < 0 ? .green : .gray)
                        .font(.caption)
                    
                    Text(formatVolume(abs(volumeChange)))
                        .font(.caption)
                        .foregroundColor(volumeChange > 0 ? .red : volumeChange < 0 ? .green : .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
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

// MARK: - 替换历史记录行

struct ReplacementHistoryRow: View {
    let record: ItemReplacementService.ReplacementRecord
    let onUndo: () -> Void
    
    @State private var showingUndoConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.originalItem.category.icon)
                            .font(.title2)
                        
                        Text("\(record.originalItem.name) → \(record.replacementItem.name)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Text(record.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(record.appliedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(record.userInitiated ? "手动" : "自动")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(record.userInitiated ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(record.userInitiated ? .blue : .green)
                        .cornerRadius(4)
                }
            }
            
            // 节省信息
            if !record.savingsDescription.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(record.savingsDescription)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("撤销") {
                        showingUndoConfirmation = true
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .alert("撤销替换", isPresented: $showingUndoConfirmation) {
            Button("取消", role: .cancel) { }
            Button("撤销", role: .destructive) {
                onUndo()
            }
        } message: {
            Text("确定要撤销这次替换吗？这将恢复原始物品。")
        }
    }
}

// MARK: - 统计卡片

struct StatisticsCard: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.body)
                        Spacer()
                        Text(item.1)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 设置状态卡片

struct SettingsStatusCard: View {
    let settings: ItemReplacementService.AutoReplacementSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自动替换设置")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("自动替换")
                    Spacer()
                    Text(settings.isEnabled ? "已启用" : "已禁用")
                        .foregroundColor(settings.isEnabled ? .green : .red)
                }
                
                HStack {
                    Text("高优先级自动应用")
                    Spacer()
                    Text(settings.autoApplyHighPriority ? "是" : "否")
                        .foregroundColor(settings.autoApplyHighPriority ? .green : .gray)
                }
                
                HStack {
                    Text("中优先级自动应用")
                    Spacer()
                    Text(settings.autoApplyMediumPriority ? "是" : "否")
                        .foregroundColor(settings.autoApplyMediumPriority ? .green : .gray)
                }
                
                HStack {
                    Text("启用通知")
                    Spacer()
                    Text(settings.notificationEnabled ? "是" : "否")
                        .foregroundColor(settings.notificationEnabled ? .green : .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 预览

struct ReplacementSuggestionsView_Previews: PreviewProvider {
    static var previews: some View {
        ReplacementSuggestionsView()
    }
}