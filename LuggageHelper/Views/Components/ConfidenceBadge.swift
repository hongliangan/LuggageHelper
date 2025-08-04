import SwiftUI

/// 置信度徽章组件
/// 用于显示AI识别结果的置信度
struct ConfidenceBadge: View {
    let confidence: Double
    let style: Style
    
    enum Style {
        case detailed  // 带圆点指示器的详细版本
        case compact   // 简洁版本
    }
    
    init(confidence: Double, style: Style = .detailed) {
        self.confidence = confidence
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .detailed:
            detailedView
        case .compact:
            compactView
        }
    }
    
    private var detailedView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var compactView: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(confidenceColor.opacity(0.15))
            .foregroundColor(confidenceColor)
            .cornerRadius(6)
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
}

#if DEBUG
struct ConfidenceBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ConfidenceBadge(confidence: 0.95, style: .detailed)
            ConfidenceBadge(confidence: 0.75, style: .detailed)
            ConfidenceBadge(confidence: 0.45, style: .detailed)
            
            Divider()
            
            ConfidenceBadge(confidence: 0.95, style: .compact)
            ConfidenceBadge(confidence: 0.75, style: .compact)
            ConfidenceBadge(confidence: 0.45, style: .compact)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif