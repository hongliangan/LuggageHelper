import SwiftUI

/// 行李列表主页面
/// 展示所有已创建的行李箱/包，支持新增、编辑、删除操作
struct LuggageListView: View {
    @ObservedObject var viewModel: LuggageViewModel
    @State private var showingAddLuggage = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.luggages) { luggage in
                    NavigationLink {
                        LuggageDetailView(luggage: luggage, viewModel: viewModel)
                    } label: {
                        LuggageRowView(luggage: luggage)
                    }
                }
                .onDelete(perform: deleteLuggage)
            }
            .navigationTitle("我的行李")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddLuggage = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLuggage) {
                AddLuggageView(viewModel: viewModel)
            }
        }
    }
    
    /// 删除指定索引的行李
    /// - Parameter offsets: 要删除的行李索引集合
    private func deleteLuggage(offsets: IndexSet) {
        for index in offsets {
            viewModel.removeLuggage(viewModel.luggages[index])
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