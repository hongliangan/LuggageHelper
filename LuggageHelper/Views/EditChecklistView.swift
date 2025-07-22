import SwiftUI

/// 编辑现有出行清单页面
/// 允许用户修改清单标题和项目
struct EditChecklistView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: LuggageViewModel
    
    @State private var title: String
    @State private var items: [TravelChecklistItem]
    @State private var showingSelectItems = false // 控制选择物品视图的显示
    
    let checklist: TravelChecklist // 接收要编辑的清单对象
    
    init(checklist: TravelChecklist, viewModel: LuggageViewModel) {
        self.checklist = checklist
        self.viewModel = viewModel
        _title = State(initialValue: checklist.title)
        _items = State(initialValue: checklist.items)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("清单标题")) {
                    TextField("请输入清单标题", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                Section(header: Text("清单项目")) {
                    ForEach(items.indices, id: \.self) { idx in
                        HStack {
                            TextField("项目", text: Binding(
                                get: { items[idx].name },
                                set: { items[idx].name = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            Button(role: .destructive) {
                                removeItem(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .onDelete(perform: deleteItem)
                    
                    Button("添加项目") {
                        items.append(TravelChecklistItem(name: ""))
                    }
                    
                    Button("添加物品") {
                        showingSelectItems = true
                    }
                }
            }
            .navigationTitle("编辑清单")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { updateChecklist() }
                        .disabled(title.isEmpty || items.allSatisfy { $0.name.isEmpty })
                }
            }
            .sheet(isPresented: $showingSelectItems) {
                SelectItemsForChecklistView(onItemsSelected: {
                    selectedNames in
                    for name in selectedNames {
                        items.append(TravelChecklistItem(name: name))
                    }
                })
            }
        }
    }
    
    /// 更新清单到viewModel
    private func updateChecklist() {
        let updatedItems = items.filter { !$0.name.isEmpty }
        var updatedChecklist = checklist
        updatedChecklist.title = title
        updatedChecklist.items = updatedItems
        viewModel.updateChecklist(updatedChecklist)
        dismiss()
    }
    
    /// 删除清单项目
    private func removeItem(at index: Int) {
        items.remove(at: index)
    }
    
    /// 删除清单项目 (用于ForEach的onDelete修饰符)
    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}
