import SwiftUI

/// 物品单行展示组件
/// 用于在列表中展示单个物品的基本信息
struct ItemRowView: View {
    let item: LuggageItem
    let compact: Bool
    
    init(item: LuggageItem, compact: Bool = false) {
        self.item = item
        self.compact = compact
    }
    
    var body: some View {
        HStack {
            if let imagePath = item.imagePath,
               let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: compact ? 30 : 40, height: compact ? 30 : 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "cube.box")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 30 : 40, height: compact ? 30 : 40)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(compact ? .caption : .body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("重量: \(item.weight, specifier: "%.1f")kg")
                        .font(compact ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                    
                    Text("体积: \(item.volume, specifier: "%.1f")L")
                        .font(compact ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                }
                
                if let location = item.location, !location.isEmpty {
                    Text("位置: \(location)")
                        .font(compact ? .caption2 : .caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, compact ? 4 : 8)
    }
}