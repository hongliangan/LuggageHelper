import SwiftUI

/// 出行清单页面
/// 管理出行准备清单，支持勾选已完成项目
struct TravelChecklistView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @State private var showingAddChecklist = false
    @State private var checklistToEdit: TravelChecklist? // 声明 checklistToEdit 变量
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.checklists) { checklist in
                    NavigationLink {
                        ChecklistDetailView(checklist: checklist, viewModel: viewModel)
                    } label: {
                        ChecklistRowView(checklist: checklist)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.removeChecklist(checklist)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            checklistToEdit = checklist
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("出行清单")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddChecklist = true
                        } label: {
                            Label("添加清单", systemImage: "plus")
                        }
                        
                        NavigationLink(destination: AITravelPlannerView()) {
                            Label("AI 旅行规划", systemImage: "wand.and.stars")
                        }
                        
                        NavigationLink(destination: PersonalizedTravelPlannerView()) {
                            Label("个性化旅行规划", systemImage: "person.fill.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            })
            .sheet(isPresented: $showingAddChecklist) {
                AddChecklistView(viewModel: viewModel)
            }
            .sheet(item: $checklistToEdit) { checklist in
                EditChecklistView(checklist: checklist, viewModel: viewModel)
            }
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
                .foregroundColor(checklist.isAllChecked ? .green : .red)
            
            ProgressView(value: checklist.progress)
                .progressViewStyle(LinearProgressViewStyle())
        }
    }
}
