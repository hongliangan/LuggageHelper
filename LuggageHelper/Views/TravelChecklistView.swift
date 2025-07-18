import SwiftUI

/// 出行清单页面
/// 管理出行准备清单，支持勾选已完成项目
struct TravelChecklistView: View {
    @ObservedObject var viewModel: LuggageViewModel
    @State private var showingAddChecklist = false
    @State private var selectedChecklist: TravelChecklist?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.checklists) { checklist in
                    NavigationLink {
                        ChecklistDetailView(checklist: checklist, viewModel: viewModel)
                    } label: {
                        ChecklistRowView(checklist: checklist)
                    }
                }
                .onDelete(perform: deleteChecklist)
            }
            .navigationTitle("出行清单")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddChecklist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddChecklist) {
                AddChecklistView(viewModel: viewModel)
            }
        }
    }
    
    /// 删除指定索引的清单
    private func deleteChecklist(offsets: IndexSet) {
        for index in offsets {
            viewModel.removeChecklist(viewModel.checklists[index])
        }
    }
}

/// 清单单行展示组件
struct ChecklistRowView: View {
    let checklist: TravelChecklist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(checklist.title)
                .font(.headline)
            Text("共 \(checklist.items.count) 项，已完成 \(checklist.completedCount) 项")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: checklist.progress)
                .progressViewStyle(LinearProgressViewStyle())
        }
    }
}