import SwiftUI
import Charts

/// 重量预测视图
struct WeightPredictionView: View {
    @StateObject private var llmService = LLMAPIService.shared
    @StateObject private var configManager = LLMConfigurationManager.shared
    
    let items: [LuggageItem]
    let luggage: Luggage?
    
    @State private var weightPrediction: WeightPrediction?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingOptimizationTips = false
    
    private var totalWeight: Double {
        items.reduce(0) { $0 + $1.weight }
    }
    
    private var weightWithLuggage: Double {
        totalWeight + (luggage?.emptyWeight ?? 0) * 1000
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 当前重量概览
                    currentWeightOverview
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let prediction = weightPrediction {
                        predictionContent(prediction)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("重量预测")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        predictWeight()
                    }
                    .disabled(isLoading || !configManager.isConfigValid)
                }
            }
            .onAppear {
                if weightPrediction == nil {
                    predictWeight()
                }
            }
            .sheet(isPresented: $showingOptimizationTips) {
                WeightOptimizationTipsView(
                    prediction: weightPrediction,
                    items: items
                )
            }
        }
    }
    
    // MARK: - 子视图
    
    private var currentWeightOverview: some View {
        VStack(spacing: 16) {
            // 主要重量显示
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前总重量")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatWeight(weightWithLuggage))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(weightColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("物品数量")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(items.count)件")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            // 重量分解
            HStack(spacing: 20) {
                WeightInfoItem(
                    title: "物品重量",
                    weight: totalWeight,
                    color: .blue
                )
                
                if let luggage = luggage {
                    WeightInfoItem(
                        title: "箱子重量",
                        weight: luggage.emptyWeight * 1000,
                        color: .gray
                    )
                }
            }
            
            // 重量状态指示器
            weightStatusIndicator
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var weightStatusIndicator: some View {
        HStack {
            Circle()
                .fill(weightColor)
                .frame(width: 8, height: 8)
            
            Text(weightStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if weightWithLuggage > 23000 {
                Button("查看减重建议") {
                    showingOptimizationTips = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在分析重量分布...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("获取AI重量分析")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("AI将分析您的物品重量分布并提供优化建议")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("开始分析") {
                predictWeight()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("分析失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                predictWeight()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func predictionContent(_ prediction: WeightPrediction) -> some View {
        VStack(spacing: 20) {
            // 类别重量分布图表
            categoryWeightChart(prediction)
            
            // 警告信息
            if !prediction.warnings.isEmpty {
                warningsSection(prediction.warnings)
            }
            
            // 优化建议
            if !prediction.suggestions.isEmpty {
                suggestionsSection(prediction.suggestions)
            }
            
            // 置信度信息
            confidenceSection(prediction.confidence)
        }
    }
    
    private func categoryWeightChart(_ prediction: WeightPrediction) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重量分布")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(prediction.breakdown, id: \.category) { item in
                    BarMark(
                        x: .value("重量", item.weight),
                        y: .value("类别", item.category.displayName)
                    )
                    .foregroundStyle(item.category.color)
                }
                .frame(height: 200)
            } else {
                // iOS 16以下的替代实现
                VStack(spacing: 8) {
                    ForEach(prediction.breakdown, id: \.category) { item in
                        CategoryWeightBar(
                            category: item.category,
                            weight: item.weight,
                            percentage: item.percentage,
                            totalWeight: prediction.totalWeight
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func warningsSection(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("重量警告")
                    .font(.headline)
            }
            
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(warning)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemOrange).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func suggestionsSection(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)
                Text("优化建议")
                    .font(.headline)
            }
            
            ForEach(suggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(suggestion)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Button("查看详细优化方案") {
                showingOptimizationTips = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func confidenceSection(_ confidence: Double) -> some View {
        HStack {
            Text("预测准确度")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Image(systemName: "star.fill")
                        .foregroundColor(index < Int(confidence * 5) ? .yellow : .gray.opacity(0.3))
                        .font(.caption)
                }
                
                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - 计算属性
    
    private var weightColor: Color {
        if weightWithLuggage > 25000 {
            return .red
        } else if weightWithLuggage > 23000 {
            return .orange
        } else if weightWithLuggage > 20000 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var weightStatusText: String {
        if weightWithLuggage > 25000 {
            return "严重超重"
        } else if weightWithLuggage > 23000 {
            return "超重"
        } else if weightWithLuggage > 20000 {
            return "接近限重"
        } else {
            return "重量正常"
        }
    }
    
    // MARK: - 方法
    
    private func predictWeight() {
        guard configManager.isConfigValid else {
            errorMessage = "请先配置LLM API"
            return
        }
        
        guard !items.isEmpty else {
            errorMessage = "没有物品需要分析"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let prediction = try await llmService.predictWeight(items: items)
                
                await MainActor.run {
                    self.weightPrediction = prediction
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
}

// MARK: - 支持视图

/// 重量信息项
struct WeightInfoItem: View {
    let title: String
    let weight: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatWeight(weight))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
}

/// 类别重量条形图
struct CategoryWeightBar: View {
    let category: ItemCategory
    let weight: Double
    let percentage: Double
    let totalWeight: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Text(category.icon)
                        .font(.caption)
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Text(formatWeight(weight))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("(\(Int(percentage))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    Rectangle()
                        .fill(category.color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
}

/// 重量优化建议视图
struct WeightOptimizationTipsView: View {
    let prediction: WeightPrediction?
    let items: [LuggageItem]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 重量分析
                    if let prediction = prediction {
                        weightAnalysisSection(prediction)
                    }
                    
                    // 减重建议
                    weightReductionTips
                    
                    // 重物品列表
                    heavyItemsList
                }
                .padding()
            }
            .navigationTitle("减重优化")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func weightAnalysisSection(_ prediction: WeightPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重量分析")
                .font(.headline)
            
            ForEach(prediction.breakdown.sorted { $0.weight > $1.weight }, id: \.category) { item in
                HStack {
                    Text(item.category.icon)
                    Text(item.category.displayName)
                    Spacer()
                    Text(formatWeight(item.weight))
                        .fontWeight(.medium)
                    Text("(\(Int(item.percentage))%)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var weightReductionTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("减重建议")
                .font(.headline)
            
            let tips = [
                "选择轻量化材质的物品",
                "减少不必要的重复物品",
                "使用多功能物品替代单一功能物品",
                "考虑在目的地购买消耗品",
                "选择压缩包装的物品"
            ]
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(tip)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(12)
    }
    
    private var heavyItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重物品清单")
                .font(.headline)
            
            let heavyItems = items.sorted { $0.weight > $1.weight }.prefix(10)
            
            ForEach(Array(heavyItems), id: \.id) { item in
                HStack {
                    Text(item.category.icon)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.body)
                        
                        if item.quantity > 1 {
                            Text("数量: \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formatWeight(item.weight * Double(item.quantity)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(item.weight > 1000 ? .red : .primary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
}

// MARK: - ItemCategory 扩展

extension ItemCategory {
    var color: Color {
        switch self {
        case .clothing: return .blue
        case .electronics: return .purple
        case .toiletries: return .cyan
        case .documents: return .orange
        case .medicine: return .red
        case .accessories: return .pink
        case .shoes: return .brown
        case .books: return .green
        case .food: return .yellow
        case .sports: return .indigo
        case .beauty: return .mint
        case .other: return .gray
        }
    }
}

// MARK: - 预览

struct WeightPredictionView_Previews: PreviewProvider {
    static var previews: some View {
        WeightPredictionView(
            items: [
                LuggageItem(
                    name: "T恤", 
                    volume: 500, 
                    weight: 200, 
                    category: .clothing
                ),
                LuggageItem(
                    name: "牛仔裤", 
                    volume: 800, 
                    weight: 600, 
                    category: .clothing
                ),
                LuggageItem(
                    name: "笔记本电脑", 
                    volume: 2000, 
                    weight: 1500, 
                    category: .electronics
                ),
                LuggageItem(
                    name: "充电器", 
                    volume: 200, 
                    weight: 300, 
                    category: .electronics
                )
            ],
            luggage: Luggage(
                id: UUID(),
                name: "行李箱", 
                capacity: 50000, 
                emptyWeight: 3.5, 
                imagePath: nil, 
                items: [], 
                note: nil, 
                luggageType: .checked, 
                selectedAirlineId: nil
            )
        )
    }
}