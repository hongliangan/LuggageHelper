import Foundation
import SwiftUI

// MARK: - 加载状态管理服务
@MainActor
class LoadingStateManager: ObservableObject {
    static let shared = LoadingStateManager()
    
    @Published var activeOperations: [LoadingOperation] = []
    @Published var globalLoadingState: GlobalLoadingState = .idle
    
    private var operationQueue: [LoadingOperation] = []
    private let maxConcurrentOperations = 3
    
    private init() {}
    
    // MARK: - 操作管理
    
    /// 开始加载操作
    func startOperation(
        id: String? = nil,
        type: OperationType,
        title: String,
        description: String? = nil,
        canCancel: Bool = false,
        estimatedDuration: TimeInterval? = nil,
        priority: OperationPriority = .normal
    ) -> LoadingOperation {
        let operation = LoadingOperation(
            id: id ?? UUID().uuidString,
            type: type,
            title: title,
            description: description,
            canCancel: canCancel,
            estimatedDuration: estimatedDuration,
            priority: priority
        )
        
        if activeOperations.count < maxConcurrentOperations {
            activeOperations.append(operation)
            updateGlobalState()
        } else {
            operationQueue.append(operation)
        }
        
        return operation
    }
    
    /// 更新操作进度
    func updateProgress(operationId: String, progress: Double, message: String? = nil) {
        if let index = activeOperations.firstIndex(where: { $0.id == operationId }) {
            activeOperations[index].progress = min(max(progress, 0.0), 1.0)
            if let message = message {
                activeOperations[index].currentStep = message
            }
            activeOperations[index].lastUpdated = Date()
        }
    }
    
    /// 完成操作
    func completeOperation(operationId: String, result: OperationResult? = nil) {
        if let index = activeOperations.firstIndex(where: { $0.id == operationId }) {
            var operation = activeOperations[index]
            operation.state = .completed
            operation.result = result
            operation.endTime = Date()
            
            activeOperations.remove(at: index)
            
            // 启动队列中的下一个操作
            startNextQueuedOperation()
            updateGlobalState()
        }
    }
    
    /// 取消操作
    func cancelOperation(operationId: String) {
        if let index = activeOperations.firstIndex(where: { $0.id == operationId }) {
            let operation = activeOperations[index]
            if operation.canCancel {
                activeOperations[index].state = .cancelled
                activeOperations.remove(at: index)
                
                // 通知取消
                NotificationCenter.default.post(
                    name: .operationCancelled,
                    object: nil,
                    userInfo: ["operationId": operationId]
                )
                
                startNextQueuedOperation()
                updateGlobalState()
            }
        }
    }
    
    /// 失败操作
    func failOperation(operationId: String, error: Error) {
        if let index = activeOperations.firstIndex(where: { $0.id == operationId }) {
            activeOperations[index].state = .failed
            activeOperations[index].error = error
            activeOperations[index].endTime = Date()
            
            activeOperations.remove(at: index)
            
            startNextQueuedOperation()
            updateGlobalState()
        }
    }
    
    // MARK: - 批量操作
    
    /// 开始批量操作
    func startBatchOperation(
        operations: [BatchOperationItem],
        title: String,
        description: String? = nil
    ) -> LoadingOperation {
        let batchOperation = LoadingOperation(
            id: UUID().uuidString,
            type: .batch,
            title: title,
            description: description,
            canCancel: true,
            estimatedDuration: operations.reduce(0) { $0 + ($1.estimatedDuration ?? 5.0) },
            priority: .normal
        )
        
        batchOperation.batchItems = operations
        batchOperation.totalBatchItems = operations.count
        
        activeOperations.append(batchOperation)
        updateGlobalState()
        
        return batchOperation
    }
    
    /// 更新批量操作进度
    func updateBatchProgress(operationId: String, completedItems: Int, currentItem: String? = nil) {
        if let index = activeOperations.firstIndex(where: { $0.id == operationId }) {
            let operation = activeOperations[index]
            if let totalItems = operation.totalBatchItems, totalItems > 0 {
                activeOperations[index].progress = Double(completedItems) / Double(totalItems)
                activeOperations[index].completedBatchItems = completedItems
                if let currentItem = currentItem {
                    activeOperations[index].currentStep = "正在处理: \(currentItem)"
                }
                activeOperations[index].lastUpdated = Date()
            }
        }
    }
    
