import SwiftUI

/// AI 识别按钮组件
/// 提供统一的 AI 识别入口按钮
struct AIIdentificationButton: View {
    enum IdentificationType {
        case name
        case photo
        case batch
        case advanced
    }
    
    let type: IdentificationType
    let action: () -> Void
    var compact: Bool = false
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                icon
                    .font(compact ? .body : .title3)
                    .foregroundColor(.blue)
                
                if !compact {
                    Text(title)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(compact ? 8 : 12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(compact ? 8 : 12)
        }
        .buttonStyle(.plain)
    }
    
    private var icon: Image {
        switch type {
        case .name:
            return Image(systemName: "text.magnifyingglass")
        case .photo:
            return Image(systemName: "camera.viewfinder")
        case .batch:
            return Image(systemName: "rectangle.stack.badge.play")
        case .advanced:
            return Image(systemName: "sparkles.rectangle.stack")
        }
    }
    
    private var title: String {
        switch type {
        case .name:
            return "通过名称识别"
        case .photo:
            return "通过照片识别"
        case .batch:
            return "批量识别多个物品"
        case .advanced:
            return "高级 AI 识别"
        }
    }
}

/// AI 识别按钮组
/// 提供多个 AI 识别按钮的组合
struct AIIdentificationButtonGroup: View {
    let onNameIdentification: () -> Void
    let onPhotoIdentification: () -> Void
    let onBatchIdentification: () -> Void
    let onAdvancedIdentification: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            AIIdentificationButton(type: .name, action: onNameIdentification)
            AIIdentificationButton(type: .photo, action: onPhotoIdentification)
            AIIdentificationButton(type: .batch, action: onBatchIdentification)
            AIIdentificationButton(type: .advanced, action: onAdvancedIdentification)
        }
    }
}

/// AI 识别快捷按钮组
/// 提供紧凑型的 AI 识别按钮组合
struct AIIdentificationQuickButtons: View {
    let onNameIdentification: () -> Void
    let onPhotoIdentification: () -> Void
    let onBatchIdentification: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AIIdentificationButton(type: .name, action: onNameIdentification, compact: true)
            AIIdentificationButton(type: .photo, action: onPhotoIdentification, compact: true)
            AIIdentificationButton(type: .batch, action: onBatchIdentification, compact: true)
        }
    }
}

#if DEBUG
struct AIIdentificationButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AIIdentificationButton(type: .name, action: {})
            AIIdentificationButton(type: .photo, action: {})
            AIIdentificationButton(type: .batch, action: {})
            AIIdentificationButton(type: .advanced, action: {})
            
            Divider()
            
            HStack {
                AIIdentificationButton(type: .name, action: {}, compact: true)
                AIIdentificationButton(type: .photo, action: {}, compact: true)
                AIIdentificationButton(type: .batch, action: {}, compact: true)
            }
            
            Divider()
            
            AIIdentificationButtonGroup(
                onNameIdentification: {},
                onPhotoIdentification: {},
                onBatchIdentification: {},
                onAdvancedIdentification: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif