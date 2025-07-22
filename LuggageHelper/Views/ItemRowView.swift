import SwiftUI

/// 物品单行展示组件
/// 用于在列表中展示单个物品的基本信息
struct ItemRowView: View {
    let item: LuggageItem
    let compact: Bool
    @EnvironmentObject var viewModel: LuggageViewModel
    @State private var itemToEdit: LuggageItem? // 用于控���编辑视图的显示
    
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
                
                // 显示位置和状态信息
                if !compact {
                    locationAndStatusView
                }
            }
            
            Spacer()
        }
        .padding(.vertical, compact ? 4 : 8)
        .contextMenu {
            itemContextMenu
        }
        .sheet(item: $itemToEdit) { itemToEdit in
            // 传递物品所属的行李ID，如果是独立物品则为nil
            EditItemView(item: itemToEdit, luggageId: (viewModel.getItemStatus(for: itemToEdit).isStandalone) ? nil : viewModel.getItemStatus(for: itemToEdit).luggage?.id)
        }
    }
    
    /// 位置和状态信息视图
    private var locationAndStatusView: some View {
        let status = viewModel.getItemStatus(for: item)
        
        return VStack(alignment: .leading, spacing: 4) {
            // 组合显示用户位置和物品状态
            HStack(spacing: 8) {
                // 用户设置的位置（如果有）
                if let userLocation = status.userLocation, !userLocation.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "location")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(userLocation)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // 物品状态标记
                statusBadge(for: status)
                
                Spacer()
            }
            
            // 如果有备注，显示备注
            if let note = item.note, !note.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    /// 状态标记视图
    private func statusBadge(for status: ItemStatus) -> some View {
        let (icon, text, color, backgroundColor) = statusInfo(for: status)
        
        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    /// 获取状态信息
    private func statusInfo(for status: ItemStatus) -> (icon: String, text: String, color: Color, backgroundColor: Color) {
        switch status {
        case .standalone:
            return ("house.fill", "独立存放", .orange, Color.orange.opacity(0.15))
        case .inLuggage(let luggage, _):
            let luggageIcon = luggage.luggageType == .carryOn ? "bag.fill" : "suitcase.fill"
            return (luggageIcon, luggage.name, .green, Color.green.opacity(0.15))
        }
    }
    
    /// 物品操作菜单
    private var itemContextMenu: some View {
        let status = viewModel.getItemStatus(for: item)
        
        return Group {
            Button(action: {
                itemToEdit = item // 设置要编辑的物品
            }) {
                Label("编辑物品", systemImage: "pencil")
            }
            
            switch status {
            case .standalone:
                // 独立物品菜单
                if !viewModel.luggages.isEmpty {
                    Menu("移动到行李") {
                        ForEach(viewModel.luggages) { luggage in
                            Button(action: {
                                viewModel.moveItemToLuggage(item, to: luggage.id)
                            }) {
                                Label(luggage.name, systemImage: luggage.luggageType == .carryOn ? "bag" : "suitcase")
                            }
                        }
                    }
                }
                
                Button(role: .destructive, action: {
                    viewModel.removeStandaloneItem(item)
                }) {
                    Label("删除物品", systemImage: "trash")
                }
                
            case .inLuggage(let luggage, _):
                // 行李中物品菜单
                Button(action: {
                    viewModel.moveItemFromLuggage(item, from: luggage.id)
                }) {
                    Label("移出行李", systemImage: "tray.and.arrow.up")
                }
                
                Button(role: .destructive, action: {
                    viewModel.removeItem(item.id, from: luggage.id)
                }) {
                    Label("删除物品", systemImage: "trash")
                }
            }
        }
    }
}