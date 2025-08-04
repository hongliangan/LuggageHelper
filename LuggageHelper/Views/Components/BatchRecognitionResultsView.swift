import SwiftUI

/// 批量识别结果视图
/// 显示批量识别的详细结果，包括成功和失败的识别
struct BatchRecognitionResultsView: View {
    let result: BatchRecognitionResult
    let onItemSelected: (ItemInfo) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedTab: ResultTab = .successful
    @State private var showRetryOptions = false
    @State private var retryingObjects: Set<UUID> = []
    
    enum ResultTab: String, CaseIterable {
        case successful = "成功"
        case failed = "失败"
        case summary = "摘要"
        
        var icon: String {
            switch self {
            case .successful: return "checkmark.circle"
            case .failed: return "xmark.circle"
            case .summary: return "chart.bar"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部统计卡片
                summaryCard
                    .padding()
                
                // 标签选择器
                Picker("结果类型", selection: $selectedTab) {
                    ForEach(ResultTab.allCases, id: \.self) { tab in
                        HStack {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    successfulResultsView
                        .tag(ResultTab.successful)
                    
                    failedResultsView
                        .tag(ResultTab.failed)
                    
                    summaryView
                        .tag(ResultTab.summary)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("批量识别结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showRetryOptions = true }) {
                            Label("重试失败项", systemImage: "arrow.clockwise")
                        }
                        .disabled(result.failedObjects.isEmpty)
                        
                        Button(action: { shareResults() }) {
                            Label("分享结果", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showRetryOptions) {
            RetryOptionsView(
                failedObjects: result.failedObjects,
                onRetry: { objects in
                    retryRecognition(objects)
                    showRetryOptions = false
                },
                onDismiss: { showRetryOptions = false }
            )
        }
    }
    
    // MARK: - 摘要卡片
    private var summaryCard: some View {
        HStack(spacing: 20) {
            StatisticItem(
                title: "总计",
                value: "\(result.successfulRecognitions.count + result.failedObjects.count)",
                color: .blue,
                icon: "viewfinder"
            )
            
            StatisticItem(
                title: "成功",
                value: "\(result.successfulRecognitions.count)",
                color: .green,
                icon: "checkmark.circle"
            )
            
            StatisticItem(
                title: "失败",
                value: "\(result.failedObjects.count)",
                color: .red,
                icon: "xmark.circle"
            )
            
            StatisticItem(
                title: "成功率",
                value: "\(Int(result.successRate * 100))%",
                color: result.successRate >= 0.8 ? .green : (result.successRate >= 0.6 ? .orange : .red),
                icon: "percent"
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - 成功结果视图
    private var successfulResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if result.successfulRecognitions.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "没有成功的识别",
                        subtitle: "所有物品识别都失败了"
                    )
                } else {
                    ForEach(result.successfulRecognitions) { item in
                        SuccessfulRecognitionCard(
                            item: item,
                            onSelect: { onItemSelected(item) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 失败结果视图
    private var failedResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if result.failedObjects.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle.fill",
                        title: "所有物品识别成功！",
                        subtitle: "没有失败的识别项目"
                    )
                } else {
                    ForEach(Array(result.failedObjects.enumerated()), id: \.element.id) { index, failedObject in
                        FailedRecognitionCard(
                            object: failedObject,
                            index: index + 1,
                            isRetrying: retryingObjects.contains(failedObject.id),
                            onRetry: { retryRecognition([failedObject]) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 摘要视图
    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 性能指标
                performanceMetrics
                
                // 识别质量分布
                if !result.successfulRecognitions.isEmpty {
                    confidenceDistribution
                }
                
                // 类别统计
                if !result.successfulRecognitions.isEmpty {
                    categoryStatistics
                }
            }
            .padding()
        }
    }
    
    private var performanceMetrics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("性能指标")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                let totalObjects = result.successfulRecognitions.count + result.failedObjects.count
                let averageConfidence = result.successfulRecognitions.isEmpty ? 0 : result.successfulRecognitions.map { $0.confidence }.reduce(0, +) / Double(result.successfulRecognitions.count)
                
                MetricRow(
                    title: "平均置信度",
                    value: "\(String(format: "%.1f", averageConfidence * 100))%",
                    icon: "gauge"
                )
                
                MetricRow(
                    title: "处理时间",
                    value: formatProcessingTime(result.processingTime),
                    icon: "clock"
                )
                
                if totalObjects > 0 {
                    MetricRow(
                        title: "平均每项时间",
                        value: "\(String(format: "%.1f", result.processingTime / Double(totalObjects)))秒",
                        icon: "timer"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var confidenceDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("识别质量分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            ConfidenceDistributionChart(recognitions: result.successfulRecognitions)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var categoryStatistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("识别类别统计")
                .font(.headline)
                .fontWeight(.semibold)
            
            CategoryStatisticsView(recognitions: result.successfulRecognitions)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 辅助方法
    private func retryRecognition(_ objects: [DetectedObject]) {
        let objectIds = Set(objects.map { $0.id })
        retryingObjects.formUnion(objectIds)
        
        // TODO: 实现重试逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            retryingObjects.subtract(objectIds)
        }
    }
    
    private func shareResults() {
        // TODO: 实现分享功能
    }
    
    private func formatProcessingTime(_ time: TimeInterval) -> String {
        if time < 60 {
            return "\(String(format: "%.1f", time))秒"
        } else {
            let minutes = Int(time / 60)
            let seconds = Int(time.truncatingRemainder(dividingBy: 60))
            return "\(minutes)分\(seconds)秒"
        }
    }
}

// MARK: - 辅助组件

/// 统计项组件
struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 成功识别卡片
struct SuccessfulRecognitionCard: View {
    let item: ItemInfo
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 类别图标
            Text(item.category.icon)
                .font(.largeTitle)
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 识别信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(item.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    ConfidenceBadge(confidence: item.confidence, style: .compact)
                    Spacer()
                }
            }
            
            Spacer()
            
            Button("选择") {
                onSelect()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// 失败识别卡片
struct FailedRecognitionCard: View {
    let object: DetectedObject
    let index: Int
    let isRetrying: Bool
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            if let thumbnail = object.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .frame(width: 60, height: 60)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // 失败信息
            VStack(alignment: .leading, spacing: 4) {
                Text("物品 \(index)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("识别失败")
                    .font(.caption)
                    .foregroundColor(.red)
                
                HStack {
                    Text("置信度: \(String(format: "%.1f", object.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            if isRetrying {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

/// 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// 指标行
struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}



/// 置信度分布图表
struct ConfidenceDistributionChart: View {
    let recognitions: [ItemInfo]
    
    private var confidenceRanges: [(String, Int, Color)] {
        let high = recognitions.filter { $0.confidence >= 0.8 }.count
        let medium = recognitions.filter { $0.confidence >= 0.6 && $0.confidence < 0.8 }.count
        let low = recognitions.filter { $0.confidence < 0.6 }.count
        
        return [
            ("高 (≥80%)", high, .green),
            ("中 (60-79%)", medium, .orange),
            ("低 (<60%)", low, .red)
        ]
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(confidenceRanges, id: \.0) { range in
                HStack {
                    Circle()
                        .fill(range.2)
                        .frame(width: 12, height: 12)
                    
                    Text(range.0)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(range.1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(range.2)
                }
            }
        }
    }
}

/// 类别统计视图
struct CategoryStatisticsView: View {
    let recognitions: [ItemInfo]
    
    private var categoryStats: [(ItemCategory, Int)] {
        let grouped = Dictionary(grouping: recognitions) { $0.category }
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(categoryStats, id: \.0) { category, count in
                HStack {
                    Text(category.icon)
                        .font(.title3)
                    
                    Text(category.displayName)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

/// 重试选项视图
struct RetryOptionsView: View {
    let failedObjects: [DetectedObject]
    let onRetry: ([DetectedObject]) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedObjects: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择要重试的物品")
                    .font(.headline)
                
                List {
                    ForEach(Array(failedObjects.enumerated()), id: \.element.id) { index, object in
                        HStack {
                            if let thumbnail = object.thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            VStack(alignment: .leading) {
                                Text("物品 \(index + 1)")
                                    .font(.subheadline)
                                
                                Text("置信度: \(String(format: "%.1f", object.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedObjects.contains(object.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedObjects.contains(object.id) {
                                selectedObjects.remove(object.id)
                            } else {
                                selectedObjects.insert(object.id)
                            }
                        }
                    }
                }
                
                HStack {
                    Button("全选") {
                        selectedObjects = Set(failedObjects.map { $0.id })
                    }
                    .buttonStyle(.bordered)
                    
                    Button("清除") {
                        selectedObjects.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("重试选中") {
                        let objectsToRetry = failedObjects.filter { selectedObjects.contains($0.id) }
                        onRetry(objectsToRetry)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedObjects.isEmpty)
                }
                .padding()
            }
            .navigationTitle("重试选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct BatchRecognitionResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSuccessfulItems = [
            ItemInfo(name: "T-Shirt", category: .clothing, weight: 150, volume: 500, confidence: 0.95),
            ItemInfo(name: "iPhone 15", category: .electronics, weight: 180, volume: 100, confidence: 0.88)
        ]
        
        let mockFailedObjects = [
            DetectedObject(boundingBox: .zero, confidence: 0.45, category: .other, thumbnail: UIImage(systemName: "questionmark.diamond")),
            DetectedObject(boundingBox: .zero, confidence: 0.30, category: .other, thumbnail: UIImage(systemName: "questionmark.diamond"))
        ]
        
        let mockResult = BatchRecognitionResult(
            taskId: UUID(),
            originalImage: UIImage(systemName: "photo.stack") ?? UIImage(),
            successful: mockSuccessfulItems,
            failed: mockFailedObjects,
            processingTime: 15.5
        )
        
        BatchRecognitionResultsView(
            result: mockResult,
            onItemSelected: { _ in print("Item selected") },
            onDismiss: { print("Dismissed") }
        )
    }
}
#endif