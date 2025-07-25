import SwiftUI

/// 智能提醒主界面
struct SmartRemindersView: View {
    @StateObject private var llmService = LLMAPIService.shared
    @StateObject private var configManager = LLMConfigurationManager.shared
    @StateObject private var userPreferences = UserPreferencesManager.shared
    
    let checklist: [LuggageItem]
    let luggage: Luggage?
    let travelPlan: TravelPlan?
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var reminderSettings = ReminderSettings()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 配置状态提示
                if !configManager.isConfigValid {
                    configurationBanner
                }
                
                // 标签页选择器
                tabSelector
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    // 遗漏物品检查
                    if let travelPlan = travelPlan {
                        MissingItemsCheckView(
                            checklist: checklist,
                            travelPlan: travelPlan
                        )
                        .tag(0)
                    } else {
                        noTravelPlanView
                            .tag(0)
                    }
                    
                    // 重量预测
                    WeightPredictionView(
                        items: checklist,
                        luggage: luggage
                    )
                    .tag(1)
                    
                    // 智能建议
                    SmartSuggestionsView(
                        items: checklist,
                        travelPlan: travelPlan
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("智能提醒")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ReminderSettingsView(settings: $reminderSettings)
            }
        }
    }
    
    // MARK: - 子视图
    
    private var configurationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("请先配置LLM API以使用智能提醒功能")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("配置") {
                // 跳转到配置页面
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemOrange).opacity(0.1))
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "遗漏检查",
                icon: "checkmark.shield.fill",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabButton(
                title: "重量预测",
                icon: "scalemass.fill",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabButton(
                title: "智能建议",
                icon: "lightbulb.fill",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .padding(.horizontal)
        .background(Color(.systemGray6))
    }
    
    private var noTravelPlanView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("需要旅行计划")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("遗漏物品检查需要您的旅行计划信息。请先创建或选择一个旅行计划。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("创建旅行计划") {
                // 跳转到旅行计划创建页面
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 标签按钮

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 智能建议视图

struct SmartSuggestionsView: View {
    let items: [LuggageItem]
    let travelPlan: TravelPlan?
    
    @StateObject private var llmService = LLMAPIService.shared
    @State private var suggestions: [LocalSmartSuggestion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if suggestions.isEmpty {
                    emptyStateView
                } else {
                    suggestionsContent
                }
            }
            .padding()
        }
        .onAppear {
            if suggestions.isEmpty {
                loadSuggestions()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在生成智能建议...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("获取智能建议")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("AI将根据您的物品和旅行计划提供个性化建议")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("生成建议") {
                loadSuggestions()
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
            
            Text("生成失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                loadSuggestions()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var suggestionsContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(suggestions, id: \.id) { suggestion in
                SmartSuggestionCard(suggestion: suggestion)
            }
        }
    }
    
    private func loadSuggestions() {
        isLoading = true
        errorMessage = nil
        
        // 模拟生成建议
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.suggestions = generateMockSuggestions()
            self.isLoading = false
        }
    }
    
    private func generateMockSuggestions() -> [LocalSmartSuggestion] {
        [
            LocalSmartSuggestion(
                type: .optimization,
                title: "装箱空间优化",
                description: "您的衣物可以通过卷叠方式节省30%的空间",
                priority: .high,
                actionable: true
            ),
            LocalSmartSuggestion(
                type: .safety,
                title: "液体物品提醒",
                description: "检测到3件液体物品，请确保符合航空液体限制",
                priority: .medium,
                actionable: false
            ),
            LocalSmartSuggestion(
                type: .recommendation,
                title: "天气适应建议",
                description: "目的地近期有雨，建议携带轻便雨具",
                priority: .low,
                actionable: true
            )
        ]
    }
}

// MARK: - 智能建议卡片

struct SmartSuggestionCard: View {
    let suggestion: LocalSmartSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(suggestion.type.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(suggestion.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                PriorityBadge(priority: suggestion.priority)
            }
            
            if suggestion.actionable {
                HStack {
                    Spacer()
                    
                    Button("查看详情") {
                        // 处理建议操作
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 优先级徽章

struct PriorityBadge: View {
    let priority: LocalSmartSuggestion.Priority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.2))
            .foregroundColor(priority.color)
            .cornerRadius(4)
    }
}

// MARK: - 提醒设置视图

struct ReminderSettingsView: View {
    @Binding var settings: ReminderSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("检查设置") {
                    Toggle("启用遗漏物品检查", isOn: $settings.enableMissingItemsCheck)
                    Toggle("启用重量预测", isOn: $settings.enableWeightPrediction)
                    Toggle("启用智能建议", isOn: $settings.enableSmartSuggestions)
                }
                
                Section("提醒频率") {
                    Picker("检查频率", selection: $settings.checkFrequency) {
                        Text("每次打开").tag(ReminderSettings.CheckFrequency.always)
                        Text("每日一次").tag(ReminderSettings.CheckFrequency.daily)
                        Text("手动触发").tag(ReminderSettings.CheckFrequency.manual)
                    }
                }
                
                Section("通知设置") {
                    Toggle("推送通知", isOn: $settings.enableNotifications)
                    
                    if settings.enableNotifications {
                        Toggle("重量超限提醒", isOn: $settings.notifyWeightLimit)
                        Toggle("遗漏重要物品提醒", isOn: $settings.notifyMissingItems)
                    }
                }
                
                Section("个性化") {
                    Toggle("学习用户偏好", isOn: $settings.learnUserPreferences)
                    Toggle("记住忽略的建议", isOn: $settings.rememberIgnoredSuggestions)
                }
            }
            .navigationTitle("提醒设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // 保存设置到UserDefaults或其他持久化存储
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: "reminder_settings")
    }
}

// MARK: - 数据模型

/// 本地智能建议模型（用于视图内部）
struct LocalSmartSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let priority: Priority
    let actionable: Bool
    
    enum SuggestionType {
        case optimization
        case safety
        case recommendation
        case warning
        
        var icon: String {
            switch self {
            case .optimization: return "arrow.up.circle.fill"
            case .safety: return "shield.fill"
            case .recommendation: return "lightbulb.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .optimization: return .blue
            case .safety: return .green
            case .recommendation: return .yellow
            case .warning: return .orange
            }
        }
    }
    
    enum Priority {
        case high
        case medium
        case low
        
        var displayName: String {
            switch self {
            case .high: return "高"
            case .medium: return "中"
            case .low: return "低"
            }
        }
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .gray
            }
        }
    }
}

