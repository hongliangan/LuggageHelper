import SwiftUI

/// 替代品建议测试视图
struct AlternativeSuggestionTestView: View {
    @StateObject private var llmService = LLMAPIService.shared
    @StateObject private var configManager = LLMConfigurationManager.shared
    
    @State private var testItemName = "厚重毛衣"
    @State private var testItemCategory = ItemCategory.clothing
    @State private var testItemWeight = 800.0
    @State private var testItemVolume = 1200.0
    
    @State private var maxWeight = 500.0
    @State private var maxVolume = 800.0
    @State private var maxBudget = 200.0
    @State private var requiredFeatures = "轻便,保暖"
    
    @State private var alternatives: [AlternativeItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 配置状态
                    configurationStatus
                    
                    // 测试物品输入
                    testItemSection
                    
                    // 约束条件输入
                    constraintsSection
                    
                    // 测试按钮
                    testButtons
                    
                    // 结果显示
                    if showingResults {
                        resultsSection
                    }
                }
                .padding()
            }
            .navigationTitle("替代品建议测试")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 子视图
    
    private var configurationStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LLM API 配置状态")
                .font(.headline)
            
            HStack {
                Image(systemName: configManager.isConfigValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(configManager.isConfigValid ? .green : .red)
                
                Text(configManager.isConfigValid ? "已配置" : "未配置")
                    .foregroundColor(configManager.isConfigValid ? .green : .red)
                
                Spacer()
                
                if !configManager.isConfigValid {
                    Button("配置") {
                        // 打开配置界面
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testItemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试物品")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("物品名称:")
                        .frame(width: 80, alignment: .leading)
                    TextField("输入物品名称", text: $testItemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("类别:")
                        .frame(width: 80, alignment: .leading)
                    Picker("类别", selection: $testItemCategory) {
                        ForEach(ItemCategory.allCases, id: \.self) { category in
                            Text("\(category.icon) \(category.displayName)").tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("重量(g):")
                        .frame(width: 80, alignment: .leading)
                    TextField("重量", value: $testItemWeight, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    Text("体积(cm³):")
                        .frame(width: 80, alignment: .leading)
                    TextField("体积", value: $testItemVolume, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("约束条件")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("最大重量(g):")
                        .frame(width: 100, alignment: .leading)
                    TextField("最大重量", value: $maxWeight, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    Text("最大体积(cm³):")
                        .frame(width: 100, alignment: .leading)
                    TextField("最大体积", value: $maxVolume, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    Text("预算上限(元):")
                        .frame(width: 100, alignment: .leading)
                    TextField("预算", value: $maxBudget, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("必需功能 (用逗号分隔):")
                    TextField("如: 轻便,保暖,防水", text: $requiredFeatures)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var testButtons: some View {
        VStack(spacing: 12) {
            Button("测试单个替代品建议") {
                testSingleAlternative()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || !configManager.isConfigValid)
            
            Button("测试功能性替代品搜索") {
                testFunctionalAlternatives()
            }
            .buttonStyle(.bordered)
            .disabled(isLoading || !configManager.isConfigValid)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在获取建议...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("测试结果")
                .font(.headline)
            
            if let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("错误")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(.systemRed).opacity(0.1))
                .cornerRadius(8)
            } else if alternatives.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("未找到替代品建议")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(alternatives, id: \.id) { alternative in
                        AlternativeResultCard(alternative: alternative)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 方法
    
    private func testSingleAlternative() {
        guard configManager.isConfigValid else {
            errorMessage = "请先配置LLM API"
            return
        }
        
        isLoading = true
        errorMessage = nil
        showingResults = true
        alternatives = []
        
        Task {
            do {
                let testItem = ItemInfo(
                    name: testItemName,
                    category: testItemCategory,
                    weight: testItemWeight,
                    volume: testItemVolume,
                    confidence: 1.0,
                    source: "测试输入"
                )
                
                let constraints = AlternativeConstraints(
                    maxWeight: maxWeight,
                    maxVolume: maxVolume,
                    maxBudget: maxBudget,
                    requiredFeatures: requiredFeatures.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                )
                
                let result = try await llmService.suggestAlternatives(
                    for: testItem,
                    constraints: constraints
                )
                
                await MainActor.run {
                    self.alternatives = result
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
    
    private func testFunctionalAlternatives() {
        guard configManager.isConfigValid else {
            errorMessage = "请先配置LLM API"
            return
        }
        
        isLoading = true
        errorMessage = nil
        showingResults = true
        alternatives = []
        
        Task {
            do {
                let constraints = AlternativeConstraints(
                    maxWeight: maxWeight,
                    maxVolume: maxVolume,
                    maxBudget: maxBudget,
                    requiredFeatures: requiredFeatures.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                )
                
                let result = try await llmService.searchFunctionalAlternatives(
                    functionality: "提供\(testItemName)的功能",
                    constraints: constraints
                )
                
                await MainActor.run {
                    self.alternatives = result
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
}

// MARK: - 替代品结果卡片

struct AlternativeResultCard: View {
    let alternative: AlternativeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 基本信息
            HStack(spacing: 12) {
                Text(alternative.category.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alternative.name)
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        Label(formatWeight(alternative.weight), systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(formatVolume(alternative.volume), systemImage: "cube")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let price = alternative.estimatedPrice {
                            Label("¥\(Int(price))", systemImage: "yensign.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 评分
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(index < Int(alternative.suitability * 5) ? .yellow : .gray.opacity(0.3))
                                .font(.caption)
                        }
                    }
                    
                    Text("适用性")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 优势和劣势
            if !alternative.advantages.isEmpty || !alternative.disadvantages.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    if !alternative.advantages.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("优势")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            
                            ForEach(alternative.advantages.prefix(2), id: \.self) { advantage in
                                Text("• \(advantage)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if !alternative.disadvantages.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text("劣势")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            
                            ForEach(alternative.disadvantages.prefix(2), id: \.self) { disadvantage in
                                Text("• \(disadvantage)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // 推荐理由
            if !alternative.reason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("推荐理由")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text(alternative.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // 评分详情
            HStack(spacing: 16) {
                if let functionality = alternative.functionalityMatch {
                    ScoreIndicator(title: "功能匹配", score: functionality, color: .blue)
                }
                
                ScoreIndicator(title: "兼容性", score: alternative.compatibilityScore, color: .green)
                
                if let versatility = alternative.versatility {
                    ScoreIndicator(title: "多功能性", score: versatility, color: .purple)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
    
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

// MARK: - 评分指示器

struct ScoreIndicator: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score * 100))")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - 预览

struct AlternativeSuggestionTestView_Previews: PreviewProvider {
    static var previews: some View {
        AlternativeSuggestionTestView()
    }
}