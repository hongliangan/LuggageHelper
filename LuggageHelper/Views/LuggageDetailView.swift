import SwiftUI

/// 行李详情页面
/// 展示单个行李的详细信息、内部物品列表，并提供添加物品入口
struct LuggageDetailView: View {
    let luggage: Luggage
    @EnvironmentObject var viewModel: LuggageViewModel
    @State private var showingAddItem = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 行李信息卡片
                luggageInfoCard
                
                // 物品列表
                itemsSection
            }
            .padding()
        }
        .navigationTitle(luggage.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(luggage: luggage)
        }
    }
    
    /// 行李信息展示卡片
    private var luggageInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let imagePath = luggage.imagePath,
                   let uiImage = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "suitcase")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(luggage.name)
                        .font(.title2.bold())
                    
                    Text("容量: \(luggage.capacity)L")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("空箱重量: \(luggage.emptyWeight)kg")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("类型: \(luggage.luggageType.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("已用容量: \(luggage.usedCapacity, specifier: "%.1f")L")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Text("总重量: \(luggage.totalWeight, specifier: "%.1f")kg")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        if let warning = viewModel.getOverweightWarning(for: luggage) {
                            Text("⚠️ \(warning)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let note = luggage.note, !note.isEmpty {
                        Text("备注: \(note)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// 物品列表区域
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("包含物品")
                .font(.headline)
                .padding(.horizontal)
            
            if luggage.items.isEmpty {
                Text("暂无物品")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(luggage.items) { item in
                    ItemRowView(item: item, compact: true)
                }
            }
        }
    }
}

#if DEBUG
struct LuggageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockLuggage = Luggage(
            name: "示例箱子",
            capacity: 30,
            emptyWeight: 2.5,
            imagePath: nil,
            items: [],
            note: "测试用备注"
        )
        LuggageDetailView(luggage: mockLuggage)
            .environmentObject(LuggageViewModel())
    }
}
#endif