/// 提醒设置模型
struct ReminderSettings: Codable {
    var enableMissingItemsCheck = true
    var enableWeightPrediction = true
    var enableSmartSuggestions = true
    var checkFrequency = CheckFrequency.always
    var enableNotifications = false
    var notifyWeightLimit = true
    var notifyMissingItems = true
    var learnUserPreferences = true
    var rememberIgnoredSuggestions = true
    
    enum CheckFrequency: String, CaseIterable, Codable {
        case always = "always"
        case daily = "daily"
        case manual = "manual"
        
        var displayName: String {
            switch self {
            case .always: return "每次打开"
            case .daily: return "每日一次"
            case .manual: return "手动触发"
            }
        }
    }
}

// MARK: - 预览

struct SmartRemindersView_Previews: PreviewProvider {
    static var previews: some View {
        SmartRemindersView(
            checklist: [
                LuggageItem(id: UUID(), name: "T恤", volume: 500, weight: 200, category: .clothing, imagePath: nil, location: nil, note: nil),
                LuggageItem(id: UUID(), name: "牛仔裤", volume: 800, weight: 600, category: .clothing, imagePath: nil, location: nil, note: nil),
                LuggageItem(id: UUID(), name: "笔记本电脑", volume: 2000, weight: 1500, category: .electronics, imagePath: nil, location: nil, note: nil)
            ],
            luggage: Luggage(id: UUID(), name: "行李箱", capacity: 50000, emptyWeight: 3.5, imagePath: nil, items: [], note: nil, luggageType: .checked, selectedAirlineId: nil),
            travelPlan: TravelPlan(
                destination: "东京",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                season: "春季",
                activities: ["观光", "购物", "美食"]
            )
        )
    }
}