    // MARK: - 队列管理
    
    private func startNextQueuedOperation() {
        guard !operationQueue.isEmpty,
              activeOperations.count < maxConcurrentOperations else { return }
        
        // 按优先级排序
        operationQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        let nextOperation = operationQueue.removeFirst()
        activeOperations.append(nextOperation)
    }
    
    private func updateGlobalState() {
        if activeOperations.isEmpty {
            globalLoadingState = .idle
        } else if activeOperations.contains(where: { $0.type == .critical }) {
            globalLoadingState = .critical
        } else if activeOperations.count >= maxConcurrentOperations {
            globalLoadingState = .busy
        } else {
            globalLoadingState = .loading
        }
    }
    
    // MARK: - 便捷方法
    
    /// AI操作加载
    func startAIOperation(title: String, description: String? = nil) -> LoadingOperation {
        return startOperation(
            type: .ai,
            title: title,
            description: description,
            canCancel: true,
            estimatedDuration: 5.0,
            priority: .normal
        )
    }
    
    /// 数据同步加载
    func startSyncOperation(title: String) -> LoadingOperation {
        return startOperation(
            type: .sync,
            title: title,
            canCancel: false,
            estimatedDuration: 3.0,
            priority: .high
        )
    }
    
    /// 文件操作加载
    func startFileOperation(title: String) -> LoadingOperation {
        return startOperation(
            type: .file,
            title: title,
            canCancel: true,
            estimatedDuration: 2.0,
            priority: .normal
        )
    }
    
    // MARK: - 状态查询
    
    /// 检查是否有指定类型的操作正在进行
    func hasActiveOperation(ofType type: OperationType) -> Bool {
        return activeOperations.contains { $0.type == type }
    }
    
    /// 获取指定类型的操作
    func getActiveOperations(ofType type: OperationType) -> [LoadingOperation] {
        return activeOperations.filter { $0.type == type }
    }
    
    /// 获取操作统计
    func getOperationStatistics() -> OperationStatistics {
        let totalActive = activeOperations.count
        let totalQueued = operationQueue.count
        
        var typeDistribution: [OperationType: Int] = [:]
        for operation in activeOperations {
            typeDistribution[operation.type, default: 0] += 1
        }
        
        let averageProgress = activeOperations.isEmpty ? 0.0 :
            activeOperations.reduce(0.0) { $0 + $1.progress } / Double(activeOperations.count)
        
        return OperationStatistics(
            activeOperations: totalActive,
            queuedOperations: totalQueued,
            typeDistribution: typeDistribution,
            averageProgress: averageProgress,
            globalState: globalLoadingState
        )
    }
    
    // MARK: - 清理方法
    
    /// 取消所有可取消的操作
    func cancelAllCancellableOperations() {
        let cancellableOperations = activeOperations.filter { $0.canCancel }
        for operation in cancellableOperations {
            cancelOperation(operationId: operation.id)
        }
    }
    
    /// 清空队列
    func clearQueue() {
        operationQueue.removeAll()
    }
    
    /// 重置所有状态
    func reset() {
        activeOperations.removeAll()
        operationQueue.removeAll()
        globalLoadingState = .idle
    }
}

// MARK: - 数据模型

/// 加载操作
class LoadingOperation: ObservableObject, Identifiable {
    let id: String
    let type: OperationType
    let title: String
    let description: String?
    let canCancel: Bool
    let estimatedDuration: TimeInterval?
    let priority: OperationPriority
    let startTime: Date
    
    @Published var state: OperationState = .running
    @Published var progress: Double = 0.0
    @Published var currentStep: String = ""
    @Published var lastUpdated: Date
    
    var endTime: Date?
    var result: OperationResult?
    var error: Error?
    
