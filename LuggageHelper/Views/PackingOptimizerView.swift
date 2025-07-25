import SwiftUI

/// 装箱优化视图
/// 提供基于物品和行李箱的装箱优化建议，集成 AI 智能优化功能
struct PackingOptimizerView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @EnvironmentObject var aiViewModel: AIViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let luggage: Luggage
    
    @State private var showingAnalysis = false
    @State private var packingPlan: PackingPlan?
    @State private var packingAnalysis: PackingAnalysis?
    @State private var selectedAirline: Airline?
    @State private var isLoadingAI = false
    @State private var showingAIOptions = false
    @State private var selectedOptimizationMode: OptimizationMode = .balanced
    @State private var aiPackingPlan: PackingPlan?
    @State private var showingComparison = false
    @State private var selectedPlan: PlanType = .local
    
    // 装箱优化器
    private let optimizer = PackingOptimizer.shared
    
    // 优化模式枚举
    enum OptimizationMode: String, CaseIterable {
        case space = "space"
        case weight = "weight"
        case balanced = "balanced"
        case safety = "safety"
        
        var displayName: String {
            switch self {
            case .space: return "空间优先"
            case .weight: return "重量优先"
            case .balanced: return "均衡优化"
            case .safety: return "安全优先"
            }
        }
        
        var description: String {
            switch self {
            case .space: return "最大化空间利用率"
            case .weight: return "优化重量分布"
            case .balanced: return "平衡各项指标"
            case .safety: return "优先考虑物品安全"
            }
        }
        
        var icon: String {
            switch self {
            case .space: return "cube"
            case .weight: return "scalemass"
            case .balanced: return "balance.horizontal"
            case .safety: return "shield"
            }
        }
    }
    
    // 方案类型
    enum PlanType: String, CaseIterable {
        case local = "local"
        case ai = "ai"
        
        var displayName: String {
            switch self {
            case .local: return "本地算法"
            case .ai: return "AI 优化"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 行李箱信息
                luggageInfoSection
                
                // 航空公司选择
                airlineSelectionSection
                
                // AI 优化选项
                aiOptimizationSection
                
                // 装箱优化按钮组
                optimizationButtonsSection
                
                // 方案比较选择器
                if packingPlan != nil || aiPackingPlan != nil {
                    planComparisonSection
                }
                
                // 装箱计划结果
                if let plan = currentSelectedPlan {
                    packingPlanSection(plan)
                }
                
                // 装箱分析结果
                if let analysis = packingAnalysis {
                    packingAnalysisSection(analysis)
                }
                
                // AI 建议接受和调整功能
                if aiPackingPlan != nil {
                    aiSuggestionActionsSection
                }
            }
            .padding()
        }
        .navigationTitle("智能装箱优化")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAIOptions) {
            aiOptionsSheet
        }
        .sheet(isPresented: $showingComparison) {
            planComparisonSheet
        }
        .onAppear {
            // 默认选择行李箱关联的航空公司
            if let airlineId = luggage.selectedAirlineId {
                selectedAirline = viewModel.airline(by: airlineId)
            }
            
            // 自动生成装箱计划
            generatePackingPlan()
        }
    }
    
    // 当前选中的方案
    private var currentSelectedPlan: PackingPlan? {
        switch selectedPlan {
        case .local:
            return packingPlan
        case .ai:
            return aiPackingPlan
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
    
    // AI 优化选项部分
    private var aiOptimizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("优化模式")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(OptimizationMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedOptimizationMode = mode
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(selectedOptimizationMode == mode ? .white : .blue)
                            
                            Text(mode.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedOptimizationMode == mode ? .white : .primary)
                            
                            Text(mode.description)
                                .font(.caption2)
                                .foregroundColor(selectedOptimizationMode == mode ? .white.opacity(0.8) : .secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(selectedOptimizationMode == mode ? Color.blue : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // 优化按钮组
    private var optimizationButtonsSection: some View {
        VStack(spacing: 12) {
            // 本地优化按钮
            Button(action: {
                generatePackingPlan()
                showingAnalysis = true
            }) {
                HStack {
                    Image(systemName: "cpu")
                    Text("本地算法优化")
                    Spacer()
                    if packingPlan != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            
            // AI 优化按钮
            Button(action: {
                generateAIPackingPlan()
            }) {
                HStack {
                    if isLoadingAI {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "brain")
                    }
                    Text("AI 智能优化")
                    Spacer()
                    if aiPackingPlan != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isLoadingAI || luggage.items.isEmpty)
            
            // 高级选项按钮
            Button(action: {
                showingAIOptions = true
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("高级选项")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
        }
    }
    
    // 方案比较选择器
    private var planComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("装箱方案")
                    .font(.headline)
                
                Spacer()
                
                Button("详细比较") {
                    showingComparison = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Picker("选择方案", selection: $selectedPlan) {
                ForEach(PlanType.allCases, id: \.self) { planType in
                    HStack {
                        Text(planType.displayName)
                        Spacer()
                        if planType == .local && packingPlan != nil {
                            Text("评分: \(Int(packingAnalysis?.score ?? 0))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if planType == .ai && aiPackingPlan != nil {
                            Text("AI 推荐")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .tag(planType)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // AI 建议操作部分
    private var aiSuggestionActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 建议操作")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: {
                    acceptAISuggestions()
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("接受建议")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showAdjustmentOptions()
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("调整方案")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    rejectAISuggestions()
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("拒绝")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 装箱计划部分
    private func packingPlanSection(_ plan: PackingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("装箱计划")
                    .font(.headline)
                
                Spacer()
                
                // 方案来源标识
                HStack(spacing: 4) {
                    Image(systemName: selectedPlan == .ai ? "brain" : "cpu")
                        .font(.caption)
                    Text(selectedPlan.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selectedPlan == .ai ? Color.blue.opacity(0.1) : Color(.systemGray5))
                .foregroundColor(selectedPlan == .ai ? .blue : .secondary)
                .cornerRadius(4)
            }
            
            // 装箱统计卡片
            packingStatsCards(plan)
            
            // 装箱警告
            if !plan.warnings.isEmpty {
                enhancedWarningsSection(plan.warnings)
            }
            
            // 装箱建议
            if !plan.suggestions.isEmpty {
                enhancedSuggestionsSection(plan.suggestions)
            }
            
            // 可视化装箱顺序
            visualPackingOrderSection(plan.items)
            
            // 详细指导按钮
            NavigationLink(destination: PackingSuggestionDetailView(
                packingPlan: plan,
                luggage: luggage,
                items: luggage.items
            )) {
                HStack {
                    Spacer()
                    Image(systemName: "list.bullet.clipboard")
                    Text("查看详细装箱指导")
                    Spacer()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    // 装箱统计卡片
    private func packingStatsCards(_ plan: PackingPlan) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            // 重量卡片
            StatCard(
                title: "总重量",
                value: "\(String(format: "%.1f", plan.totalWeight / 1000))kg",
                subtitle: "含箱重: \(String(format: "%.1f", (plan.totalWeight + luggage.emptyWeight * 1000) / 1000))kg",
                icon: "scalemass",
                color: .orange
            )
            
            // 体积卡片
            StatCard(
                title: "空间利用率",
                value: "\(String(format: "%.1f", plan.efficiency * 100))%",
                subtitle: "剩余: \(String(format: "%.0f", luggage.capacity - plan.totalVolume))cm³",
                icon: "cube",
                color: .blue
            )
            
            // 物品数量卡片
            StatCard(
                title: "物品数量",
                value: "\(plan.items.count)件",
                subtitle: "平均重量: \(String(format: "%.0f", plan.totalWeight / Double(plan.items.count)))g",
                icon: "shippingbox",
                color: .green
            )
            
            // 优化评分卡片
            StatCard(
                title: "优化评分",
                value: "\(Int(packingAnalysis?.score ?? 0))/100",
                subtitle: scoreDescription(packingAnalysis?.score ?? 0),
                icon: "star",
                color: scoreColor(packingAnalysis?.score ?? 0)
            )
        }
    }
    
    // 统计卡片组件
    private struct StatCard: View {
        let title: String
        let value: String
        let subtitle: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // 增强的警告部分
    private func enhancedWarningsSection(_ warnings: [PackingWarning]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("警告")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("\(warnings.count)个")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }
            
            ForEach(warnings.sorted { $0.severity.rawValue > $1.severity.rawValue }) { warning in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: warningIcon(warning.type))
                        .foregroundColor(warningColor(warning.severity))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(warningTypeDisplayName(warning.type))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(warningColor(warning.severity))
                        
                        Text(warning.message)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(warning.severity.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(warningColor(warning.severity).opacity(0.2))
                        .foregroundColor(warningColor(warning.severity))
                        .cornerRadius(4)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(warningColor(warning.severity).opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 增强的建议部分
    private func enhancedSuggestionsSection(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)
                Text("装箱建议")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(suggestions.count)条")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 可视化装箱顺序部分
    private func visualPackingOrderSection(_ items: [PackingItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("装箱顺序")
                .font(.headline)
            
            // 按位置分组并可视化
            let positionGroups = Dictionary(grouping: items) { $0.position }
            let sortedPositions: [PackingPosition] = [.top, .middle, .bottom, .side, .corner]
            
            VStack(spacing: 8) {
                ForEach(sortedPositions, id: \.self) { position in
                    if let positionItems = positionGroups[position] {
                        packingPositionRow(position: position, items: positionItems)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // 装箱位置行
    private func packingPositionRow(position: PackingPosition, items: [PackingItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(position.displayName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(positionColor(position))
                
                Spacer()
                
                Text("\(items.count)件")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(positionColor(position).opacity(0.2))
                    .foregroundColor(positionColor(position))
                    .cornerRadius(4)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(items.sorted { $0.priority > $1.priority }.prefix(6)) { item in
                    if let luggageItem = luggage.items.first(where: { $0.id == item.itemId }) {
                        VStack(spacing: 4) {
                            Text(luggageItem.category.icon)
                                .font(.title3)
                            
                            Text(luggageItem.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text("优先级: \(item.priority)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(6)
                    }
                }
                
                if items.count > 6 {
                    VStack {
                        Text("...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("还有\(items.count - 6)件")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(positionColor(position).opacity(0.1))
        .cornerRadius(8)
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
    
    // AI 选项表单
    private var aiOptionsSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("AI 优化设置")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("优化模式")
                        .font(.headline)
                    
                    ForEach(OptimizationMode.allCases, id: \.self) { mode in
                        Button(action: {
                            selectedOptimizationMode = mode
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayName)
                                        .fontWeight(.medium)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedOptimizationMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(selectedOptimizationMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingAIOptions = false
                    generateAIPackingPlan()
                }) {
                    HStack {
                        Spacer()
                        Text("开始 AI 优化")
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("取消") {
                    showingAIOptions = false
                }
            )
        }
    }
    
    // 方案比较表单
    private var planComparisonSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("方案对比")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let localPlan = packingPlan, let aiPlan = aiPackingPlan {
                        comparisonTable(localPlan: localPlan, aiPlan: aiPlan)
                    }
                    
                    // 详细对比图表
                    if let localAnalysis = packingAnalysis {
                        comparisonCharts(analysis: localAnalysis)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    showingComparison = false
                }
            )
        }
    }
    
    // 对比表格
    private func comparisonTable(localPlan: PackingPlan, aiPlan: PackingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("方案对比")
                .font(.headline)
            
            VStack(spacing: 8) {
                comparisonRow(title: "空间利用率", 
                            localValue: "\(String(format: "%.1f", localPlan.efficiency * 100))%",
                            aiValue: "\(String(format: "%.1f", aiPlan.efficiency * 100))%")
                
                comparisonRow(title: "总重量", 
                            localValue: "\(String(format: "%.1f", localPlan.totalWeight / 1000))kg",
                            aiValue: "\(String(format: "%.1f", aiPlan.totalWeight / 1000))kg")
                
                comparisonRow(title: "警告数量", 
                            localValue: "\(localPlan.warnings.count)个",
                            aiValue: "\(aiPlan.warnings.count)个")
                
                comparisonRow(title: "建议数量", 
                            localValue: "\(localPlan.suggestions.count)条",
                            aiValue: "\(aiPlan.suggestions.count)条")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // 对比行
    private func comparisonRow(title: String, localValue: String, aiValue: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(localValue)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            Text("vs")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(aiValue)
                .foregroundColor(.blue)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .trailing)
        }
    }
    
    // 对比图表
    private func comparisonCharts(analysis: PackingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("类别分布对比")
                .font(.headline)
            
            // 这里可以添加图表组件，暂时用简单的条形图表示
            ForEach(analysis.categoryBreakdown.prefix(5), id: \.category) { category in
                HStack {
                    Text(category.category.icon)
                    Text(category.category.displayName)
                        .frame(width: 80, alignment: .leading)
                    
                    // 简单的进度条
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: geometry.size.width * CGFloat(category.weightPercentage))
                            
                            Rectangle()
                                .fill(Color.clear)
                        }
                    }
                    .frame(height: 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                    
                    Text("\(String(format: "%.1f", category.weightPercentage * 100))%")
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                }
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
    
    // 生成 AI 装箱计划
    private func generateAIPackingPlan() {
        guard !luggage.items.isEmpty else { return }
        
        isLoadingAI = true
        
        Task {
            do {
                // 使用 AI 服务生成装箱计划
                let plan = try await aiViewModel.aiService.optimizePacking(
                    items: luggage.items,
                    luggage: luggage
                )
                
                await MainActor.run {
                    self.aiPackingPlan = plan
                    self.selectedPlan = .ai
                    self.isLoadingAI = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingAI = false
                    // 显示错误信息
                    print("AI 优化失败: \(error)")
                }
            }
        }
    }
    
    // 接受 AI 建议
    private func acceptAISuggestions() {
        guard let aiPlan = aiPackingPlan else { return }
        
        // 将 AI 建议应用到当前装箱方案
        packingPlan = aiPlan
        selectedPlan = .local
        
        // 显示成功提示
        // 这里可以添加 Toast 提示
    }
    
    // 显示调整选项
    private func showAdjustmentOptions() {
        // 显示调整界面，允许用户微调 AI 建议
        // 这里可以实现更详细的调整功能
    }
    
    // 拒绝 AI 建议
    private func rejectAISuggestions() {
        aiPackingPlan = nil
        selectedPlan = .local
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
    
    // 位置颜色
    private func positionColor(_ position: PackingPosition) -> Color {
        switch position {
        case .bottom:
            return .brown
        case .middle:
            return .orange
        case .top:
            return .green
        case .side:
            return .blue
        case .corner:
            return .purple
        }
    }
    
    // 警告图标
    private func warningIcon(_ type: WarningType) -> String {
        switch type {
        case .overweight:
            return "scalemass"
        case .oversized:
            return "cube"
        case .fragile:
            return "exclamationmark.shield"
        case .liquid:
            return "drop"
        case .battery:
            return "battery.100"
        case .prohibited:
            return "xmark.circle"
        case .attention:
            return "exclamationmark.triangle"
        }
    }
    
    // 警告类型显示名称
    private func warningTypeDisplayName(_ type: WarningType) -> String {
        switch type {
        case .overweight:
            return "超重警告"
        case .oversized:
            return "超尺寸警告"
        case .fragile:
            return "易碎品提醒"
        case .liquid:
            return "液体限制"
        case .battery:
            return "电池规定"
        case .prohibited:
            return "禁止携带"
        case .attention:
            return "注意事项"
        }
    }
    
    // 评分描述
    private func scoreDescription(_ score: Double) -> String {
        if score >= 90 {
            return "优秀"
        } else if score >= 80 {
            return "良好"
        } else if score >= 70 {
            return "一般"
        } else if score >= 60 {
            return "需改进"
        } else {
            return "较差"
        }
    }
}

struct PackingOptimizerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PackingOptimizerView(luggage: Luggage(name: "示例行李箱", capacity: 50000, emptyWeight: 3.5))
                .environmentObject(LuggageViewModel())
                .environmentObject(AIViewModel())
        }
    }
}