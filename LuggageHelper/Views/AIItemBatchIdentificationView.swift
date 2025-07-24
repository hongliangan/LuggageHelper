import SwiftUI

/// AI 物品批量识别视图
/// 支持一次识别多个物品
struct AIItemBatchIdentificationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var aiViewModel = AIViewModel()
    
    @State private var itemNames: String = ""
    @State private var identifiedItems: [ItemInfo] = []
    @State private var isProcessing = false
    @State private var currentItemIndex = 0
    @State private var progress: Double = 0
    @State private var showResults = false
    @State private var selectedItems: Set<UUID> = []
    
    // 回调函数，用于将识别结果传递给父视图
    var onItemsIdentified: ([ItemInfo]) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showResults {
                    resultsView
                } else {
                    inputView
                }
            }
            .navigationTitle("批量识别物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                if showResults {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("使用选中项") {
                            let selectedItemsList = identifiedItems.filter { selectedItems.contains($0.id) }
                            onItemsIdentified(selectedItemsList)
                            dismiss()
                        }
                        .disabled(selectedItems.isEmpty)
                    }
                }
            })
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 20) {
            // 说明
            VStack(alignment: .leading, spacing: 8) {
                Text("批量识别物品")
                    .font(.headline)
                
                Text("请输入多个物品名称，每行一个。AI 将自动识别每个物品的重量、体积和类别。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // 输入区域
            VStack(spacing: 12) {
                TextEditor(text: $itemNames)
                    .frame(height: 200)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if itemNames.isEmpty {
                                Text("输入物品名称，每行一个\n例如：\niPhone 15 Pro\n牛仔裤\n运动鞋")
                                    .foregroundColor(.gray.opacity(0.7))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .allowsHitTesting(false)
                            }
                        }
                    )
                
                // 示例按钮
                Button("插入示例物品") {
                    itemNames = "iPhone 15 Pro\n牛仔裤\n运动鞋\n充电器\n洗发水\n毛巾\n雨伞"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                // 开始识别按钮
                Button {
                    startBatchIdentification()
                } label: {
                    if isProcessing {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在识别 (\(currentItemIndex)/\(getItemList().count))")
                        }
                    } else {
                        Text("开始批量识别")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(itemNames.isEmpty || isProcessing)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                
                if isProcessing {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .padding(.top, 8)
                }
            }
            .padding()
            
            Spacer()
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 16) {
            // 结果统计
            HStack {
                Text("识别结果")
                    .font(.headline)
                Spacer()
                Text("\(identifiedItems.count) 个物品")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // 全选/取消全选
            HStack {
                Button(selectedItems.count == identifiedItems.count ? "取消全选" : "全选") {
                    if selectedItems.count == identifiedItems.count {
                        selectedItems.removeAll()
                    } else {
                        selectedItems = Set(identifiedItems.map { $0.id })
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("已选择 \(selectedItems.count) 项")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // 结果列表
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(identifiedItems) { item in
                        HStack(alignment: .top) {
                            // 选择框
                            Button {
                                if selectedItems.contains(item.id) {
                                    selectedItems.remove(item.id)
                                } else {
                                    selectedItems.insert(item.id)
                                }
                            } label: {
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundColor(selectedItems.contains(item.id) ? .blue : .gray)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            
                            // 物品信息卡片
                            AIItemInfoCard(item: item, showActions: false)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 16)
            }
            
            // 底部按钮
            Button("重新识别") {
                showResults = false
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取物品列表
    private func getItemList() -> [String] {
        return itemNames
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// 开始批量识别
    private func startBatchIdentification() {
        let items = getItemList()
        guard !items.isEmpty else { return }
        
        isProcessing = true
        progress = 0
        currentItemIndex = 0
        identifiedItems = []
        
        Task {
            for (index, itemName) in items.enumerated() {
                currentItemIndex = index + 1
                progress = Double(index) / Double(items.count)
                
                do {
                    // 使用 AIService 识别物品
                    let result = try await aiViewModel.aiService.identifyItem(name: itemName)
                    await MainActor.run {
                        identifiedItems.append(result)
                    }
                } catch {
                    // 如果识别失败，添加一个默认物品
                    await MainActor.run {
                        identifiedItems.append(ItemInfo.defaultItem(name: itemName))
                    }
                }
            }
            
            await MainActor.run {
                isProcessing = false
                progress = 1.0
                showResults = true
                // 默认全选
                selectedItems = Set(identifiedItems.map { $0.id })
            }
        }
    }
}

#if DEBUG
struct AIItemBatchIdentificationView_Previews: PreviewProvider {
    static var previews: some View {
        AIItemBatchIdentificationView { _ in }
    }
}
#endif