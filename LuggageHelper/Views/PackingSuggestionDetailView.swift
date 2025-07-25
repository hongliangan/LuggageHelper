import SwiftUI

/// 装箱建议详情视图
/// 提供详细的装箱指导和可视化展示
struct PackingSuggestionDetailView: View {
    let packingPlan: PackingPlan
    let luggage: Luggage
    let items: [LuggageItem]
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPosition: PackingPosition?
    @State private var showingItemDetail: LuggageItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 3D 可视化行李箱
                luggageVisualizationSection
                
                // 分步装箱指导
                stepByStepGuideSection
                
                // 物品详细信息
                itemDetailsSection
                
                // 装箱技巧
                packingTipsSection
            }
            .padding()
        }
        .navigationTitle("装箱指导")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $showingItemDetail) { item in
            ItemPackingDetailSheet(item: item, packingItem: packingItemFor(item))
        }
    }
    
    // 行李箱可视化部分
    private var luggageVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行李箱布局")
                .font(.headline)
            
            // 简化的 3D 行李箱视图
            ZStack {
                // 行李箱轮廓
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(height: 200)
                
                // 分层显示
                VStack(spacing: 0) {
                    // 顶部区域
                    positionLayer(.top, height: 50)
                    
                    // 中部区域
                    positionLayer(.middle, height: 100)
                    
                    // 底部区域
                    positionLayer(.bottom, height: 50)
                }
                .padding(8)
                
                // 侧面和角落物品
                HStack {
                    positionSideView(.side)
                    Spacer()
                    positionSideView(.corner)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // 位置说明
            positionLegend
        }
    }
    
    // 位置图层
    private func positionLayer(_ position: PackingPosition, height: CGFloat) -> some View {
        let positionItems = packingPlan.items.filter { $0.position == position }
        
        return HStack {
            Text(position.displayName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(positionColor(position))
                .frame(width: 60, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(positionItems.prefix(8)) { packingItem in
                        if let item = items.first(where: { $0.id == packingItem.itemId }) {
                            Button(action: {
                                showingItemDetail = item
                            }) {
                                VStack(spacing: 2) {
                                    Text(item.category.icon)
                                        .font(.caption2)
                                    
                                    Text(item.name.prefix(4))
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(4)
                                .background(positionColor(position).opacity(0.3))
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    if positionItems.count > 8 {
                        Text("+\(positionItems.count - 8)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: height)
        .background(positionColor(position).opacity(0.1))
        .cornerRadius(8)
    }
    
    // 侧面视图
    private func positionSideView(_ position: PackingPosition) -> some View {
        let positionItems = packingPlan.items.filter { $0.position == position }
        
        return VStack(spacing: 4) {
            Text(position.displayName)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(positionColor(position))
            
            ForEach(positionItems.prefix(3)) { packingItem in
                if let item = items.first(where: { $0.id == packingItem.itemId }) {
                    Button(action: {
                        showingItemDetail = item
                    }) {
                        Text(item.category.icon)
                            .font(.caption)
                            .padding(2)
                            .background(positionColor(position).opacity(0.3))
                            .cornerRadius(2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if positionItems.count > 3 {
                Text("...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 40)
    }
    
    // 位置图例
    private var positionLegend: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(PackingPosition.allCases, id: \.self) { position in
                HStack(spacing: 4) {
                    Circle()
                        .fill(positionColor(position))
                        .frame(width: 8, height: 8)
                    
                    Text(position.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // 分步指导部分
    private var stepByStepGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装箱步骤")
                .font(.headline)
            
            let sortedItems = packingPlan.items.sorted { item1, item2 in
                let order1 = positionOrder(item1.position)
                let order2 = positionOrder(item2.position)
                if order1 != order2 {
                    return order1 < order2
                }
                return item1.priority > item2.priority
            }
            
            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, packingItem in
                if let item = items.first(where: { $0.id == packingItem.itemId }) {
                    packingStepRow(step: index + 1, item: item, packingItem: packingItem)
                }
            }
        }
    }
    
    // 装箱步骤行
    private func packingStepRow(step: Int, item: LuggageItem, packingItem: PackingItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 步骤编号
            Text("\(step)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(positionColor(packingItem.position))
                .clipShape(Circle())
            
            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.category.icon)
                    Text(item.name)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(packingItem.position.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(positionColor(packingItem.position).opacity(0.2))
                        .foregroundColor(positionColor(packingItem.position))
                        .cornerRadius(4)
                }
                
                Text(packingItem.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("重量: \(String(format: "%.0f", item.weight))g")
                    Text("体积: \(String(format: "%.0f", item.volume))cm³")
                    Text("优先级: \(packingItem.priority)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Button(action: {
                showingItemDetail = item
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 物品详细信息部分
    private var itemDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("物品分类")
                .font(.headline)
            
            let categoryGroups = Dictionary(grouping: packingPlan.items) { item in
                items.first(where: { $0.id == item.itemId })?.category ?? .other
            }
            
            ForEach(ItemCategory.allCases, id: \.self) { category in
                if let categoryItems = categoryGroups[category], !categoryItems.isEmpty {
                    categorySection(category: category, packingItems: categoryItems)
                }
            }
        }
    }
    
    // 类别部分
    private func categorySection(category: ItemCategory, packingItems: [PackingItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.icon)
                Text(category.displayName)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(packingItems.count)件")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(packingItems) { packingItem in
                    if let item = items.first(where: { $0.id == packingItem.itemId }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(packingItem.position.displayName)
                                    .font(.caption2)
                                    .foregroundColor(positionColor(packingItem.position))
                            }
                            
                            Spacer()
                            
                            Text("P\(packingItem.priority)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 装箱技巧部分
    private var packingTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装箱技巧")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                packingTip(
                    icon: "arrow.down",
                    title: "重物在下",
                    description: "将重物放在行李箱底部，保持重心稳定"
                )
                
                packingTip(
                    icon: "shield",
                    title: "易碎保护",
                    description: "用衣物包裹易碎品，放在行李箱中央"
                )
                
                packingTip(
                    icon: "cube",
                    title: "空间利用",
                    description: "利用鞋内空间，衣物卷起来节省空间"
                )
                
                packingTip(
                    icon: "hand.raised",
                    title: "常用在上",
                    description: "常用物品放在顶部，方便取用"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 装箱技巧项
    private func packingTip(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 辅助方法
    private func positionColor(_ position: PackingPosition) -> Color {
        switch position {
        case .bottom: return .brown
        case .middle: return .orange
        case .top: return .green
        case .side: return .blue
        case .corner: return .purple
        }
    }
    
    private func positionOrder(_ position: PackingPosition) -> Int {
        switch position {
        case .bottom: return 1
        case .middle: return 2
        case .side: return 3
        case .corner: return 4
        case .top: return 5
        }
    }
    
    private func packingItemFor(_ item: LuggageItem) -> PackingItem? {
        return packingPlan.items.first { $0.itemId == item.id }
    }
}

// 物品装箱详情表单
struct ItemPackingDetailSheet: View {
    let item: LuggageItem
    let packingItem: PackingItem?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 物品基本信息
                    itemInfoSection
                    
                    // 装箱建议
                    if let packingItem = packingItem {
                        packingSuggestionSection(packingItem)
                    }
                    
                    // 注意事项
                    precautionsSection
                }
                .padding()
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var itemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("物品信息")
                .font(.headline)
            
            VStack(spacing: 8) {
                infoRow(title: "类别", value: "\(item.category.icon) \(item.category.displayName)")
                infoRow(title: "重量", value: "\(String(format: "%.0f", item.weight))g")
                infoRow(title: "体积", value: "\(String(format: "%.0f", item.volume))cm³")
                
                if let location = item.location {
                    infoRow(title: "位置", value: location)
                }
                
                if let note = item.note {
                    infoRow(title: "备注", value: note)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func packingSuggestionSection(_ packingItem: PackingItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装箱建议")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("建议位置:")
                        .fontWeight(.medium)
                    
                    Text(packingItem.position.displayName)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(positionColor(packingItem.position).opacity(0.2))
                        .foregroundColor(positionColor(packingItem.position))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text("优先级:")
                        .fontWeight(.medium)
                    
                    Text("\(packingItem.priority)/10")
                        .fontWeight(.bold)
                        .foregroundColor(priorityColor(packingItem.priority))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议原因:")
                        .fontWeight(.medium)
                    
                    Text(packingItem.reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var precautionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("注意事项")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                precautionItem(
                    icon: "exclamationmark.triangle",
                    text: "请确保物品包装完好，避免在运输过程中损坏",
                    color: .orange
                )
                
                if item.category == .electronics {
                    precautionItem(
                        icon: "battery.100",
                        text: "电子产品请检查电池规定，锂电池需随身携带",
                        color: .red
                    )
                }
                
                if item.category == .toiletries || item.category == .beauty {
                    precautionItem(
                        icon: "drop",
                        text: "液体物品请确保密封，符合航空限制（≤100ml）",
                        color: .blue
                    )
                }
                
                precautionItem(
                    icon: "checkmark.shield",
                    text: "贵重物品建议随身携带，不要放在托运行李中",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func precautionItem(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func positionColor(_ position: PackingPosition) -> Color {
        switch position {
        case .bottom: return .brown
        case .middle: return .orange
        case .top: return .green
        case .side: return .blue
        case .corner: return .purple
        }
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        if priority >= 8 {
            return .red
        } else if priority >= 6 {
            return .orange
        } else if priority >= 4 {
            return .blue
        } else {
            return .gray
        }
    }
}

// 扩展 PackingPosition 以支持 allCases
extension PackingPosition: CaseIterable {
    public static var allCases: [PackingPosition] {
        return [.bottom, .middle, .top, .side, .corner]
    }
}

struct PackingSuggestionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PackingSuggestionDetailView(
                packingPlan: PackingPlan(
                    luggageId: UUID(),
                    items: [],
                    totalWeight: 5000,
                    totalVolume: 25000,
                    efficiency: 0.75,
                    warnings: [],
                    suggestions: []
                ),
                luggage: Luggage(name: "示例行李箱", capacity: 50000, emptyWeight: 3.5),
                items: []
            )
        }
    }
}