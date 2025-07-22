import SwiftUI

/// 出行清单详情页面
/// 展示清单项目，支持勾选和备注
struct ChecklistDetailView: View {
    @Environment(\.dismiss) var dismiss
    let checklist: TravelChecklist
    let viewModel: LuggageViewModel
    
    var body: some View {
        List {
            Section(header: Text("清单项目")) {
                ForEach(checklist.items) { item in
                    HStack {
                        Button(action: {
                            viewModel.toggleChecklistItem(item.id, in: checklist.id)
                        }) {
                            Image(systemName: item.checked ? "checkmark.square" : "square")
                                .foregroundColor(item.checked ? .green : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .strikethrough(item.checked)
                                .foregroundColor(item.checked ? .secondary : .primary)
                            
                            if let note = item.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            
            Section(header: Text("进度")) {
                HStack {
                    Text("已完成")
                    Spacer()
                    Text("\(checklist.completedCount) / \(checklist.items.count)")
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: checklist.progress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .navigationTitle(checklist.title)
        .navigationBarTitleDisplayMode(.inline)
    }
} 