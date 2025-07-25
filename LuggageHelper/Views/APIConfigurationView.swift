import SwiftUI

/// API配置主界面视图
struct APIConfigurationView: View {
    @StateObject private var configManager = APIConfigurationManager.shared
    @State private var showingTestResult = false
    @State private var testResultMessage = ""
    @State private var testResultType: ResultType = .success
    @State private var showingSaveConfirmation = false
    
    enum ResultType {
        case success, failure
    }
    
    var body: some View {
        NavigationStack {
            Form {
                configurationSection
                modelSelectionSection
                advancedSettingsSection
                actionButtonsSection
            }
            .navigationTitle("硅基流动API配置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("测试结果", isPresented: $showingTestResult) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(testResultMessage)
            }
            .confirmationDialog("保存确认", isPresented: $showingSaveConfirmation) {
                Button("强制保存", role: .destructive) {
                    saveConfiguration(force: true)
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("连接测试失败。您确定要保存此配置吗？")
            }
        }
    }
    
    // MARK: - 配置部分
    
    private var configurationSection: some View {
        Section(header: Text("基础配置")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("基础URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://api.siliconflow.cn/v1", text: $configManager.currentConfig.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API密钥")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("sf-开头的API密钥", text: $configManager.currentConfig.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
    
    // MARK: - 模型选择部分
    
    private var modelSelectionSection: some View {
        Section(header: Text("模型选择")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("模型名称")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例如：deepseek-ai/DeepSeek-V2.5", text: $configManager.currentConfig.model)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
    
    // MARK: - 高级设置部分
    
    private var advancedSettingsSection: some View {
        Section(header: Text("高级设置")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("最大Token数: \(configManager.currentConfig.maxTokens)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(configManager.currentConfig.maxTokens) },
                    set: { configManager.updateConfiguration(maxTokens: Int($0)) }
                ), in: 100...4000, step: 100)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("温度参数: \(String(format: "%.1f", configManager.currentConfig.temperature))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $configManager.currentConfig.temperature, in: 0.0...2.0, step: 0.1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Top-p参数: \(String(format: "%.1f", configManager.currentConfig.topP))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $configManager.currentConfig.topP, in: 0.0...1.0, step: 0.1)
            }
        }
    }
    
    // MARK: - 操作按钮部分
    
    private var actionButtonsSection: some View {
        Section {
            Button(action: testConnection) { // 直接调用 testConnection
                HStack {
                    Image(systemName: "network")
                    Text("测试连接")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: { saveConfiguration(force: true) }) { // 添加一个独立的保存按钮
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("保存配置")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: resetToDefaults) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("恢复默认")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.orange)
            
            Button(action: clearConfiguration) {
                HStack {
                    Image(systemName: "trash")
                    Text("清除配置")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - 操作方法
    
    /// 测试连接
    // 修复 testConnection 方法
    private func testConnection() {
        Task {
            do {
                let llmConfig = LLMAPIService.LLMServiceConfig(
                    providerType: .openai,
                    baseURL: configManager.currentConfig.baseURL,
                    apiKey: configManager.currentConfig.apiKey,
                    model: configManager.currentConfig.model,
                    maxTokens: configManager.currentConfig.maxTokens,
                    temperature: configManager.currentConfig.temperature,
                    topP: configManager.currentConfig.topP
                )
                let result = try await LLMAPIService.shared.testConnection(config: llmConfig)
                await MainActor.run {
                    testResultMessage = result
                    testResultType = .success
                    showingTestResult = true
                }
            } catch {
                await MainActor.run {
                    testResultMessage = "连接测试失败: \(error.localizedDescription)"
                    testResultType = .failure
                    showingTestResult = true
                }
            }
        }
    }
    
    /// 保存配置
    private func saveConfiguration(force: Bool) {
        if force {
            configManager.saveConfiguration(configManager.currentConfig)
            testResultMessage = "配置已成功保存。"
            testResultType = .success
            showingTestResult = true
        }
    }
    
    private func resetToDefaults() {
        configManager.saveConfiguration(.default)
    }
    
    private func clearConfiguration() {
        configManager.clearConfiguration()
    }
}

// MARK: - 模型信息视图

struct ModelInfoView: View {
    var body: some View {
        List {
            ForEach(SupportedModels.modelDetails, id: \.name) { model in
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.name)
                        .font(.headline)
                    
                    Text(model.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label(model.contextLength, systemImage: "text.justify")
                        Spacer()
                        Label(model.price, systemImage: "dollarsign.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("模型信息")
    }
}

// MARK: - 配置验证视图

struct ConfigurationValidationView: View {
    let validationResult: ValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if validationResult.isValid {
                Label("配置有效", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Label("配置存在问题", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                ForEach(validationResult.errors, id: \.self) { error in
                    HStack(alignment: .top) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.orange)
                            .padding(.top, 6)
                        Text(error.errorDescription ?? "未知错误")
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - 行李建议生成视图

struct LuggageSuggestionView: View {
    @ObservedObject private var apiService = LLMAPIService.shared
    @State private var destination = ""
    @State private var duration = 7
    @State private var season = "春季"
    @State private var activities = "观光, 购物, 美食"
    @State private var suggestion = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let seasons = ["春季", "夏季", "秋季", "冬季"]
    
    var body: some View {
        NavigationStack {
            Form {
                travelInfoSection
                generateButtonSection
                suggestionSection
            }
            .navigationTitle("行李建议生成")
            .navigationBarTitleDisplayMode(.inline)
            .alert("生成失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var travelInfoSection: some View {
        Section(header: Text("旅行信息")) {
            TextField("目的地", text: $destination)
                .textFieldStyle(.roundedBorder)
            
            Stepper("旅行天数: \(duration)", value: $duration, in: 1...30)
            
            Picker("季节", selection: $season) {
                ForEach(seasons, id: \.self) { season in
                    Text(season).tag(season)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("计划活动（用逗号分隔）", text: $activities)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var generateButtonSection: some View {
        Section {
            Button(action: generateSuggestion) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "生成中..." : "生成行李建议")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(destination.isEmpty || isLoading)
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var suggestionSection: some View {
        Section(header: Text("行李建议")) {
            if suggestion.isEmpty {
                Text("请填写旅行信息并点击生成按钮")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(suggestion)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 8)
            }
        }
    }
    
    private func generateSuggestion() {
        isLoading = true
        suggestion = ""
        
        Task {
            do {
                let result = try await LLMAPIService.shared.generateTravelChecklist(
                    destination: destination,
                    duration: duration,
                    season: season,
                    activities: activities.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                )
                
                await MainActor.run {
                    suggestion = formatTravelSuggestion(result)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    /// 格式化旅行建议为字符串显示
    private func formatTravelSuggestion(_ travelSuggestion: TravelSuggestion) -> String {
        var result = "\n📋 **推荐物品清单**\n\n"
        
        // 修复：使用正确的属性名 suggestedItems
        for item in travelSuggestion.suggestedItems {
            result += "• \(item.name)\n"
            if !item.reason.isEmpty {
                result += "  理由: \(item.reason)\n"
            }
            result += "\n"
        }
        
        if !travelSuggestion.categories.isEmpty {
            result += "\n📂 **主要类别**\n"
            for category in travelSuggestion.categories {
                result += "• \(category.displayName)\n"
            }
        }
        
        // 添加旅行小贴士
        if !travelSuggestion.tips.isEmpty {
            result += "\n💡 **旅行小贴士**\n"
            for tip in travelSuggestion.tips {
                result += "• \(tip)\n"
            }
        }
        
        // 添加注意事项
        if !travelSuggestion.warnings.isEmpty {
            result += "\n⚠️ **注意事项**\n"
            for warning in travelSuggestion.warnings {
                result += "• \(warning)\n"
            }
        }
        
        return result
    }
}

// MARK: - 扩展模型信息

extension SupportedModels {
    static let modelDetails: [ModelDetail] = [
        ModelDetail(
            name: "deepseek-ai/DeepSeek-R1",
            description: "DeepSeek-R1 是最新的推理模型，在数学、代码和推理任务上表现优异",
            contextLength: "128K tokens",
            price: "¥0.004/1K tokens"
        ),
        ModelDetail(
            name: "deepseek-ai/DeepSeek-V3",
            description: "DeepSeek-V3 是强大的通用大模型，适用于各种场景",
            contextLength: "128K tokens",
            price: "¥0.001/1K tokens"
        ),
        ModelDetail(
            name: "Qwen/Qwen2.5-72B-Instruct",
            description: "通义千问2.5 72B指令微调模型，中文能力突出",
            contextLength: "128K tokens",
            price: "¥0.002/1K tokens"
        )
    ]
}

struct ModelDetail {
    let name: String
    let description: String
    let contextLength: String
    let price: String
}

// 修复类型转换（类似第4点）
// 修复动态成员访问 - 移除不存在的方法调用
// 将：
// llmService.generateLuggageSuggestion
// 改为正确的方法名或移除该调用
