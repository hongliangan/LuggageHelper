import SwiftUI

// MARK: - 加载状态显示组件
struct LoadingStateView: View {
    let operation: LoadingOperation
    let onCancel: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // 操作类型图标和标题
            HStack {
                Image(systemName: operation.type.icon)
                    .foregroundColor(operation.type.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(operation.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let description = operation.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if operation.canCancel, let onCancel = onCancel {
                    Button("取消") {
                        onCancel()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // 进度条
            VStack(spacing: 8) {
                ProgressView(value: operation.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: operation.type.color))
                
                HStack {
                    Text("\(Int(operation.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let remainingTime = operation.formattedRemainingTime {
                        Text("剩余 \(remainingTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 当前步骤
            if !operation.currentStep.isEmpty {
                HStack {
                    Text(operation.currentStep)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            // 批量操作进度
            if let totalItems = operation.totalBatchItems, totalItems > 0 {
                HStack {
                    Text("进度: \(operation.completedBatchItems)/\(totalItems)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("已用时: \(formatElapsedTime(operation.elapsedTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 简化加载指示器
struct SimpleLoadingView: View {
    let title: String
    let subtitle: String?
    let showProgress: Bool
    let progress: Double
    
    init(title: String, subtitle: String? = nil, showProgress: Bool = false, progress: Double = 0.0) {
        self.title = title
        self.subtitle = subtitle
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if showProgress {
                ProgressView(value: progress)
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 全屏加载覆盖层
struct LoadingOverlayView: View {
    let operation: LoadingOperation
    let onCancel: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 加载动画
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: operation.type.color))
                
                // 操作信息
                VStack(spacing: 8) {
                    Text(operation.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    if let description = operation.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !operation.currentStep.isEmpty {
                        Text(operation.currentStep)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // 进度信息
                if operation.progress > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: operation.progress)
                            .frame(width: 200)
                            .progressViewStyle(LinearProgressViewStyle(tint: operation.type.color))
                        
                        HStack {
                            Text("\(Int(operation.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let remainingTime = operation.formattedRemainingTime {
                                Text("剩余 \(remainingTime)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 200)
                    }
                }
                
                // 取消按钮
                if operation.canCancel, let onCancel = onCancel {
                    Button("取消") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
        }
    }
}

// MARK: - 操作队列视图
struct OperationQueueView: View {
    @StateObject private var loadingManager = LoadingStateManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // 活动操作
                if !loadingManager.activeOperations.isEmpty {
                    Section("正在进行") {
                        ForEach(loadingManager.activeOperations) { operation in
                            OperationRowView(operation: operation) {
                                loadingManager.cancelOperation(operationId: operation.id)
                            }
                        }
                    }
                }
                
                // 全局状态
                Section("系统状态") {
                    HStack {
                        Circle()
                            .fill(loadingManager.globalLoadingState.color)
                            .frame(width: 12, height: 12)
                        
                        Text(loadingManager.globalLoadingState.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(loadingManager.activeOperations.count) 个活动操作")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 操作统计
                let stats = loadingManager.getOperationStatistics()
                Section("统计信息") {
                    StatRow(title: "活动操作", value: "\(stats.activeOperations)")
                    StatRow(title: "队列操作", value: "\(stats.queuedOperations)")
                    StatRow(title: "平均进度", value: "\(Int(stats.averageProgress * 100))%")
                }
            }
            .navigationTitle("操作队列")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消全部") {
                        loadingManager.cancelAllCancellableOperations()
                    }
                    .disabled(loadingManager.activeOperations.isEmpty)
                }
            }
        }
    }
}

// MARK: - 操作行视图
struct OperationRowView: View {
    let operation: LoadingOperation
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: operation.type.icon)
                    .foregroundColor(operation.type.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(operation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if !operation.currentStep.isEmpty {
                        Text(operation.currentStep)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(operation.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if operation.canCancel {
                        Button("取消") {
                            onCancel()
                        }
                        .font(.caption2)
                        .foregroundColor(.red)
                    }
                }
            }
            
            ProgressView(value: operation.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: operation.type.color))
            
            if let remainingTime = operation.formattedRemainingTime {
                HStack {
                    Text("剩余时间: \(remainingTime)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("已用时: \(formatElapsedTime(operation.elapsedTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 统计行视图
struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
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

// MARK: - 加载状态修饰符
struct LoadingStateModifier: ViewModifier {
    let isLoading: Bool
    let title: String
    let subtitle: String?
    let canCancel: Bool
    let onCancel: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                SimpleLoadingView(
                    title: title,
                    subtitle: subtitle
                )
            }
        }
    }
}

extension View {
    func loadingState(
        isLoading: Bool,
        title: String,
        subtitle: String? = nil,
        canCancel: Bool = false,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(LoadingStateModifier(
            isLoading: isLoading,
            title: title,
            subtitle: subtitle,
            canCancel: canCancel,
            onCancel: onCancel
        ))
    }
}

#Preview {
    let sampleOperation = LoadingOperation(
        id: "sample",
        type: .ai,
        title: "正在识别物品",
        description: "使用AI分析物品信息",
        canCancel: true,
        estimatedDuration: 10.0
    )
    sampleOperation.progress = 0.65
    sampleOperation.currentStep = "分析物品特征..."
    
    return LoadingStateView(operation: sampleOperation) {
        print("取消操作")
    }
}