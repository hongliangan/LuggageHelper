import SwiftUI

// MARK: - 用户体验管理界面
struct UserExperienceManagementView: View {
    @StateObject private var errorHandler = ErrorHandlingService.shared
    @StateObject private var loadingManager = LoadingStateManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var undoRedoManager = UndoRedoManager.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // 错误管理
                ErrorManagementTab()
                    .tabItem {
                        Image(systemName: "exclamationmark.triangle")
                        Text("错误管理")
                    }
                    .tag(0)
                
                // 加载状态
                LoadingManagementTab()
                    .tabItem {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("加载状态")
                    }
                    .tag(1)
                
                // 网络监控
                NetworkManagementTab()
                    .tabItem {
                        Image(systemName: "network")
                        Text("网络监控")
                    }
                    .tag(2)
                
                // 操作历史
                UndoRedoManagementTab()
                    .tabItem {
                        Image(systemName: "arrow.uturn.backward")
                        Text("操作历史")
                    }
                    .tag(3)
                
                // 系统状态
                SystemStatusTab()
                    .tabItem {
                        Image(systemName: "info.circle")
                        Text("系统状态")
                    }
                    .tag(4)
            }
            .navigationTitle("用户体验管理")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 错误管理标签页
struct ErrorManagementTab: View {
    @StateObject private var errorHandler = ErrorHandlingService.shared
    
