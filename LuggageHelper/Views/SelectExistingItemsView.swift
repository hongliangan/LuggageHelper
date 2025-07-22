import SwiftUI

/// 选择现有物品页面
/// 用户可以从独立物品列表中选择一个或多个物品添加到行李中
struct SelectExistingItemsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LuggageViewModel
    
    @State private var selectedItems: Set<UUID> = []
    
    let luggageId: UUID
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.standaloneItems) { item in
                    HStack {
                        Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedItems.contains(item.id) ? .blue : .secondary)
                            .onTapGesture {
                                if selectedItems.contains(item.id) {
                                    selectedItems.remove(item.id)
                                } else {
                                    selectedItems.insert(item.id)
                                }
                            }
                        ItemRowView(item: item, compact: true)
                    }
                    .contentShape(Rectangle()) // 使整个HStack可点击
                    .onTapGesture {
                        if selectedItems.contains(item.id) {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    }
                }
            }
            .navigationTitle("选择物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加 (\(selectedItems.count))") {
                        addSelectedItemsToLuggage()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
        }
    }
    
    /// 将选中的物品添加到行李中
    private func addSelectedItemsToLuggage() {
        let itemsToAdd = viewModel.standaloneItems.filter { selectedItems.contains($0.id) }
        
        for item in itemsToAdd {
            viewModel.moveItemToLuggage(item, to: luggageId)
        }
        dismiss()
    }
}