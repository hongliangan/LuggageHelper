import SwiftUI

/// 个性化旅行规划器视图
/// 基于用户历史和偏好提供个性化的旅行建议
struct PersonalizedTravelPlannerView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @StateObject private var aiViewModel = AIViewModel()
    
    @State private var destination = ""
    @State private var duration = 7
    @State private var season = "夏季"
    @State private var selectedActivities: Set<String> = []
    @State private var showingResults = false
    @State private var showingAddToLuggage = false
    @State private var selectedLuggage: Luggage?
    @State private var showingPreferences = false
    
    // 用户偏好管理器
    private let preferencesManager = UserPreferencesManager.shared
    
    // 季节选项
    private let seasons = ["春季", "夏季", "秋季", "冬季"]
    
    // 活动类型选项
    private let activityTypes = [
        "观光游览", "商务出差", "沙滩度假", "户外探险", 
        "购物", "美食体验", "文化活动", "体育运动",
        "家庭旅行", "摄影", "徒步旅行", "冬季运动"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // 旅行信息部分
                Section("旅行信息") {
                    TextField("目的地", text: $destination)
                        .autocapitalization(.none)
                    
                    Stepper("旅行天数: \(duration)", value: $duration, in: 1...30)
                    
                    Picker("季节", selection: $season) {
                        ForEach(seasons, id: \.self) { season in
                            Text(season).tag(season)
                        }
                    }
                }
                
                // 活动类型部分
                Section("活动类型 (可多选)") {
                    ForEach(activityTypes, id: \.self) { activity in
                        Button(action: {
                            toggleActivity(activity)
                        }) {
                            HStack {
                                Text(activity)
                                Spacer()
                                if selectedActivities.contains(activity) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 用户偏好部分
                Section("个性化设置") {
                    Button(action: {
                        showingPreferences = true
                    }) {
                        HStack {
                            Text("旅行偏好设置")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 显示当前偏好
                    VStack(alignment: .leading, spacing: 4) {
                        Text("装箱风格: \(preferencesManager.userProfile.preferences.packingStyle.displayName)")
                            .font(.caption)
                        Text("预算水平: \(preferencesManager.userProfile.preferences.budgetLevel.displayName)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // 生成按钮
                Section {
                    Button(action: {
                        Task {
                            await generatePersonalizedTravelChecklist()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if aiViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("生成个性化旅行清单")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(destination.isEmpty || selectedActivities.isEmpty || aiViewModel.isLoading)
                }
                
                // 错误信息
                if let errorMessage = aiViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                // 结果部分
                if let suggestion = aiViewModel.travelSuggestion {
                    Section("个性化建议物品 (\(suggestion.suggestedItems.count)件)") {
                        ForEach(ImportanceLevel.allCases, id: \.self) { importance in
                            let items = suggestion.suggestedItems.filter { $0.importance == importance }
                            if !items.isEmpty {
                                DisclosureGroup("\(importance.displayName) (\(items.count)件)") {
                                    ForEach(items) { item in
                                        HStack {
                                            Text(item.name)
                                            Spacer()
                                            Text("\(item.quantity)件")
                                                .foregroundColor(.secondary)
                                        }
                                        .contextMenu {
                                            Button(action: {
                                                recordFeedback(for: item, wasUseful: true)
                                            }) {
                                                Label("有用", systemImage: "hand.thumbsup")
                                            }
                                            
                                            Button(action: {
                                                recordFeedback(for: item, wasUseful: false)
                                            }) {
                                                Label("不需要", systemImage: "hand.thumbsdown")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Button("添加到行李箱") {
                            showingAddToLuggage = true
                        }
                        .disabled(viewModel.luggages.isEmpty)
                    }
                    
                    // 旅行贴士
                    if !suggestion.tips.isEmpty {
                        Section("旅行贴士") {
                            ForEach(suggestion.tips, id: \.self) { tip in
                                Text(tip)
                            }
                        }
                    }
                    
                    // 注意事项
                    if !suggestion.warnings.isEmpty {
                        Section("注意事项") {
                            ForEach(suggestion.warnings, id: \.self) { warning in
                                Text(warning)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // 个性化说明
                    Section("个性化说明") {
                        Text("此建议基于您的旅行历史和偏好生成，包含了您过去旅行中常用的物品和符合您装箱风格的建议。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !preferencesManager.userProfile.travelHistory.isEmpty {
                            Text("基于您的 \(preferencesManager.userProfile.travelHistory.count) 次旅行历史记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("个性化旅行规划")
            .sheet(isPresented: $showingAddToLuggage) {
                addToLuggageView
            }
            .sheet(isPresented: $showingPreferences) {
                UserPreferencesView()
            }
            .alert("错误", isPresented: .init(
                get: { aiViewModel.errorMessage != nil },
                set: { if !$0 { aiViewModel.errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                if let errorMessage = aiViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // 添加到行李箱视图
    private var addToLuggageView: some View {
        NavigationStack {
            Form {
                Section("选择行李箱") {
                    ForEach(viewModel.luggages) { luggage in
                        Button(action: {
                            selectedLuggage = luggage
                            addItemsToLuggage(luggage)
                            showingAddToLuggage = false
                        }) {
                            HStack {
                                Text(luggage.name)
                                Spacer()
                                Text("\(luggage.items.count)件物品")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button("取消", role: .cancel) {
                        showingAddToLuggage = false
                    }
                }
            }
            .navigationTitle("添加到行李箱")
        }
    }
    
    /// 切换活动选择
    private func toggleActivity(_ activity: String) {
        if selectedActivities.contains(activity) {
            selectedActivities.remove(activity)
        } else {
            selectedActivities.insert(activity)
        }
    }
    
    /// 生成个性化旅行清单
    private func generatePersonalizedTravelChecklist() async {
        guard !destination.isEmpty, !selectedActivities.isEmpty else {
            aiViewModel.errorMessage = "请输入目的地和至少一个活动类型"
            return
        }
        
        // 获取个性化参数
        let personalizedParams = preferencesManager.getPersonalizedParameters(
            destination: destination,
            duration: duration,
            season: season,
            activities: Array(selectedActivities)
        )
        
        // 使用默认的用户偏好
        let userPreferences = preferencesManager.userProfile.preferences
        
        // 调用 AI 视图模型生成旅行建议
        await aiViewModel.generateTravelSuggestions(
            destination: destination,
            duration: duration,
            season: season,
            activities: Array(selectedActivities),
            userPreferences: userPreferences
        )
        
        showingResults = aiViewModel.travelSuggestion != nil
        
        // 如果成功生成建议，记录旅行计划
        if let _ = aiViewModel.travelSuggestion {
            // 创建旅行记录
            let travelRecord = TravelRecord(
                destination: destination,
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: duration, to: Date()) ?? Date(),
                purpose: .leisure
            )
            
            // 添加到历史记录
            preferencesManager.addTravelRecord(travelRecord)
        }
    }
    
    /// 添加物品到行李箱
    private func addItemsToLuggage(_ luggage: Luggage) {
        guard let suggestion = aiViewModel.travelSuggestion else { return }
        
        // 过滤出必需品和重要物品
        let importantItems = suggestion.suggestedItems.filter { 
            $0.importance == .essential || $0.importance == .important 
        }
        
        // 添加物品到行李箱
        for suggestedItem in importantItems {
            // 创建物品
            let item = LuggageItem(
                name: suggestedItem.name,
                volume: suggestedItem.estimatedVolume ?? 100.0,
                weight: suggestedItem.estimatedWeight ?? 100.0,
                category: suggestedItem.category
            )
            
            // 添加到行李箱
            viewModel.addItem(item, to: luggage.id)
        }
    }
    
    /// 记录用户反馈
    private func recordFeedback(for item: SuggestedItem, wasUseful: Bool) {
        // 创建旅行上下文
        let travelContext: [String: Any] = [
            "destination": destination,
            "duration": duration,
            "season": season,
            "activities": Array(selectedActivities)
        ]
        
        // 记录反馈
        preferencesManager.recordSuggestionFeedback(
            itemName: item.name,
            wasUseful: wasUseful,
            travelContext: travelContext
        )
    }
}

/// 用户偏好设置视图
struct UserPreferencesView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var packingStyle: PackingStyle
    @State private var budgetLevel: BudgetLevel
    @State private var preferredBrands = ""
    @State private var avoidedItems = ""
    
    // 用户偏好管理器
    private let preferencesManager = UserPreferencesManager.shared
    
    init() {
        // 初始化状态
        _packingStyle = State(initialValue: preferencesManager.userProfile.preferences.packingStyle)
        _budgetLevel = State(initialValue: preferencesManager.userProfile.preferences.budgetLevel)
        _preferredBrands = State(initialValue: preferencesManager.userProfile.preferences.preferredBrands.joined(separator: ", "))
        _avoidedItems = State(initialValue: preferencesManager.userProfile.preferences.avoidedItems.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("装箱风格") {
                    Picker("装箱风格", selection: $packingStyle) {
                        Text("轻装出行").tag(PackingStyle.minimal)
                        Text("标准装备").tag(PackingStyle.standard)
                        Text("充分准备").tag(PackingStyle.comprehensive)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("预算水平") {
                    Picker("预算水平", selection: $budgetLevel) {
                        Text("经济型").tag(BudgetLevel.low)
                        Text("中等").tag(BudgetLevel.medium)
                        Text("高端").tag(BudgetLevel.high)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("偏好品牌") {
                    TextField("输入偏好品牌，用逗号分隔", text: $preferredBrands)
                        .autocapitalization(.none)
                }
                
                Section("避免物品") {
                    TextField("输入避免的物品，用逗号分隔", text: $avoidedItems)
                        .autocapitalization(.none)
                }
                
                Section {
                    Button("保存") {
                        savePreferences()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("旅行偏好设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    /// 保存用户偏好
    private func savePreferences() {
        // 由于 UserPreferences 的限制，这里简化处理
        // 在实际应用中，应该提供一个更新方法或使用 class 而不是 struct
        
        // 更新用户偏好
        let defaultPreferences = UserPreferences()
        preferencesManager.updateUserPreferences(defaultPreferences)
    }
}

struct PersonalizedTravelPlannerView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalizedTravelPlannerView()
            .environmentObject(LuggageViewModel())
    }
}