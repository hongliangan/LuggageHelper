import SwiftUI

/// 替换建议详细视图
struct ReplacementSuggestionDetailView: View {
    let suggestion: ItemReplacementService.ReplacementSuggestion
    
    @State private var selectedAlternativeIndex = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 原物品信息
                    originalItemSection
                    
                    // 约束条件
                    constraintsSection
                    
                    // 替代品详情
                    alternativesSection
                    
                    // 建议理由
                    reasonSection
                    
                    // 时间和优先级信息
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("替换建议详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("接受建议") {
                            // 处理接受逻辑
                            dismiss()
                        }
                        
                        Button("拒绝建议", role: .destructive) {
                            // 处理拒绝逻辑
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var originalItemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("原物品")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Text(suggestion.originalItem.category.icon)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.originalItem.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(suggestion.originalItem.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Label(formatWeight(suggestion.originalItem.weight), systemImage: "scalemass")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Label(formatVolume(suggestion.originalItem.volume), systemImage: "cube")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if suggestion.originalItem.quantity > 1 {
                            Label("×\(suggestion.originalItem.quantity)", systemImage: "number")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("约束条件")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                if let maxWeight = suggestion.constraints.maxWeight {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.blue)
                        Text("最大重量：\(formatWeight(maxWeight))")
                        Spacer()
                    }
                }
                
                if let maxVolume = suggestion.constraints.maxVolume {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.green)
                        Text("最大体积：\(formatVolume(maxVolume))")
                        Spacer()
                    }
                }
                
                if let maxBudget = suggestion.constraints.maxBudget {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.orange)
                        Text("预算上限：¥\(String(format: "%.0f", maxBudget))")
                        Spacer()
                    }
                }
                
                if let requiredFeatures = suggestion.constraints.requiredFeatures, !requiredFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("必需功能：")
                            Spacer()
                        }
                        
                        ForEach(requiredFeatures, id: \.self) { feature in
                            Text("• \(feature)")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                }
                
                if let excludedBrands = suggestion.constraints.excludedBrands, !excludedBrands.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("排除品牌：")
                            Spacer()
                        }
                        
                        Text(excludedBrands.joined(separator: "、"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                
                if let preferredBrands = suggestion.constraints.preferredBrands, !preferredBrands.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                            Text("偏好品牌：")
                            Spacer()
                        }
                        
                        Text(preferredBrands.joined(separator: "、"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("替代品选择 (\(suggestion.alternatives.count)个)")
                .font(.headline)
                .fontWeight(.semibold)
            
            if suggestion.alternatives.count > 1 {
                Picker("替代品", selection: $selectedAlternativeIndex) {
                    ForEach(suggestion.alternatives.indices, id: \.self) { index in
                        Text(suggestion.alternatives[index].name).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 选中替代品的详细信息
            let selectedAlternative = suggestion.alternatives[selectedAlternativeIndex]
            AlternativeDetailCard(
                alternative: selectedAlternative,
                originalItem: suggestion.originalItem,
                constraints: suggestion.constraints
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("建议理由")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(suggestion.reason)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(12)
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                HStack {
                    Text("优先级：")
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.priority.displayName)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(suggestion.priority.color.opacity(0.2))
                        .foregroundColor(suggestion.priority.color)
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                HStack {
                    Text("创建时间：")
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.createdAt, style: .date)
                    Text(suggestion.createdAt, style: .time)
                    
                    Spacer()
                }
                
                HStack {
                    Text("状态：")
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.status.displayName)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 格式化方法
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
    
    private func formatVolume(_ cm3: Double) -> String {
        if cm3 >= 1000 {
            return String(format: "%.1fL", cm3 / 1000.0)
        } else {
            return String(format: "%.0fcm³", cm3)
        }
    }
}

// MARK: - 替代品详细卡片

struct AlternativeDetailCard: View {
    let alternative: ItemInfo
    let originalItem: LuggageItem
    let constraints: AlternativeConstraints
    
    private var weightChange: Double {
        alternative.weight - originalItem.weight
    }
    
    private var volumeChange: Double {
        alternative.volume - originalItem.volume
    }
    
    private var meetsWeightConstraint: Bool {
        guard let maxWeight = constraints.maxWeight else { return true }
        return alternative.weight <= maxWeight
    }
    
    private var meetsVolumeConstraint: Bool {
        guard let maxVolume = constraints.maxVolume else { return true }
        return alternative.volume <= maxVolume
    }
    
    private var meetsConstraints: Bool {
        meetsWeightConstraint && meetsVolumeConstraint
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 替代品基本信息
            HStack(spacing: 12) {
                Text(alternative.category.icon)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(alternative.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(alternative.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Label(formatWeight(alternative.weight), systemImage: "scalemass")
                            .font(.body)
                            .foregroundColor(meetsWeightConstraint ? .secondary : .red)
                        
                        Label(formatVolume(alternative.volume), systemImage: "cube")
                            .font(.body)
                            .foregroundColor(meetsVolumeConstraint ? .secondary : .red)
                    }
                }
                
                Spacer()
                
                // 约束符合状态
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: meetsConstraints ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(meetsConstraints ? .green : .red)
                        .font(.title2)
                    
                    Text(meetsConstraints ? "符合约束" : "超出限制")
                        .font(.caption)
                        .foregroundColor(meetsConstraints ? .green : .red)
                }
            }
            
            // 对比信息
            comparisonSection
            
            // 尺寸信息
            if let dimensions = alternative.dimensions {
                dimensionsSection(dimensions)
            }
            
            // 置信度和来源
            confidenceSection
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(meetsConstraints ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var comparisonSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("与原物品对比")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack(spacing: 30) {
                // 重量对比
                VStack(alignment: .leading, spacing: 6) {
                    Text("重量变化")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: weightChange > 0 ? "arrow.up" : weightChange < 0 ? "arrow.down" : "minus")
                            .foregroundColor(weightChange > 0 ? .red : weightChange < 0 ? .green : .gray)
                            .font(.body)
                        
                        Text(formatWeight(abs(weightChange)))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(weightChange > 0 ? .red : weightChange < 0 ? .green : .gray)
                    }
                    
                    if weightChange != 0 {
                        let percentage = abs(weightChange) / originalItem.weight * 100
                        Text(String(format: "%.1f%%", percentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 体积对比
                VStack(alignment: .leading, spacing: 6) {
                    Text("体积变化")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: volumeChange > 0 ? "arrow.up" : volumeChange < 0 ? "arrow.down" : "minus")
                            .foregroundColor(volumeChange > 0 ? .red : volumeChange < 0 ? .green : .gray)
                            .font(.body)
                        
                        Text(formatVolume(abs(volumeChange)))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(volumeChange > 0 ? .red : volumeChange < 0 ? .green : .gray)
                    }
                    
                    if volumeChange != 0 {
                        let percentage = abs(volumeChange) / originalItem.volume * 100
                        Text(String(format: "%.1f%%", percentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func dimensionsSection(_ dimensions: Dimensions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("尺寸信息")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("长度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fcm", dimensions.length))
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("宽度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fcm", dimensions.width))
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("高度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fcm", dimensions.height))
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI评估")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                // 置信度
                VStack(alignment: .leading, spacing: 4) {
                    Text("推荐度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(index < Int(alternative.confidence * 5) ? .yellow : .gray.opacity(0.3))
                                .font(.body)
                        }
                        
                        Text(String(format: "%.1f", alternative.confidence))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                
                Spacer()
                
                // 来源
                VStack(alignment: .trailing, spacing: 4) {
                    Text("数据来源")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(alternative.source ?? "AI识别")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - 格式化方法
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
    
    private func formatVolume(_ cm3: Double) -> String {
        if cm3 >= 1000 {
            return String(format: "%.1fL", cm3 / 1000.0)
        } else {
            return String(format: "%.0fcm³", cm3)
        }
    }
}

// MARK: - 预览

struct ReplacementSuggestionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ReplacementSuggestionDetailView(
            suggestion: ItemReplacementService.ReplacementSuggestion(
                originalItem: LuggageItem(
                    name: "厚重毛衣",
                    volume: 1200,
                    weight: 800,
                    category: .clothing,
                    imagePath: nil,
                    location: nil,
                    note: nil
                ),
                alternatives: [
                    ItemInfo(
                        name: "轻薄羊毛衫",
                        category: .clothing,
                        weight: 300,
                        volume: 600,
                        confidence: 0.9,
                        source: "AI推荐"
                    )
                ],
                constraints: AlternativeConstraints(
                    maxWeight: 500,
                    maxVolume: 800,
                    requiredFeatures: ["保暖", "轻便"]
                ),
                reason: "根据您的约束条件，推荐更轻便的替代品",
                priority: .high,
                createdAt: Date(),
                status: .pending
            )
        )
    }
}