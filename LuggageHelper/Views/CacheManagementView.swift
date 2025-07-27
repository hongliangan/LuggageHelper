import SwiftUI

struct CacheManagementView: View {
    @StateObject private var cacheManager = AICacheManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var showingClearConfirmation = false
    @State private var selectedCategory: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                // 缓存统计概览
                Section("缓存统计") {
                    CacheStatsCard()
                }
                
                // 性能监控
                Section("性能监控") {
                    PerformanceStatsCard()
                }
                
                // 缓存分类管理
                Section("缓存分类") {
                    CacheCategoriesView(selectedCategory: $selectedCategory)
                }
                
                // 缓存操作
                Section("缓存管理") {
                    CacheActionsView(
                        showingClearConfirmation: $showingClearConfirmation,
                        selectedCategory: $selectedCategory,
                        isLoading: $isLoading
                    )
                }
                
                // 性能警告
                if !performanceMonitor.getPerformanceWarnings().isEmpty {
                    Section("性能警告") {
                        PerformanceWarningsView()
                    }
                }
            }
            .navigationTitle("缓存管理")
            .refreshable {
                await refreshData()
            }
            .alert("清空缓存", isPresented: $showingClearConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认清空", role: .destructive) {
                    Task {
                        await clearCache()
                    }
                }
            } message: {
                if let category = selectedCategory {
                    Text("确定要清空 \(category) 类别的缓存吗？")
                } else {
                    Text("确定要清空所有缓存吗？这将删除所有已保存的AI响应数据。")
                }
            }
        }
    }
    
    private func refreshData() async {
        // 刷新缓存统计数据
        await cacheManager.clearExpiredEntries()
    }
    
    private func clearCache() async {
        isLoading = true
        defer { isLoading = false }
        
        if let category = selectedCategory {
            await cacheManager.clearCacheCategory(category)
        } else {
            await cacheManager.clearAllCache()
        }
        
        selectedCategory = nil
    }
}

// MARK: - 缓存统计卡片

struct CacheStatsCard: View {
    @StateObject private var cacheManager = AICacheManager.shared
    @State private var cacheStats: CacheStatistics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.blue)
                Text("缓存使用情况")
                    .font(.headline)
                Spacer()
                if let stats = cacheStats {
                    Text("\(String(format: "%.1f", stats.usagePercentage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let stats = cacheStats {
                VStack(spacing: 8) {
                    // 使用率进度条
                    ProgressView(value: stats.usagePercentage / 100.0) {
                        HStack {
                            Text(stats.formattedSize)
                            Spacer()
                            Text(stats.formattedMaxSize)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .tint(stats.usagePercentage > 80 ? .red : stats.usagePercentage > 60 ? .orange : .blue)
                    
                    // 详细统计
                    HStack {
                        VStack(alignment: .leading) {
                            Text("总条目")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stats.totalEntries)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("分类数量")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stats.categoryCounts.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
            } else {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            cacheStats = cacheManager.getCacheStatistics()
        }
    }
}

// MARK: - 性能统计卡片

struct PerformanceStatsCard: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.green)
                Text("性能统计")
                    .font(.headline)
                Spacer()
                Button("详细报告") {
                    // 显示详细性能报告
                }
                .font(.caption)
            }
            
            let report = performanceMonitor.generatePerformanceReport()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatItem(
                    title: "总请求",
                    value: "\(report.totalRequests)",
                    icon: "arrow.up.arrow.down"
                )
                
                StatItem(
                    title: "成功率",
                    value: "\(String(format: "%.1f", report.overallSuccessRate * 100))%",
                    icon: "checkmark.circle",
                    color: report.overallSuccessRate > 0.9 ? .green : .orange
                )
                
                StatItem(
                    title: "缓存命中率",
                    value: "\(String(format: "%.1f", report.cacheHitRate * 100))%",
                    icon: "bolt.circle",
                    color: report.cacheHitRate > 0.5 ? .blue : .orange
                )
                
                StatItem(
                    title: "平均响应",
                    value: "\(String(format: "%.0f", report.averageResponseTime))ms",
                    icon: "timer",
                    color: report.averageResponseTime < 2000 ? .green : .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    init(title: String, value: String, icon: String, color: Color = .primary) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - 缓存分类视图

struct CacheCategoriesView: View {
    @Binding var selectedCategory: String?
    @StateObject private var cacheManager = AICacheManager.shared
    @State private var cacheStats: CacheStatistics?
    
    var body: some View {
        VStack {
            if let stats = cacheStats {
                ForEach(Array(stats.categoryCounts.keys.sorted()), id: \.self) { category in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(categoryDisplayName(category))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        
                        Text("\(stats.categoryCounts[category] ?? 0) 条目")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("清空") {
                        selectedCategory = category
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .contentShape(Rectangle())
                }
            } else {
                ProgressView("加载分类信息...")
            }
        }
        .onAppear {
            cacheStats = cacheManager.getCacheStatistics()
        }
    }
    
    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "ai_cache_item_identification": return "物品识别"
        case "ai_cache_travel_suggestions": return "旅行建议"
        case "ai_cache_packing_optimization": return "装箱优化"
        case "ai_cache_photo_recognition": return "照片识别"
        case "ai_cache_alternatives": return "替代建议"
        case "ai_cache_airline_policies": return "航司政策"
        default: return category
        }
    }
}

// MARK: - 缓存操作视图

struct CacheActionsView: View {
    @Binding var showingClearConfirmation: Bool
    @Binding var selectedCategory: String?
    @Binding var isLoading: Bool
    @StateObject private var cacheManager = AICacheManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    isLoading = true
                    await cacheManager.clearExpiredEntries()
                    isLoading = false
                }
            }) {
                HStack {
                    Image(systemName: "trash.circle")
                    Text("清理过期缓存")
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isLoading)
            
            Button(action: {
                selectedCategory = nil
                showingClearConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("清空所有缓存")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .disabled(isLoading)
        }
    }
}

// MARK: - 性能警告视图

struct PerformanceWarningsView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    var body: some View {
        ForEach(performanceMonitor.getPerformanceWarnings()) { warning in
            HStack {
                Image(systemName: warningIcon(for: warning.severity))
                    .foregroundColor(warningColor(for: warning.severity))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(warning.message)
                        .font(.subheadline)
                    
                    Text(severityText(for: warning.severity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private func warningIcon(for severity: PerformanceWarning.Severity) -> String {
        switch severity {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    private func warningColor(for severity: PerformanceWarning.Severity) -> Color {
        switch severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
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

#Preview {
    CacheManagementView()
}