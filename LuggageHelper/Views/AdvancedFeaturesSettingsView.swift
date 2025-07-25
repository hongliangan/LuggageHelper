import SwiftUI

/// 高级功能设置界面
struct AdvancedFeaturesSettingsView: View {
    @StateObject private var configManager = LLMConfigurationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("enableSmartReminders") private var enableSmartReminders = true
    @AppStorage("enableAutoReplacement") private var enableAutoReplacement = false
    @AppStorage("enableBatchProcessing") private var enableBatchProcessing = true
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("cacheExpirationDays") private var cacheExpirationDays = 7.0
    
    var body: some View {
        NavigationView {
            Form {
                // API配置状态
                apiConfigurationSection
                
                // 智能功能开关
                smartFeaturesSection
                
                // 缓存设置
                cacheSettingsSection
                
                // 使用统计
                usageStatisticsSection
                
                // 帮助与支持
                helpAndSupportSection
            }
            .navigationTitle("高级功能设置")
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
    
    // MARK: - API配置区域
    
    private var apiConfigurationSection: some View {
        Section("AI功能配置") {
            NavigationLink(destination: APIConfigurationView()) {
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundColor(.blue)
                    Text("LLM API配置")
                }
            }
            
            HStack {
                Image(systemName: configManager.isConfigValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(configManager.isConfigValid ? .green : .red)
                
                Text("配置状态")
                
                Spacer()
                
                Text(configManager.isConfigValid ? "已配置" : "未配置")
                    .foregroundColor(configManager.isConfigValid ? .green : .red)
                    .font(.caption)
            }
            
            if !configManager.isConfigValid {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    
                    Text("需要配置API密钥才能使用AI功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 智能功能区域
    
    private var smartFeaturesSection: some View {
        Section("智能功能") {
            Toggle(isOn: $enableSmartReminders) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("智能提醒")
                        Text("自动检查遗漏物品并提醒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Toggle(isOn: $enableAutoReplacement) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动替换建议")
                        Text("自动推荐更优的物品替代方案")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Toggle(isOn: $enableBatchProcessing) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("批量处理")
                        Text("支持批量物品识别和分类")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Toggle(isOn: $enableNotifications) {
                HStack {
                    Image(systemName: "app.badge")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("推送通知")
                        Text("接收AI建议和提醒通知")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 缓存设置区域
    
    private var cacheSettingsSection: some View {
        Section("缓存设置") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("缓存过期时间")
                    Spacer()
                    Text("\(Int(cacheExpirationDays))天")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $cacheExpirationDays, in: 1...30, step: 1) {
                    Text("缓存过期时间")
                } minimumValueLabel: {
                    Text("1天")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("30天")
                        .font(.caption)
                }
            }
            
            Button(action: clearCache) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("清理缓存")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - 使用统计区域
    
    private var usageStatisticsSection: some View {
        Section("使用统计") {
            StatisticRow(
                icon: "network",
                title: "API调用次数",
                value: "--",
                color: .blue
            )
            
            StatisticRow(
                icon: "speedometer",
                title: "缓存命中率",
                value: "--",
                color: .green
            )
            
            StatisticRow(
                icon: "clock.arrow.circlepath",
                title: "上次更新",
                value: "--",
                color: .orange
            )
            
            StatisticRow(
                icon: "checkmark.circle.fill",
                title: "识别成功率",
                value: "--",
                color: .purple
            )
        }
    }
    
    // MARK: - 帮助与支持区域
    
    private var helpAndSupportSection: some View {
        Section("帮助与支持") {
            NavigationLink(destination: AIFeaturesGuideView()) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                    Text("使用指南")
                }
            }
            
            NavigationLink(destination: AIFeaturesFAQView()) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("常见问题")
                }
            }
            
            Button(action: resetAllSettings) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.red)
                    Text("重置所有设置")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func clearCache() {
        // 实现清理缓存逻辑
        // 这里可以调用相关服务的清理方法
        print("清理缓存")
    }
    
    private func resetAllSettings() {
        enableSmartReminders = true
        enableAutoReplacement = false
        enableBatchProcessing = true
        enableNotifications = true
        cacheExpirationDays = 7.0
        
        // 清理缓存
        clearCache()
        
        print("重置所有设置")
    }
}

// MARK: - 统计行组件

struct StatisticRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// MARK: - 使用指南界面

struct AIFeaturesGuideView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                GuideSection(
                    title: "智能物品识别",
                    content: "输入物品名称或拍照，AI会自动识别物品的重量、体积等信息，大大简化物品录入过程。",
                    icon: "viewfinder.circle.fill",
                    color: .blue
                )
                
                GuideSection(
                    title: "装箱优化",
                    content: "AI会根据您的箱包尺寸和物品清单，推荐最优的装箱方案和摆放顺序，最大化空间利用率。",
                    icon: "cube.box.fill",
                    color: .green
                )
                
                GuideSection(
                    title: "旅行规划",
                    content: "根据目的地、季节、活动类型等信息，AI会生成个性化的物品携带建议，避免遗漏重要物品。",
                    icon: "map.circle.fill",
                    color: .orange
                )
                
                GuideSection(
                    title: "航司政策查询",
                    content: "实时查询各航空公司的最新行李政策，包括重量限制、尺寸要求等，避免额外费用。",
                    icon: "airplane.circle.fill",
                    color: .purple
                )
                
                GuideSection(
                    title: "物品替代建议",
                    content: "当物品过重或过大时，AI会推荐更轻便的替代品，帮助您优化行李配置。",
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    color: .red
                )
                
                GuideSection(
                    title: "智能提醒",
                    content: "基于您的旅行计划，AI会主动提醒可能遗漏的重要物品，确保出行无忧。",
                    icon: "bell.circle.fill",
                    color: .yellow
                )
            }
            .padding()
        }
        .navigationTitle("使用指南")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideSection: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 常见问题界面

struct AIFeaturesFAQView: View {
    private let faqs = [
        FAQ(
            question: "为什么需要配置API？",
            answer: "AI功能需要调用大语言模型API来提供智能分析和建议。您需要配置有效的API密钥才能使用这些功能。"
        ),
        FAQ(
            question: "AI识别的准确性如何？",
            answer: "AI识别的准确性取决于输入信息的详细程度。提供更具体的物品名称和型号可以获得更准确的结果。"
        ),
        FAQ(
            question: "数据会被上传到服务器吗？",
            answer: "只有必要的物品信息会发送给AI服务进行分析，不会上传个人隐私数据。所有数据都在本地存储。"
        ),
        FAQ(
            question: "如何提高建议质量？",
            answer: "提供详细的旅行信息（目的地、时长、活动类型等）可以帮助AI生成更准确的个性化建议。"
        ),
        FAQ(
            question: "可以离线使用吗？",
            answer: "AI功能需要网络连接才能工作。但已识别的物品信息会缓存在本地，可以离线查看。"
        ),
        FAQ(
            question: "如何节省API调用费用？",
            answer: "启用缓存功能可以减少重复的API调用。相同的查询会优先使用缓存结果，降低使用成本。"
        )
    ]
    
    var body: some View {
        List {
            ForEach(faqs, id: \.question) { faq in
                FAQRow(faq: faq)
            }
        }
        .navigationTitle("常见问题")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQ {
    let question: String
    let answer: String
}

struct FAQRow: View {
    let faq: FAQ
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(faq.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(faq.answer)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览

struct AdvancedFeaturesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedFeaturesSettingsView()
    }
}