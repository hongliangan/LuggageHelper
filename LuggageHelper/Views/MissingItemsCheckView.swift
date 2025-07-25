import SwiftUI

/// 遗漏物品检查视图
struct MissingItemsCheckView: View {
    @StateObject private var llmService = LLMAPIService.shared
    @StateObject private var configManager = LLMConfigurationManager.shared
    
    let checklist: [LuggageItem]
    let travelPlan: TravelPlan
    
    @State private var missingItems: [MissingItemAlert] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddItemSheet = false
    @State private var selectedMissingItem: MissingItemAlert?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 检查状态头部
                checkStatusHeader
                
                if isLoading {
                    loadingView
                } else if missingItems.isEmpty && errorMessage == nil {
                    emptyStateView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    missingItemsList
                }
                
                Spacer()
                
                // 底部操作按钮
                bottomActionButtons
            }
            .navigationTitle("遗漏物品检查")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重新检查") {
                        checkMissingItems()
                    }
                    .disabled(isLoading || !configManager.isConfigValid)
                }
            }
            .onAppear {
                if missingItems.isEmpty {
                    checkMissingItems()
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                if let item = selectedMissingItem {
                    AddMissingItemView(missingItem: item) { newItem in
                        // 这里可以添加将物品添加到清单的逻辑
                        // 暂时只是关闭sheet
                        showingAddItemSheet = false
                        selectedMissingItem = nil
                    }
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var checkStatusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("智能遗漏检查")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("基于您的旅行计划分析可能遗漏的重要物品")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 旅行信息摘要
            HStack(spacing: 16) {
                InfoChip(icon: "location.fill", text: travelPlan.destination)
                InfoChip(icon: "calendar", text: "\(travelPlan.duration)天")
                InfoChip(icon: "thermometer.sun.fill", text: travelPlan.season)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在分析您的清单...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("AI正在根据您的旅行计划检查可能遗漏的重要物品")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("清单完整！")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("根据您的旅行计划，当前清单已包含所有重要物品。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重新检查") {
                checkMissingItems()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("检查失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                checkMissingItems()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var missingItemsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(missingItems, id: \.itemName) { item in
                    MissingItemCard(
                        item: item,
                        onAddTapped: {
                            selectedMissingItem = item
                            showingAddItemSheet = true
                        },
                        onIgnoreTapped: {
                            withAnimation {
                                missingItems.removeAll { $0.itemName == item.itemName }
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var bottomActionButtons: some View {
        VStack(spacing: 12) {
            if !missingItems.isEmpty {
                HStack(spacing: 12) {
                    Button("全部忽略") {
                        withAnimation {
                            missingItems.removeAll()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                    
                    Button("批量添加") {
                        // 实现批量添加逻辑
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Text("提示：AI建议仅供参考，请根据实际需要决定是否添加")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 方法
    
    private func checkMissingItems() {
        guard configManager.isConfigValid else {
            errorMessage = "请先配置LLM API"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let alerts = try await llmService.checkMissingItems(
                    checklist: checklist,
                    travelPlan: travelPlan
                )
                
                await MainActor.run {
                    self.missingItems = alerts
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
}

// MARK: - 支持视图

/// 信息芯片
struct InfoChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

/// 遗漏物品卡片
struct MissingItemCard: View {
    let item: MissingItemAlert
    let onAddTapped: () -> Void
    let onIgnoreTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.category.icon)
                            .font(.title2)
                        
                        Text(item.itemName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        ImportanceBadge(importance: item.importance)
                    }
                    
                    Text(item.reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // 建议信息
            if let suggestion = item.suggestion {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemYellow).opacity(0.1))
                .cornerRadius(8)
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("忽略") {
                    onIgnoreTapped()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("添加到清单") {
                    onAddTapped()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// 重要性徽章
struct ImportanceBadge: View {
    let importance: ImportanceLevel
    
    var body: some View {
        Text(importance.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(importance.color.opacity(0.2))
            .foregroundColor(importance.color)
            .cornerRadius(4)
    }
}

/// 添加遗漏物品视图
struct AddMissingItemView: View {
    let missingItem: MissingItemAlert
    let onAdd: (LuggageItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var itemName: String
    @State private var quantity = 1
    @State private var weight: Double = 100
    @State private var notes = ""
    
    init(missingItem: MissingItemAlert, onAdd: @escaping (LuggageItem) -> Void) {
        self.missingItem = missingItem
        self.onAdd = onAdd
        self._itemName = State(initialValue: missingItem.itemName)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("物品信息") {
                    HStack {
                        Text(missingItem.category.icon)
                            .font(.title2)
                        
                        TextField("物品名称", text: $itemName)
                    }
                    
                    Stepper("数量: \(quantity)", value: $quantity, in: 1...99)
                    
                    HStack {
                        Text("预估重量")
                        Spacer()
                        TextField("重量", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("AI建议") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("推荐理由")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(missingItem.reason)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if let suggestion = missingItem.suggestion {
                            Text("具体建议")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("备注") {
                    TextField("添加备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        addItem()
                    }
                    .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addItem() {
        let newItem = LuggageItem(
            name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
            volume: weight * 0.8, // 简单的体积估算
            weight: weight,
            category: missingItem.category,
            imagePath: nil,
            location: nil,
            note: notes.isEmpty ? nil : notes
        )
        
        onAdd(newItem)
        dismiss()
    }
}

// MARK: - ImportanceLevel 扩展

extension ImportanceLevel {
    var color: Color {
        switch self {
        case .essential:
            return .red
        case .important:
            return .orange
        case .recommended:
            return .blue
        case .optional:
            return .gray
        }
    }
}

// MARK: - 预览

// 修复预览中的构造函数调用
struct MissingItemsCheckView_Previews: PreviewProvider {
    static var previews: some View {
        MissingItemsCheckView(
            checklist: [
                LuggageItem(id: UUID(), name: "T恤", volume: 500, weight: 200, category: .clothing, imagePath: nil, location: nil, note: nil),
                LuggageItem(id: UUID(), name: "牛仔裤", volume: 800, weight: 600, category: .clothing, imagePath: nil, location: nil, note: nil),
                LuggageItem(id: UUID(), name: "笔记本电脑", volume: 2000, weight: 1500, category: .electronics, imagePath: nil, location: nil, note: nil)
            ],
            travelPlan: TravelPlan(
                destination: "东京",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                season: "春季",
                activities: ["观光", "购物", "美食"]
            )
        )
    }
}