    var body: some View {
        List {
            // 当前错误
            if let currentError = errorHandler.currentError {
                Section("当前错误") {
                    ErrorCardView(
                        error: currentError,
                        onRetry: {
                            // 重试逻辑
                        },
                        onDismiss: {
                            errorHandler.clearError()
                        }
                    )
                }
            }
            
            // 错误统计
            Section("错误统计") {
                let stats = errorHandler.getErrorStatistics()
                
                StatRow(title: "总错误数", value: "\(stats.totalErrors)")
                StatRow(title: "24小时内", value: "\(stats.errorsLast24h)")
                StatRow(title: "本周内", value: "\(stats.errorsLastWeek)")
                
                if let mostCommon = stats.mostCommonError {
                    StatRow(title: "最常见错误", value: mostCommon.displayName)
                }
            }
            
            // 错误类型分布
            if !errorHandler.getErrorStatistics().typeDistribution.isEmpty {
                Section("错误类型分布") {
                    let distribution = errorHandler.getErrorStatistics().typeDistribution
                    
                    ForEach(Array(distribution.keys.sorted(by: { distribution[$0]! > distribution[$1]! })), id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 20)
                            
                            Text(type.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(distribution[type] ?? 0)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 错误历史
            Section("错误历史") {
                if errorHandler.errorHistory.isEmpty {
                    Text("暂无错误记录")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(Array(errorHandler.errorHistory.prefix(5)), id: \.id) { record in
                        ErrorHistoryRowView(record: record) {
                            // 显示错误详情
                        }
                    }
                    
                    if errorHandler.errorHistory.count > 5 {
                        NavigationLink("查看全部 \(errorHandler.errorHistory.count) 条记录") {
                            ErrorHistoryView()
                        }
                    }
                }
            }
            
            // 操作按钮
            Section("操作") {
                Button("清空错误历史") {
                    errorHandler.clearErrorHistory()
                }
                .foregroundColor(.red)
                .disabled(errorHandler.errorHistory.isEmpty)
                
                Button("导出错误日志") {
                    let log = errorHandler.exportErrorHistory()
                    // 分享日志
                }
                .disabled(errorHandler.errorHistory.isEmpty)
            }
        }
    }
}

// MARK: - 加载管理标签页
struct LoadingManagementTab: View {
    @StateObject private var loadingManager = LoadingStateManager.shared
    
    var body: some View {
        List {
            // 全局状态
            Section("全局状态") {
                HStack {
                    Circle()
                        .fill(loadingManager.globalLoadingState.color)
                        .frame(width: 16, height: 16)
                    
                    Text(loadingManager.globalLoadingState.displayName)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(loadingManager.activeOperations.count) 个活动操作")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 活动操作
            if !loadingManager.activeOperations.isEmpty {
                Section("活动操作") {
                    ForEach(loadingManager.activeOperations, id: \.id) { operation in
                        LoadingStateView(operation: operation) {
                            loadingManager.cancelOperation(operationId: operation.id)
                        }
                    }
                }
            }
            
            // 操作统计
            Section("操作统计") {
                let stats = loadingManager.getOperationStatistics()
                
                StatRow(title: "活动操作", value: "\(stats.activeOperations)")
                StatRow(title: "队列操作", value: "\(stats.queuedOperations)")
                StatRow(title: "平均进度", value: "\(Int(stats.averageProgress * 100))%")
            }
            
            // 操作类型分布
            if !loadingManager.getOperationStatistics().typeDistribution.isEmpty {
                Section("操作类型分布") {
                    let distribution = loadingManager.getOperationStatistics().typeDistribution
                    
                    ForEach(Array(distribution.keys.sorted(by: { distribution[$0]! > distribution[$1]! })), id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 20)
                            
                            Text(type.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(distribution[type] ?? 0)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 操作控制
            Section("操作控制") {
                Button("取消所有可取消操作") {
                    loadingManager.cancelAllCancellableOperations()
                }
                .foregroundColor(.red)
                .disabled(loadingManager.activeOperations.filter { $0.canCancel }.isEmpty)
                
                Button("清空队列") {
                    loadingManager.clearQueue()
                }
                .disabled(loadingManager.getOperationStatistics().queuedOperations == 0)
                
                Button("重置状态") {
                    loadingManager.reset()
                }
                .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - 网络管理标签页
struct NetworkManagementTab: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var connectionTest: NetworkConnectionTestResult?
    @State private var isTestingConnection = false
    
    var body: some View {
        List {
            // 连接状态
            Section("连接状态") {
                StatusRow(
                    title: "网络连接",
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
            
            // 连接统计
            Section("连接统计") {
                let stats = networkMonitor.getConnectionStatistics()
                
                StatRow(title: "总事件数", value: "\(stats.totalEvents)")
                StatRow(title: "24小时断开次数", value: "\(stats.disconnections24h)")
                StatRow(title: "24小时重连次数", value: "\(stats.reconnections24h)")
            }
            
            // 网络建议
            let recommendations = networkMonitor.getNetworkRecommendations()
            if !recommendations.isEmpty {
                Section("网络建议") {
                    ForEach(recommendations, id: \.id) { recommendation in
                        NetworkRecommendationRow(recommendation: recommendation)
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
}

// MARK: - 撤销重做管理标签页
struct UndoRedoManagementTab: View {
    @StateObject private var undoRedoManager = UndoRedoManager.shared
    
    var body: some View {
        List {
            // 操作控制
            Section("操作控制") {
                HStack {
                    Button("撤销") {
                        undoRedoManager.undo()
                    }
                    .disabled(!undoRedoManager.canUndo)
                    
                    Spacer()
                    
                    Button("重做") {
                        undoRedoManager.redo()
                    }
                    .disabled(!undoRedoManager.canRedo)
                }
                
                if let undoTitle = undoRedoManager.undoActionTitle {
                    Text("可撤销: \(undoTitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let redoTitle = undoRedoManager.redoActionTitle {
                    Text("可重做: \(redoTitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 历史统计
            Section("历史统计") {
                let stats = undoRedoManager.getHistoryStatistics()
                
                StatRow(title: "撤销栈大小", value: "\(stats.undoStackSize)")
                StatRow(title: "重做栈大小", value: "\(stats.redoStackSize)")
                StatRow(title: "内存使用", value: "\(stats.memoryUsage / 1024) KB")
            }
            
            // 操作类型分布
            if !undoRedoManager.getHistoryStatistics().actionTypeDistribution.isEmpty {
                Section("操作类型分布") {
                    let distribution = undoRedoManager.getHistoryStatistics().actionTypeDistribution
                    
                    ForEach(Array(distribution.keys.sorted(by: { distribution[$0]! > distribution[$1]! })), id: \.self) { type in
                        HStack {
                            Text(type)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(distribution[type] ?? 0)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 操作历史
            Section("操作历史") {
                let history = undoRedoManager.getActionHistory()
                
                if history.isEmpty {
                    Text("暂无操作历史")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(Array(history.prefix(10)), id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text(item.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(formatTimestamp(item.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if history.count > 10 {
                        Text("还有 \(history.count - 10) 条记录...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 管理操作
            Section("管理操作") {
                Button("清空历史") {
                    undoRedoManager.clearHistory()
                }
                .foregroundColor(.red)
                .disabled(undoRedoManager.getHistoryStatistics().undoStackSize == 0)
                
                Button("导出历史") {
                    let history = undoRedoManager.exportHistory()
                    // 分享历史
                }
                .disabled(undoRedoManager.getHistoryStatistics().undoStackSize == 0)
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 系统状态标签页
struct SystemStatusTab: View {
    @StateObject private var errorHandler = ErrorHandlingService.shared
    @StateObject private var loadingManager = LoadingStateManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var undoRedoManager = UndoRedoManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    var body: some View {
        List {
            // 系统概览
            Section("系统概览") {
                let errorStats = errorHandler.getErrorStatistics()
                let loadingStats = loadingManager.getOperationStatistics()
                let networkStats = networkMonitor.getConnectionStatistics()
                let undoStats = undoRedoManager.getHistoryStatistics()
                
                SystemStatusRow(
                    title: "错误状态",
                    value: errorStats.errorsLast24h == 0 ? "正常" : "\(errorStats.errorsLast24h) 个错误",
                    color: errorStats.errorsLast24h == 0 ? .green : .red
                )
                
                SystemStatusRow(
                    title: "加载状态",
                    value: loadingStats.globalState.displayName,
                    color: loadingStats.globalState.color
                )
                
                SystemStatusRow(
                    title: "网络状态",
                    value: networkMonitor.isConnected ? "已连接" : "未连接",
                    color: networkMonitor.isConnected ? .green : .red
                )
                
                SystemStatusRow(
                    title: "操作历史",
                    value: "\(undoStats.undoStackSize) 个操作",
                    color: .blue
                )
            }
            
            // 性能指标
            Section("性能指标") {
                let performanceReport = performanceMonitor.generatePerformanceReport()
                
                StatRow(title: "总请求数", value: "\(performanceReport.totalRequests)")
                StatRow(title: "成功率", value: "\(String(format: "%.1f", performanceReport.overallSuccessRate * 100))%")
                StatRow(title: "缓存命中率", value: "\(String(format: "%.1f", performanceReport.cacheHitRate * 100))%")
                StatRow(title: "平均响应时间", value: "\(String(format: "%.0f", performanceReport.averageResponseTime))ms")
                StatRow(title: "内存使用", value: "\(String(format: "%.1f", performanceReport.memoryUsage))MB")
            }
            
            // 性能警告
            let warnings = performanceMonitor.getPerformanceWarnings()
            if !warnings.isEmpty {
                Section("性能警告") {
                    ForEach(warnings, id: \.id) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(warning.severity.color))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(warning.message)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(severityText(for: warning.severity))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // 系统操作
            Section("系统操作") {
                Button("重置性能统计") {
                    performanceMonitor.resetStats()
                }
                .foregroundColor(.orange)
                
                Button("清理所有缓存") {
                    Task {
                        await AICacheManager.shared.clearAllCache()
                    }
                }
                .foregroundColor(.red)
                
                Button("导出系统报告") {
                    // 导出完整的系统状态报告
                }
            }
        }
    }
    
    private func severityText(for severity: PerformanceWarning.Severity) -> String {
        switch severity {
        case .low: return "信息"
        case .medium: return "警告"
        case .high: return "严重"
        case .critical: return "紧急"
        }
    }
}

// MARK: - 系统状态行组件
struct SystemStatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
        }
    }
}

#Preview {
    UserExperienceManagementView()
}