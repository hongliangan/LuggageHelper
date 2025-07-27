import SwiftUI

/// AI 功能统一入口界面 - 智能行李管理中心
/// 
/// 这是 LuggageHelper v2.0 的核心 AI 功能入口，提供：
/// 
/// 🤖 AI 智能分析：
/// - 智能物品识别：名称/型号自动识别物品信息
/// - 批量物品分类：一键智能分类大量物品
/// - 照片识别：拍照即可获取物品详细信息
/// 
/// 🧠 智能优化：
/// - 装箱优化：AI 驱动的最优装箱方案
/// - 物品替代建议：智能推荐轻便替代品
/// - 重量预测：实时预测避免超重
/// 
/// 🌍 旅行助手：
/// - 智能旅行规划：个性化物品清单生成
/// - 航司政策查询：自动解读最新行李政策
/// - 遗漏物品提醒：基于目的地的智能提醒
/// - 个性化建议：基于历史数据的定制建议
/// 
/// ⚙️ 系统工具：
/// - 智能提醒设置：个性化提醒配置
/// - 替换设置：物品替代偏好管理
/// - API 配置：AI 服务配置和管理
/// 
/// 界面特点：
/// - 卡片式设计，功能分组清晰
/// - 实时配置状态检查
/// - 集成设置入口，一站式管理
struct AdvancedFeaturesView: View {
    @StateObject private var configManager = LLMConfigurationManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 配置状态提示
                    if !configManager.isConfigValid {
                        configurationBanner
                    }
                    
                    // 功能分组
                    aiAnalysisSection
                    smartOptimizationSection
                    travelAssistanceSection
                    systemToolsSection
                }
                .padding()
            }
            .navigationTitle("高级功能")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("设置") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AdvancedFeaturesSettingsView()
            }
        }
    }
    
    // MARK: - 配置横幅
    
    private var configurationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI功能需要配置")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("请先配置LLM API以使用智能功能")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("配置") {
                showingSettings = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemOrange).opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - AI分析功能
    
    private var aiAnalysisSection: some View {
        FeatureSection(
            title: "AI智能分析",
            subtitle: "利用人工智能分析和识别物品",
            icon: "brain.head.profile",
            iconColor: .purple
        ) {
            VStack(spacing: 12) {
                FeatureCard(
                    title: "重量预测",
                    description: "预测行李总重量并提供减重建议",
                    icon: "scalemass.circle.fill",
                    iconColor: .red,
                    destination: WeightPredictionPlaceholderView()
                )
                
                FeatureCard(
                    title: "个性化建议",
                    description: "基于历史数据的个性化出行建议",
                    icon: "person.circle.fill",
                    iconColor: .purple,
                    destination: PersonalizedTravelPlannerPlaceholderView()
                )
                
                FeatureCard(
                    title: "照片识别",
                    description: "拍照自动识别物品并填充信息",
                    icon: "camera.circle.fill",
                    iconColor: .orange,
                    destination: AIItemIdentificationView { _ in }
                )
            }
        }
    }
    
    // MARK: - 智能优化功能
    
    private var smartOptimizationSection: some View {
        FeatureSection(
            title: "智能优化",
            subtitle: "优化行李配置和空间利用",
            icon: "gearshape.2.fill",
            iconColor: .blue
        ) {
            VStack(spacing: 12) {
                FeatureCard(
                    title: "装箱优化",
                    description: "AI推荐最优装箱方案和摆放顺序",
                    icon: "cube.box.fill",
                    iconColor: .blue,
                    destination: PackingOptimizerPlaceholderView()
                )
                
                FeatureCard(
                    title: "物品替代建议",
                    description: "推荐更轻便的替代品优化重量",
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    iconColor: .orange,
                    destination: ReplacementSuggestionsPlaceholderView()
                )
                
                FeatureCard(
                    title: "重量预测",
                    description: "预测行李总重量并提供减重建议",
                    icon: "scalemass.fill",
                    iconColor: .red,
                    destination: WeightPredictionPlaceholderView()
                )
            }
        }
    }
    
    // MARK: - 旅行助手功能
    
    private var travelAssistanceSection: some View {
        FeatureSection(
            title: "旅行助手",
            subtitle: "个性化旅行建议和政策查询",
            icon: "airplane.circle.fill",
            iconColor: .green
        ) {
            VStack(spacing: 12) {
                FeatureCard(
                    title: "智能旅行规划",
                    description: "根据目的地生成个性化物品清单",
                    icon: "map.circle.fill",
                    iconColor: .green,
                    destination: AITravelPlannerView()
                )
                
                FeatureCard(
                    title: "航司政策查询",
                    description: "查询最新的航空公司行李政策",
                    icon: "airplane.circle.fill",
                    iconColor: .blue,
                    destination: AirlinePolicyView()
                )
                
                FeatureCard(
                    title: "遗漏物品提醒",
                    description: "智能检查可能遗漏的重要物品",
                    icon: "exclamationmark.bubble.circle.fill",
                    iconColor: .orange,
                    destination: MissingItemsCheckPlaceholderView()
                )
                
                FeatureCard(
                    title: "个性化建议",
                    description: "基于历史数据的个性化出行建议",
                    icon: "person.circle.fill",
                    iconColor: .purple,
                    destination: PersonalizedTravelPlannerPlaceholderView()
                )
            }
        }
    }
    
    // MARK: - 系统工具
    
    private var systemToolsSection: some View {
        FeatureSection(
            title: "系统工具",
            subtitle: "管理和配置AI功能",
            icon: "wrench.and.screwdriver.fill",
            iconColor: .gray
        ) {
            VStack(spacing: 12) {
                FeatureCard(
                    title: "智能提醒设置",
                    description: "配置智能提醒和通知偏好",
                    icon: "bell.circle.fill",
                    iconColor: .red,
                    destination: SmartRemindersPlaceholderView()
                )
                
                FeatureCard(
                    title: "替换设置",
                    description: "管理自动替换建议的设置",
                    icon: "gearshape.circle.fill",
                    iconColor: .gray,
                    destination: ReplacementSettingsPlaceholderView()
                )
                
                FeatureCard(
                    title: "API配置",
                    description: "配置LLM API和模型参数",
                    icon: "server.rack",
                    iconColor: .blue,
                    destination: APIConfigurationView()
                )
            }
        }
    }
}

