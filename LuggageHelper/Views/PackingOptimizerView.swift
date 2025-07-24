import SwiftUI

/// 装箱优化视图
/// 提供基于物品和行李箱的装箱优化建议
struct PackingOptimizerView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let luggage: Luggage
    
    @State private var showingAnalysis = false
    @State private var packingPlan: PackingPlan?
    @State private var packingAnalysis: PackingAnalysis?
    @State private var selectedAirline: Airline?
    
    // 装箱优化器
    private let optimizer = PackingOptimizer.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 行李箱信息
                luggageInfoSection
                
                // 航空公司选择
                airlineSelectionSection
                
                // 装箱优化按钮
                optimizeButton
                
                // 装箱计划结果
                if let plan = packingPlan {
                    packingPlanSection(plan)
                }
                
                // 装箱分析结果
                if let analysis = packingAnalysis {
                    packingAnalysisSection(analysis)
                }
            }
            .padding()
        }
        .navigationTitle("装箱优化")
        .onAppear {
            // 默认选择行李箱关联的航空公司
            if let airlineId = luggage.selectedAirlineId {
                selectedAirline = viewModel.airline(by: airlineId)
            }
            
            // 自动生成装箱计划
            generatePackingPlan()
        }
    }
    
    // 行李箱信息部分
    private var luggageInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("行李箱信息")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("名称: \(luggage.name)")
                    Text("类型: \(luggage.luggageType.displayName)")
                    Text("容量: \(String(format: "%.1f", luggage.capacity))cm³")
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("空箱重量: \(String(format: "%.1f", luggage.emptyWeight))kg")
                    Text("物品数量: \(luggage.items.count)件")
                    Text("总重量: \(String(format: "%.1f", luggage.totalWeight))kg")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // 航空公司选择部分
    private var airlineSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择航空公司")
                .font(.headline)
            
            Picker("航空公司", selection: $selectedAirline) {
                Text("无").tag(nil as Airline?)
                ForEach(viewModel.airlines) { airline in
                    Text(airline.name).tag(airline as Airline?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedAirline) { _ in
                // 重新生成装箱计划
                generatePackingPlan()
            }
            
            if let airline = selectedAirline {
                VStack(alignment: .leading, spacing: 4) {
                    Text("托运限重: \(String(format: "%.1f", airline.checkedBaggageWeightLimit))kg")
                    Text("手提限重: \(String(format: "%.1f", airline.carryOnWeightLimit))kg")
                }
                .padding(.vertical, 4)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // 优化按钮
    private var optimizeButton: some View {
        Button(action: {
            generatePackingPlan()
            showingAnalysis = true
        }) {
            HStack {
                Spacer()
                Image(systemName: "wand.and.stars")
                Text("优化装箱方案")
                Spacer()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    // 装箱计划部分
    private func packingPlanSection(_ plan: PackingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装箱计划")
                .font(.headline)
            
            // 装箱统计
            HStack {
                VStack(alignment: .leading) {
                    Text("总重量: \(String(format: "%.1f", plan.totalWeight / 1000))kg")
                    Text("总体积: \(String(format: "%.1f", plan.totalVolume))cm³")
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("空间利用率: \(String(format: "%.1f", plan.efficiency * 100))%")
                    Text("物品数量: \(plan.items.count)件")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 装箱警告
            if !plan.warnings.isEmpty {
                warningsSection(plan.warnings)
            }
            
            // 装箱建议
            if !plan.suggestions.isEmpty {
                suggestionsSection(plan.suggestions)
            }
            
            // 装箱顺序
            packingOrderSection(plan.items)
        }
    }
    
    // 装箱分析部分
    private func packingAnalysisSection(_ analysis: PackingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装箱分析")
                .font(.headline)
            
            // 装箱评分
            HStack {
                Text("装箱评分")
                Spacer()
                Text("\(Int(analysis.score))/100")
                    .font(.title2)
                    .foregroundColor(scoreColor(analysis.score))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 类别分布
            categoryBreakdownSection(analysis.categoryBreakdown)
            
            // 智能建议
            if !analysis.recommendations.isEmpty {
                recommendationsSection(analysis.recommendations)
            }
        }
    }
    
    // 警告部分
    private func warningsSection(_ warnings: [PackingWarning]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("警告")
                .font(.headline)
                .foregroundColor(.red)
            
            ForEach(warnings) { warning in
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(warningColor(warning.severity))
                    
                    Text(warning.message)
                        .foregroundColor(warningColor(warning.severity))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 建议部分
    private func suggestionsSection(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("装箱建议")
                .font(.headline)
                .foregroundColor(.blue)
            
            ForEach(suggestions, id: \.self) { suggestion in
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.blue)
                    
                    Text(suggestion)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 装箱顺序部分
    private func packingOrderSection(_ items: [PackingItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("装箱顺序")
                .font(.headline)
            
            // 按位置分组
            let positionGroups = Dictionary(grouping: items) { $0.position }
            let sortedPositions: [PackingPosition] = [.bottom, .middle, .top, .side, .corner]
            
            ForEach(sortedPositions, id: \.self) { position in
                if let positionItems = positionGroups[position] {
                    DisclosureGroup(
                        content: {
                            ForEach(positionItems.sorted { $0.priority > $1.priority }) { item in
                                if let luggageItem = luggage.items.first(where: { $0.id == item.itemId }) {
                                    HStack {
                                        Text(luggageItem.name)
                                        Spacer()
                                        Text("优先级: \(item.priority)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        },
                        label: {
                            HStack {
                                Text("\(position.displayName) (\(positionItems.count)件)")
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                                Text(positionDescription(position))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 类别分布部分
    private func categoryBreakdownSection(_ categories: [CategoryAnalysis]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类别分布")
                .font(.headline)
            
            ForEach(categories.sorted { $0.totalWeight > $1.totalWeight }, id: \.category) { category in
                HStack {
                    Text(category.category.icon)
                    Text(category.category.displayName)
                    Spacer()
                    Text("\(category.itemCount)件")
                    Text("\(String(format: "%.1f", category.totalWeight / 1000))kg")
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 智能建议部分
    private func recommendationsSection(_ recommendations: [SmartSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("智能建议")
                .font(.headline)
                .foregroundColor(.blue)
            
            ForEach(recommendations.sorted { $0.priority > $1.priority }) { suggestion in
                HStack(alignment: .top) {
                    Text(suggestion.type.icon)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .bold()
                        
                        Text(suggestion.description)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 生成装箱计划
    private func generatePackingPlan() {
        // 生成装箱计划
        packingPlan = optimizer.optimizePacking(
            items: luggage.items,
            luggage: luggage,
            airline: selectedAirline
        )
        
        // 生成装箱分析
        packingAnalysis = optimizer.analyzePackingPlan(
            items: luggage.items,
            luggage: luggage
        )
    }
    
    // 警告颜色
    private func warningColor(_ severity: WarningSeverity) -> Color {
        switch severity {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
    
    // 评分颜色
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    // 位置描述
    private func positionDescription(_ position: PackingPosition) -> String {
        switch position {
        case .bottom:
            return "最先放入"
        case .middle:
            return "中间放入"
        case .top:
            return "最后放入"
        case .side:
            return "侧面放入"
        case .corner:
            return "角落填充"
        }
    }
}

struct PackingOptimizerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PackingOptimizerView(luggage: Luggage(name: "示例行李箱", capacity: 50000, emptyWeight: 3.5))
                .environmentObject(LuggageViewModel())
        }
    }
}