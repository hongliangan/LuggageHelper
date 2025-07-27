import SwiftUI

// MARK: - 网络状态指示器
struct NetworkStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 连接状态图标
            Image(systemName: networkMonitor.isConnected ? 
                  networkMonitor.connectionType.icon : "wifi.slash")
                .foregroundColor(networkMonitor.isConnected ? .green : .red)
                .font(.caption)
            
            // 连接类型和状态
            Text(networkMonitor.isConnected ? 
                 networkMonitor.connectionType.displayName : "未连接")
                .font(.caption)
                .foregroundColor(networkMonitor.isConnected ? .primary : .red)
            
            // 网络质量指示器
            if networkMonitor.isConnected {
                NetworkQualityIndicator()
            }
            
            // 详情按钮
            Button(action: {
                showingDetails = true
            }) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingDetails) {
            NetworkDetailView()
        }
    }
}

// MARK: - 网络质量指示器
struct NetworkQualityIndicator: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var connectionQuality: ConnectionQuality = .poor
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(barColor(for: index))
                    .frame(width: 3, height: CGFloat(4 + index * 2))
                    .cornerRadius(1)
            }
        }
        .task {
            connectionQuality = await networkMonitor.assessConnectionQuality()
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let activeLevel = qualityLevel(connectionQuality)
        return index < activeLevel ? connectionQuality.color : Color(.systemGray4)
    }
    
    private func qualityLevel(_ quality: ConnectionQuality) -> Int {
        switch quality {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }
}

// MARK: - 网络详情视图
struct NetworkDetailView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @State private var connectionTest: NetworkConnectionTestResult?
    @State private var isTestingConnection = false
    
    var body: some View {
        NavigationView {
            List {
                // 当前状态
                Section("当前状态") {
                    StatusRow(
                        title: "连接状态",
                        value: networkMonitor.isConnected ? "已连接" : "未连接",
                        color: networkMonitor.isConnected ? .green : .red
                    )
                    
                    if networkMonitor.isConnected {
                        StatusRow(
                            title: "连接类型",
                            value: networkMonitor.connectionType.displayName,
                            color: .blue
                        )
                        
                        StatusRow(
                            title: "计费网络",
                            value: networkMonitor.isExpensive ? "是" : "否",
                            color: networkMonitor.isExpensive ? .orange : .green
                        )
                        
                        StatusRow(
                            title: "受限网络",
                            value: networkMonitor.isConstrained ? "是" : "否",
                            color: networkMonitor.isConstrained ? .orange : .green
                        )
                    }
                }
                
                // 连接测试
                Section("连接测试") {
                    Button(action: {
                        testConnection()
                    }) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            
                            Text("测试网络连接")
                        }
                    }
                    .disabled(isTestingConnection || !networkMonitor.isConnected)
                    
                    if let test = connectionTest {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: test.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(test.isSuccessful ? .green : .red)
                                
                                Text(test.isSuccessful ? "连接正常" : "连接异常")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(String(format: "%.0f", test.responseTime))ms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let error = test.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 网络建议
                let recommendations = networkMonitor.getNetworkRecommendations()
                if !recommendations.isEmpty {
                    Section("网络建议") {
                        ForEach(recommendations) { recommendation in
                            NetworkRecommendationRow(recommendation: recommendation)
                        }
                    }
                }
                
                // 离线功能
                Section("离线功能") {
                    let offlineFeatures = networkMonitor.getOfflineAvailableFeatures()
                    let onlineFeatures = networkMonitor.getOnlineRequiredFeatures()
                    
                    ForEach(OfflineFeature.allCases, id: \.self) { feature in
                        HStack {
                            Image(systemName: networkMonitor.canUseOffline(feature) ? 
                                  "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(networkMonitor.canUseOffline(feature) ? .green : .red)
                            
                            Text(feature.displayName)
                            
                            Spacer()
                            
                            Text(networkMonitor.canUseOffline(feature) ? "可离线使用" : "需要网络")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 连接统计
                Section("连接统计") {
                    let stats = networkMonitor.getConnectionStatistics()
                    
                    StatRow(title: "总事件数", value: "\(stats.totalEvents)")
                    StatRow(title: "24小时断开次数", value: "\(stats.disconnections24h)")
                    StatRow(title: "24小时重连次数", value: "\(stats.reconnections24h)")
                    StatRow(title: "当前连接时长", value: formatUptime(stats.currentUptime))
                }
            }
            .navigationTitle("网络状态")
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
    
    private func testConnection() {
        isTestingConnection = true
        
        Task {
            let result = await networkMonitor.testConnection()
            await MainActor.run {
                connectionTest = result
                isTestingConnection = false
            }
        }
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime / 3600)
        let minutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - 状态行组件
struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - 网络建议行组件
struct NetworkRecommendationRow: View {
    let recommendation: NetworkRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: iconForRecommendationType(recommendation.type))
                        .foregroundColor(colorForRecommendationType(recommendation.type))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(recommendation.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded && !recommendation.actions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议操作：")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(recommendation.actions.enumerated()), id: \.offset) { index, action in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .leading)
                            
                            Text(action)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.top, 4)
            }
        }
    }
    
    private func iconForRecommendationType(_ type: NetworkRecommendation.RecommendationType) -> String {
        switch type {
        case .connection: return "wifi.exclamationmark"
        case .dataUsage: return "chart.bar.fill"
        case .performance: return "speedometer"
        case .optimization: return "gear"
        }
    }
    
    private func colorForRecommendationType(_ type: NetworkRecommendation.RecommendationType) -> Color {
        switch type {
        case .connection: return .red
        case .dataUsage: return .orange
        case .performance: return .yellow
        case .optimization: return .blue
        }
    }
}

// MARK: - 网络状态横幅
struct NetworkStatusBanner: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var isVisible = true
    
    var body: some View {
        if !networkMonitor.isConnected && isVisible {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("网络连接断开")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("部分功能可能无法使用")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button("关闭") {
                    withAnimation {
                        isVisible = false
                    }
                }
                .font(.caption)
                .foregroundColor(.white)
            }
            .padding()
            .background(Color.red)
            .transition(.move(edge: .top))
        }
    }
}

// MARK: - 网络状态修饰符
struct NetworkAwareModifier: ViewModifier {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    let requiresNetwork: Bool
    let fallbackContent: AnyView?
    
    func body(content: Content) -> some View {
        Group {
            if requiresNetwork && !networkMonitor.isConnected {
                if let fallback = fallbackContent {
                    fallback
                } else {
                    ContentUnavailableView(
                        "需要网络连接",
                        systemImage: "wifi.slash",
                        description: Text("此功能需要网络连接才能使用")
                    )
                }
            } else {
                content
            }
        }
    }
}

extension View {
    func requiresNetwork(_ requires: Bool = true, fallback: AnyView? = nil) -> some View {
        modifier(NetworkAwareModifier(
            requiresNetwork: requires,
            fallbackContent: fallback
        ))
    }
}

#Preview {
    VStack(spacing: 20) {
        NetworkStatusView()
        
        NetworkStatusBanner()
        
        Text("示例内容")
            .requiresNetwork(true)
    }
    .padding()
}