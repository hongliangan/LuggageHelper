import SwiftUI

/// AI 物品信息卡片组件
/// 用于在多个地方显示物品信息
struct AIItemInfoCard: View {
    let item: ItemInfo
    var showActions: Bool = true
    var onUse: (() -> Void)? = nil
    var onViewAlternatives: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和图标
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(item.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(item.category.icon)
                    .font(.system(size: 36))
            }
            
            Divider()
            
            // 物品详细信息
            VStack(alignment: .leading, spacing: 8) {
                infoRow(title: "重量", value: "\(String(format: "%.2f", item.weight/1000)) kg")
                infoRow(title: "体积", value: "\(String(format: "%.2f", item.volume/1000)) L")
                
                if let dimensions = item.dimensions {
                    infoRow(title: "尺寸", value: dimensions.formatted)
                }
                
                infoRow(title: "置信度", value: "\(Int(item.confidence * 100))%")
                infoRow(title: "数据来源", value: item.source)
            }
            
            if showActions {
                Divider()
                
                // 操作按钮
                HStack(spacing: 16) {
                    if !item.alternatives.isEmpty && onViewAlternatives != nil {
                        Button {
                            onViewAlternatives?()
                        } label: {
                            Label("查看替代品", systemImage: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if let onUse = onUse {
                        Button {
                            onUse()
                        } label: {
                            Label("使用此结果", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

#if DEBUG
struct AIItemInfoCard_Previews: PreviewProvider {
    static var previews: some View {
        AIItemInfoCard(
            item: ItemInfo(
                name: "iPhone 15 Pro",
                category: .electronics,
                weight: 221,
                volume: 150,
                dimensions: Dimensions(length: 15, width: 7, height: 0.8),
                confidence: 0.95,
                source: "AI识别"
            ),
            onUse: {},
            onViewAlternatives: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif