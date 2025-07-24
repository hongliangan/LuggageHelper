import SwiftUI

/// AI 旅行规划器视图
/// 用于生成基于目的地、季节和活动的旅行物品清单
struct AITravelPlannerView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    @StateObject private var aiViewModel = AIViewModel()
    
    @State private var destination = ""
    @State private var duration = 7
    @State private var season = "夏季"
    @State private var selectedActivities: Set<String> = []
    @State private var showingResults = false
    @State private var showingAddToLuggage = false
    @State private var selectedLuggage: Luggage?
    @State private var showingChecklistCreated = false
    
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
                
                // 生成按钮
                Section {
                    Button(action: {
                        Task {
                            await generateTravelChecklist()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if aiViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("生成旅行清单")
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
                    Section("建议物品 (\(suggestion.suggestedItems.count)件)") {
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
                                    }
                                }
                            }
                        }
                        
                        Button("添加到行李箱") {
                            showingAddToLuggage = true
                        }
                        .disabled(viewModel.luggages.isEmpty)
                        
                        // 添加这个新按钮
                        Button("创建出行清单") {
                            viewModel.addChecklistFromSuggestion(suggestion)
                            showingChecklistCreated = true
                        }
                        .buttonStyle(.borderedProminent)
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
                }
            }
            .navigationTitle("AI 旅行规划")
            .sheet(isPresented: $showingAddToLuggage) {
                addToLuggageView
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
            .alert("清单已创建", isPresented: $showingChecklistCreated) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("出行清单已成功创建，您可以在出行清单页面查看和管理。")
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
    
    /// 生成旅行清单
    private func generateTravelChecklist() async {
        guard !destination.isEmpty, !selectedActivities.isEmpty else {
            aiViewModel.errorMessage = "请输入目的地和至少一个活动类型"
            return
        }
        
        // 调用 AI 视图模型生成旅行建议
        await aiViewModel.generateTravelSuggestions(
            destination: destination,
            duration: duration,
            season: season,
            activities: Array(selectedActivities)
        )
        
        showingResults = aiViewModel.travelSuggestion != nil
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
}

struct AITravelPlannerView_Previews: PreviewProvider {
    static var previews: some View {
        AITravelPlannerView()
            .environmentObject(LuggageViewModel())
    }
}