    // 批量操作相关
    var batchItems: [BatchOperationItem]?
    var totalBatchItems: Int?
    var completedBatchItems: Int = 0
    
    init(id: String, type: OperationType, title: String, description: String? = nil,
         canCancel: Bool = false, estimatedDuration: TimeInterval? = nil,
         priority: OperationPriority = .normal) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.canCancel = canCancel
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.startTime = Date()
        self.lastUpdated = Date()
    }
    
    /// 计算已用时间
    var elapsedTime: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    /// 计算预估剩余时间
    var estimatedRemainingTime: TimeInterval? {
        guard let estimatedDuration = estimatedDuration,
              progress > 0.0 && progress < 1.0 else { return nil }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let totalEstimatedTime = elapsedTime / progress
        return totalEstimatedTime - elapsedTime
    }
    
    /// 格式化剩余时间
    var formattedRemainingTime: String? {
        guard let remainingTime = estimatedRemainingTime else { return nil }
        
        if remainingTime < 60 {
            return String(format: "%.0f秒", remainingTime)
        } else {
            let minutes = Int(remainingTime / 60)
            let seconds = Int(remainingTime.truncatingRemainder(dividingBy: 60))
            return "\(minutes)分\(seconds)秒"
        }
    }
}

/// 操作类型
enum OperationType: String, CaseIterable {
    case ai = "ai"
    case sync = "sync"
    case file = "file"
    case network = "network"
    case batch = "batch"
    case critical = "critical"
    case background = "background"
    
    var displayName: String {
        switch self {
        case .ai: return "AI处理"
        case .sync: return "数据同步"
        case .file: return "文件操作"
        case .network: return "网络请求"
        case .batch: return "批量操作"
        case .critical: return "关键操作"
        case .background: return "后台任务"
        }
    }
    
    var icon: String {
        switch self {
        case .ai: return "brain.head.profile"
        case .sync: return "arrow.triangle.2.circlepath"
        case .file: return "doc.fill"
        case .network: return "network"
        case .batch: return "list.bullet"
        case .critical: return "exclamationmark.triangle.fill"
        case .background: return "moon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .ai: return .blue
        case .sync: return .green
        case .file: return .orange
        case .network: return .purple
        case .batch: return .indigo
        case .critical: return .red
        case .background: return .gray
        }
    }
}

/// 操作优先级
enum OperationPriority: Int, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .normal: return "普通"
        case .high: return "高"
        case .critical: return "紧急"
        }
    }
}

/// 操作状态
enum OperationState: String, CaseIterable {
    case queued = "queued"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .queued: return "排队中"
        case .running: return "进行中"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
    
    var color: Color {
        switch self {
        case .queued: return .orange
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

/// 全局加载状态
enum GlobalLoadingState: String, CaseIterable {
    case idle = "idle"
    case loading = "loading"
    case busy = "busy"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .loading: return "加载中"
        case .busy: return "繁忙"
        case .critical: return "关键操作"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .green
        case .loading: return .blue
        case .busy: return .orange
        case .critical: return .red
        }
    }
}

/// 操作结果
struct OperationResult {
    let success: Bool
    let message: String?
    let data: Any?
    
    init(success: Bool, message: String? = nil, data: Any? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}

/// 批量操作项
struct BatchOperationItem: Identifiable {
    let id = UUID()
    let title: String
    let estimatedDuration: TimeInterval?
    let data: Any?
    
    init(title: String, estimatedDuration: TimeInterval? = nil, data: Any? = nil) {
        self.title = title
        self.estimatedDuration = estimatedDuration
        self.data = data
    }
}

/// 操作统计
struct OperationStatistics {
    let activeOperations: Int
    let queuedOperations: Int
    let typeDistribution: [OperationType: Int]
    let averageProgress: Double
    let globalState: GlobalLoadingState
}

// MARK: - 通知扩展

extension Notification.Name {
    static let operationCancelled = Notification.Name("operationCancelled")
    static let operationCompleted = Notification.Name("operationCompleted")
    static let operationFailed = Notification.Name("operationFailed")
}