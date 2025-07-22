import SwiftUI

/// 为清单选择现有物品页面
/// 用户可以从所有物品列表中选择一个或多个物品添加到清单中
struct SelectItemsForChecklistView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LuggageViewModel
    
    @State private var selectedItemIds: Set<UUID> = []
    
    // 用于返回选中的物品名称列表
    var onItemsSelected: ([String]) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.allItems) { item in
                    HStack {
                        Image(systemName: selectedItemIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedItemIds.contains(item.id) ? .blue : .secondary)
                            .onTapGesture {
                                toggleSelection(for: item.id)
                            }
                        Text(item.name)
                        Spacer()
                    }
                    .contentShape(Rectangle()) // 使整个HStack可点击
                    .onTapGesture {
                        toggleSelection(for: item.id)
                    }
                }
            }
            .navigationTitle("选择物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加 (\(selectedItemIds.count)) ") {
                        addSelectedItemsToChecklist()
                    }
                    .disabled(selectedItemIds.isEmpty)
                }
            }
        }
    }
    
    /// 切换物品的选中状态
    private func toggleSelection(for itemId: UUID) {
        if selectedItemIds.contains(itemId) {
            selectedItemIds.remove(itemId)
        } else {
            selectedItemIds.insert(itemId)
        }
    }
    
    /// 将选中的物品名称添加到清单中
    private func addSelectedItemsToChecklist() {
        let selectedNames = viewModel.allItems.filter { selectedItemIds.contains($0.id) }.map { $0.name }
        onItemsSelected(selectedNames)
        dismiss()
    }
}