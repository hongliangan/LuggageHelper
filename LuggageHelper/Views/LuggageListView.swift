import SwiftUI

/// 行李列表主页面
/// 展示所有已创建的行李箱/包，支持新增、编辑、删除操作
struct LuggageListView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @State private var showingAddLuggage = false
    @State private var luggageToEdit: Luggage?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.luggages) { luggage in
                    NavigationLink {
                        LuggageDetailView(luggage: luggage)
                    } label: {
                        LuggageRowView(luggage: luggage)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.removeLuggage(luggage)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            luggageToEdit = luggage
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("我的行李")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddLuggage = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            })
            .sheet(isPresented: $showingAddLuggage) {
                AddLuggageView()
            }
            .sheet(item: $luggageToEdit) { luggage in
                EditLuggageView(luggage: luggage)
            }
        }
    }
}

/// 行李单行展示组件
/// 在列表中简洁展示行李关键信息
struct LuggageRowView: View {
    let luggage: Luggage
    
    var body: some View {
        HStack {
            if let imagePath = luggage.imagePath,
               let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "suitcase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text(luggage.name)
                    .font(.headline)
                Text("容量: \(luggage.usedCapacity, specifier: "%.1f") / \(luggage.capacity, specifier: "%.1f") L")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("重量: \(luggage.totalWeight, specifier: "%.1f") kg")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}