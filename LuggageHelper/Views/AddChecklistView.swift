import SwiftUI

/// 添加新出行清单页面
/// 允许用户输入清单标题和项目，保存到viewModel
struct AddChecklistView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: LuggageViewModel
    @State private var title: String = ""
    @State private var items: [String] = [""]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("清单标题")) {
                    TextField("请输入清单标题", text: $title)
                }
                Section(header: Text("清单项目")) {
                    ForEach(items.indices, id: \ .self) { idx in
                        TextField("项目", text: Binding(
                            get: { items[idx] },
                            set: { items[idx] = $0 }
                        ))
                    }
                    Button("添加项目") {
                        items.append("")
                    }
                }
            }
            .navigationTitle("新建清单")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveChecklist() }
                        .disabled(title.isEmpty || items.allSatisfy { $0.isEmpty })
                }
            }
        }
    }
    /// 保存新清单到viewModel
    private func saveChecklist() {
        let checklistItems = items.filter { !$0.isEmpty }.map { name in
            TravelChecklistItem(name: name)
        }
        let checklist = TravelChecklist(title: title, items: checklistItems)
        viewModel.addChecklist(checklist)
        dismiss()
    }
} 