// MARK: - 功能分组组件

struct FeatureSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分组标题
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 功能卡片
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 功能卡片组件

struct FeatureCard<Destination: View>: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let destination: Destination
    
    @StateObject private var configManager = LLMConfigurationManager.shared
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .opacity(configManager.isConfigValid ? 1.0 : 0.6)
        }
        .disabled(!configManager.isConfigValid)
    }
}

// MARK: - 占位符View

/// 装箱优化占位符View
struct PackingOptimizerPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.box.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("装箱优化")
                .font(.title)
                .fontWeight(.bold)
            
            Text("此功能需要选择具体的行李箱才能使用")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("请先在行李管理中创建行李箱，然后从行李箱详情页面访问装箱优化功能")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .navigationTitle("装箱优化")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 遗漏物品检查占位符View
struct MissingItemsCheckPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.bubble.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("遗漏物品提醒")
                .font(.title)
                .fontWeight(.bold)
            
            Text("此功能需要创建旅行清单才能使用")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("请先在旅行清单中创建出行计划，然后使用此功能检查可能遗漏的物品")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .navigationTitle("遗漏物品提醒")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 个性化旅行规划占位符View
struct PersonalizedTravelPlannerPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.purple)
            
            Text("个性化建议")
                .font(.title)
                .fontWeight(.bold)
            
            Text("基于您的历史数据提供个性化出行建议")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能包括：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• 基于历史出行记录的物品推荐")
                Text("• 个人偏好学习和优化")
                Text("• 智能行程规划建议")
                Text("• 个性化装箱方案")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Text("此功能正在开发中，敬请期待")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("个性化建议")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 重量预测占位符View
struct WeightPredictionPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "scalemass.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("重量预测")
                .font(.title)
                .fontWeight(.bold)
            
            Text("智能预测行李总重量并提供减重建议")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能包括：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• 实时重量计算和预测")
                Text("• 超重警告和减重建议")
                Text("• 重量优化的智能建议")
                Text("• 航司重量限制对比")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Text("请先在行李管理中添加物品，然后使用此功能进行重量预测")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("重量预测")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 物品替代建议占位符View
struct ReplacementSuggestionsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("物品替代建议")
                .font(.title)
                .fontWeight(.bold)
            
            Text("推荐更轻便的替代品优化重量和空间")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能包括：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• 基于功能的替代品搜索")
                Text("• 重量和体积对比分析")
                Text("• 替代品的自动替换")
                Text("• 功能差异说明")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Text("请先在行李管理中添加物品，然后使用此功能获取替代建议")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("物品替代建议")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 智能提醒设置占位符View
struct SmartRemindersPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("智能提醒设置")
                .font(.title)
                .fontWeight(.bold)
            
            Text("配置智能提醒和通知偏好")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能包括：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• 遗漏物品提醒设置")
                Text("• 出发前检查提醒")
                Text("• 重量超限警告")
                Text("• 个性化提醒偏好")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Text("此功能正在开发中，敬请期待")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("智能提醒设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 替换设置占位符View
struct ReplacementSettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("替换设置")
                .font(.title)
                .fontWeight(.bold)
            
            Text("管理自动替换建议的设置")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能包括：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• 自动替换开关")
                Text("• 替换建议阈值")
                Text("• 偏好品牌设置")
                Text("• 替换历史记录")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Text("此功能正在开发中，敬请期待")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("替换设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 预览

struct AdvancedFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedFeaturesView()
    }
}
