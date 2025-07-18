import SwiftUI

/// 出行清单详情页面
/// 展示清单项目，支持勾选和备注
struct ChecklistDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State var checklist: TravelChecklist
    @ObservedObject var viewModel: LuggageViewModel
    
    var body: some View {
        List {
            Section(header: Text("清单项目")) {
                ForEach(checklist.items.indices, id: \ .self) { idx in
                    HStack {
                        Button(action: {
                            toggleItem(idx)
                        }) {
                            Image(systemName: checklist.items[idx].checked ? "checkmark.square" : "square")
                        }
                        Text(checklist.items[idx].name)
                        Spacer()
                        if let note = checklist.items[idx].note, !note.isEmpty {
                            Image(systemName: "note.text")
                        }
                    }
                }
            }
        }
        .navigationTitle(checklist.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") { dismiss() }
            }
        }
    }
    /// 切换项目勾选状态
    private func toggleItem(_ idx: Int) {
        checklist.items[idx].checked.toggle()
        // 这里可以根据需要同步到viewModel
    }
} 