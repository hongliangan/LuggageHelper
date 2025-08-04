import SwiftUI

/// 批量识别结果物品卡片
/// 显示单个识别结果的详细信息
struct BatchRecognitionItemCard: View {
    let recognition: ObjectRecognitionResult
    let onUse: (ItemInfo) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 物品缩略图
            if let thumbnail = recognition.detectedObject.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // 识别信息
            VStack(alignment: .leading, spacing: 4) {
                Text(recognition.recognizedItem.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(recognition.recognizedItem.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    // 置信度指示器
                    confidenceIndicator
                    
                    Spacer()
                    
                    // 物品详细信息
                    VStack(alignment: .trailing, spacing: 2) {
                        if recognition.recognizedItem.weight > 0 {
                            Text("\(String(format: "%.0f", recognition.recognizedItem.weight))g")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if recognition.recognizedItem.volume > 0 {
                            Text("\(String(format: "%.0f", recognition.recognizedItem.volume))ml")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 使用按钮
            Button("使用") {
                onUse(recognition.recognizedItem)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    /// 置信度指示器
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(String(format: "%.0f", recognition.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(confidenceColor)
        }
    }
    
    /// 根据置信度返回颜色
    private var confidenceColor: Color {
        if recognition.confidence >= 0.8 {
            return .green
        } else if recognition.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

#if DEBUG
struct BatchRecognitionItemCard_Previews: PreviewProvider {
    static var previews: some View {
        let mockDetectedObject = DetectedObject(
            boundingBox: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
            confidence: 0.85,
            category: .other,
            thumbnail: UIImage(systemName: "photo")
        )
        
        let mockItemInfo = ItemInfo(
            name: "蓝牙耳机",
            category: .electronics,
            weight: 50.0,
            volume: 100.0,
            confidence: 0.85
        )
        
        let mockRecognition = ObjectRecognitionResult(
            detectedObject: mockDetectedObject,
            recognizedItem: mockItemInfo,
            confidence: 0.85,
            processingTime: 1.2
        )
        
        BatchRecognitionItemCard(
            recognition: mockRecognition,
            onUse: { _ in }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif