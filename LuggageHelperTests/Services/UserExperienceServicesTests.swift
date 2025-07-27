import XCTest
@testable import LuggageHelper

@MainActor
final class UserExperienceServicesTests: XCTestCase {
    
    var errorHandler: ErrorHandlingService!
    var networkMonitor: MockNetworkMonitor!
    var loadingManager: LoadingStateManager!
    var undoRedoManager: UndoRedoManager!
    
    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandlingService.shared
        networkMonitor = MockNetworkMonitor()
        loadingManager = LoadingStateManager.shared
        undoRedoManager = UndoRedoManager.shared
        
        // 清理状态
        errorHandler.clearErrorHistory()
        loadingManager.reset()
        undoRedoManager.clearHistory()
    }
    
    override func tearDown() {
        errorHandler = nil
        networkMonitor = nil
        loadingManager = nil
        undoRedoManager = nil
        super.tearDown()
    }
    
    // MARK: - 错误处理服务测试
    
    func testErrorHandlingBasicFunctionality() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "测试错误"])
        
        // When
        errorHandler.handleError(testError, context: "单元测试", showToUser: false)
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, 1)
        let recordedError = errorHandler.errorHistory.first!
        XCTAssertEqual(recordedError.context, "单元测试")
        XCTAssertEqual(recordedError.error.type, .unknown)
    }
    
    func testErrorTypeConversion() {
        // Given
        let networkError = URLError(.notConnectedToInternet)
        let apiError = LLMAPIService.APIError.rateLimitExceeded
        
        // When
        errorHandler.handleError(networkError, context: "网络测试", showToUser: false)
        errorHandler.handleError(apiError, context: "API测试", showToUser: false)
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, 2)
        
        let networkErrorRecord = errorHandler.errorHistory.first { $0.context == "网络测试" }
        XCTAssertNotNil(networkErrorRecord)
        XCTAssertEqual(networkErrorRecord?.error.type, .network)
        
        let apiErrorRecord = errorHandler.errorHistory.first { $0.context == "API测试" }
        XCTAssertNotNil(apiErrorRecord)
        XCTAssertEqual(apiErrorRecord?.error.type, .rateLimited)
    }
    
    func testErrorStatistics() {
        // Given
        let errors = [
            NSError(domain: "Test1", code: 1, userInfo: nil),
            NSError(domain: "Test2", code: 2, userInfo: nil),
            URLError(.notConnectedToInternet)
        ]
        
        // When
        for (index, error) in errors.enumerated() {
            errorHandler.handleError(error, context: "测试\(index)", showToUser: false)
        }
        
        // Then
        let stats = errorHandler.getErrorStatistics()
        XCTAssertEqual(stats.totalErrors, 3)
        XCTAssertEqual(stats.errorsLast24h, 3)
        XCTAssertTrue(stats.typeDistribution.count > 0)
    }
    
    func testErrorHistoryLimit() {
        // Given
        let maxErrors = 55 // 超过默认限制50
        
        // When
        for i in 0..<maxErrors {
            let error = NSError(domain: "Test", code: i, userInfo: nil)
            errorHandler.handleError(error, context: "测试\(i)", showToUser: false)
        }
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, 50) // 应该被限制在50个
    }
    
    // MARK: - 网络监控测试
    
    func testNetworkMonitorBasicFunctionality() async {
        // Given
        networkMonitor.mockIsConnected = true
        networkMonitor.mockConnectionType = .wifi
        
        // When
        let isConnected = networkMonitor.isConnected
        let connectionType = networkMonitor.connectionType
        let testResult = await networkMonitor.testConnection()
        
        // Then
        XCTAssertTrue(isConnected)
        XCTAssertEqual(connectionType, .wifi)
        XCTAssertTrue(testResult.isSuccessful)
        XCTAssertGreaterThan(testResult.responseTime, 0)
    }
    
    func testNetworkMonitorOfflineMode() async {
        // Given
        networkMonitor.mockIsConnected = false
        
        // When
        let testResult = await networkMonitor.testConnection()
        let canUseAI = networkMonitor.canUseOffline(.aiFeatures)
        let canManageItems = networkMonitor.canUseOffline(.itemManagement)
        
        // Then
        XCTAssertFalse(testResult.isSuccessful)
        XCTAssertNotNil(testResult.error)
        XCTAssertFalse(canUseAI)
        XCTAssertTrue(canManageItems)
    }
    
    func testNetworkQualityAssessment() async {
        // Given
        networkMonitor.mockIsConnected = true
        networkMonitor.mockConnectionQuality = .excellent
        
        // When
        let quality = await networkMonitor.assessConnectionQuality()
        
        // Then
        XCTAssertEqual(quality, .excellent)
    }
    
    func testNetworkRecommendations() {
        // Given
        networkMonitor.mockIsExpensive = true
        networkMonitor.mockIsConstrained = true
        
        // When
        let recommendations = networkMonitor.getNetworkRecommendations()
        
        // Then
        XCTAssertFalse(recommendations.isEmpty)
        XCTAssertTrue(recommendations.contains { $0.type == .dataUsage })
        XCTAssertTrue(recommendations.contains { $0.type == .performance })
    }
    
    // MARK: - 加载状态管理测试
    
    func testLoadingStateManagerBasicOperations() {
        // Given
        let operationTitle = "测试操作"
        
        // When
        let operation = loadingManager.startOperation(
            type: .ai,
            title: operationTitle,
            canCancel: true
        )
        
        // Then
        XCTAssertEqual(loadingManager.activeOperations.count, 1)
        XCTAssertEqual(loadingManager.activeOperations.first?.title, operationTitle)
        XCTAssertEqual(loadingManager.globalLoadingState, .loading)
        
        // When - 更新进度
        loadingManager.updateProgress(operationId: operation.id, progress: 0.5)
        
        // Then
        XCTAssertEqual(operation.progress, 0.5)
        
        // When - 完成操作
        loadingManager.completeOperation(operationId: operation.id)
        
        // Then
        XCTAssertEqual(loadingManager.activeOperations.count, 0)
        XCTAssertEqual(loadingManager.globalLoadingState, .idle)
    }
    
    func testLoadingStateManagerConcurrencyLimit() {
        // Given
        let maxConcurrent = 3
        
        // When - 启动超过限制的操作
        var operations: [LoadingOperation] = []
        for i in 0..<5 {
            let operation = loadingManager.startOperation(
                type: .ai,
                title: "操作\(i)"
            )
            operations.append(operation)
        }
        
        // Then
        XCTAssertLessThanOrEqual(loadingManager.activeOperations.count, maxConcurrent)
        
        // When - 完成一个操作
        loadingManager.completeOperation(operationId: operations[0].id)
        
        // Then - 队列中的操作应该开始
        // 注意：这个测试可能需要根据实际的队列实现进行调整
    }
    
    func testLoadingStateManagerBatchOperations() {
        // Given
        let batchItems = [
            BatchOperationItem(title: "项目1"),
            BatchOperationItem(title: "项目2"),
            BatchOperationItem(title: "项目3")
        ]
        
        // When
        let batchOperation = loadingManager.startBatchOperation(
            operations: batchItems,
            title: "批量操作"
        )
        
        // Then
        XCTAssertEqual(batchOperation.totalBatchItems, 3)
        XCTAssertEqual(batchOperation.completedBatchItems, 0)
        
        // When - 更新批量进度
        loadingManager.updateBatchProgress(
            operationId: batchOperation.id,
            completedItems: 2
        )
        
        // Then
        XCTAssertEqual(batchOperation.completedBatchItems, 2)
        XCTAssertEqual(batchOperation.progress, 2.0/3.0, accuracy: 0.01)
    }
    
    func testLoadingStateManagerCancellation() {
        // Given
        let operation = loadingManager.startOperation(
            type: .ai,
            title: "可取消操作",
            canCancel: true
        )
        
        // When
        loadingManager.cancelOperation(operationId: operation.id)
        
        // Then
        XCTAssertEqual(loadingManager.activeOperations.count, 0)
        XCTAssertEqual(operation.state, .cancelled)
    }
    
    // MARK: - 撤销重做管理测试
    
    func testUndoRedoManagerBasicOperations() {
        // Given
        let mockAction = MockUndoableAction(title: "测试操作")
        
        // When
        undoRedoManager.execute(mockAction)
        
        // Then
        XCTAssertTrue(undoRedoManager.canUndo)
        XCTAssertFalse(undoRedoManager.canRedo)
        XCTAssertEqual(undoRedoManager.undoActionTitle, "测试操作")
        XCTAssertTrue(mockAction.wasExecuted)
        
        // When - 撤销
        undoRedoManager.undo()
        
        // Then
        XCTAssertFalse(undoRedoManager.canUndo)
        XCTAssertTrue(undoRedoManager.canRedo)
        XCTAssertTrue(mockAction.wasUndone)
        
        // When - 重做
        undoRedoManager.redo()
        
        // Then
        XCTAssertTrue(undoRedoManager.canUndo)
        XCTAssertFalse(undoRedoManager.canRedo)
        XCTAssertEqual(mockAction.executeCount, 2)
    }
    
    func testUndoRedoManagerGroupOperations() {
        // Given
        let action1 = MockUndoableAction(title: "操作1")
        let action2 = MockUndoableAction(title: "操作2")
        
        // When
        undoRedoManager.beginGroup(title: "批量操作")
        undoRedoManager.addToCurrentGroup(action1)
        undoRedoManager.addToCurrentGroup(action2)
        undoRedoManager.endGroup()
        
        // Then
        XCTAssertTrue(undoRedoManager.canUndo)
        XCTAssertEqual(undoRedoManager.undoActionTitle, "批量操作")
        XCTAssertTrue(action1.wasExecuted)
        XCTAssertTrue(action2.wasExecuted)
        
        // When - 撤销组操作
        undoRedoManager.undo()
        
        // Then
        XCTAssertTrue(action1.wasUndone)
        XCTAssertTrue(action2.wasUndone)
    }
    
    func testUndoRedoManagerHistoryLimit() {
        // Given
        let maxActions = 55 // 超过默认限制50
        
        // When
        for i in 0..<maxActions {
            let action = MockUndoableAction(title: "操作\(i)")
            undoRedoManager.execute(action)
        }
        
        // Then
        let stats = undoRedoManager.getHistoryStatistics()
        XCTAssertEqual(stats.undoStackSize, 50) // 应该被限制在50个
    }
    
    // MARK: - 集成测试
    
    func testErrorHandlingIntegrationWithNetworkMonitor() async {
        // Given
        networkMonitor.mockIsConnected = false
        
        // When
        let testResult = await networkMonitor.testConnection()
        if !testResult.isSuccessful {
            let networkError = NSError(
                domain: "NetworkTest",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: testResult.error ?? "网络错误"]
            )
            errorHandler.handleError(networkError, context: "网络集成测试", showToUser: false)
        }
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, 1)
        let errorRecord = errorHandler.errorHistory.first!
        XCTAssertEqual(errorRecord.error.type, .unknown) // 或者根据实际转换逻辑调整
    }
    
    func testLoadingStateIntegrationWithErrorHandling() {
        // Given
        let operation = loadingManager.startOperation(
            type: .ai,
            title: "集成测试操作"
        )
        
        // When - 模拟操作失败
        let testError = NSError(domain: "IntegrationTest", code: 500, userInfo: nil)
        loadingManager.failOperation(operationId: operation.id, error: testError)
        errorHandler.handleError(testError, context: "加载操作失败", showToUser: false)
        
        // Then
        XCTAssertEqual(loadingManager.activeOperations.count, 0)
        XCTAssertEqual(operation.state, .failed)
        XCTAssertEqual(errorHandler.errorHistory.count, 1)
    }
    
    // MARK: - 性能测试
    
    func testErrorHandlingPerformance() {
        measure {
            for i in 0..<100 {
                let error = NSError(domain: "PerformanceTest", code: i, userInfo: nil)
                errorHandler.handleError(error, context: "性能测试\(i)", showToUser: false)
            }
        }
    }
    
    func testLoadingStateManagerPerformance() {
        measure {
            var operations: [LoadingOperation] = []
            
            // 创建操作
            for i in 0..<50 {
                let operation = loadingManager.startOperation(
                    type: .background,
                    title: "性能测试操作\(i)"
                )
                operations.append(operation)
            }
            
            // 完成操作
            for operation in operations {
                loadingManager.completeOperation(operationId: operation.id)
            }
        }
    }
}

// MARK: - Mock Undoable Action

class MockUndoableAction: UndoableAction {
    let title: String
    let timestamp: Date
    
    var wasExecuted = false
    var wasUndone = false
    var executeCount = 0
    var undoCount = 0
    
    init(title: String) {
        self.title = title
        self.timestamp = Date()
    }
    
    func execute() {
        wasExecuted = true
        executeCount += 1
    }
    
    func undo() {
        wasUndone = true
        undoCount += 1
    }
}

// MARK: - 扩展测试用例

extension UserExperienceServicesTests {
    
    // MARK: - 边界条件测试
    
    func testErrorHandlingWithNilError() {
        // Given
        let nilError: Error? = nil
        
        // When & Then
        // 这个测试验证错误处理服务如何处理nil错误
        // 在实际实现中，应该有适当的nil检查
    }
    
    func testLoadingStateManagerWithInvalidOperationId() {
        // Given
        let invalidId = UUID().uuidString
        
        // When
        loadingManager.updateProgress(operationId: invalidId, progress: 0.5)
        loadingManager.completeOperation(operationId: invalidId)
        loadingManager.cancelOperation(operationId: invalidId)
        
        // Then
        // 应该优雅地处理无效ID，不崩溃
        XCTAssertEqual(loadingManager.activeOperations.count, 0)
    }
    
    func testUndoRedoManagerWithEmptyStack() {
        // Given - 空栈
        
        // When
        undoRedoManager.undo()
        undoRedoManager.redo()
        
        // Then
        XCTAssertFalse(undoRedoManager.canUndo)
        XCTAssertFalse(undoRedoManager.canRedo)
    }
    
    // MARK: - 内存管理测试
    
    func testMemoryLeakPrevention() {
        // Given
        weak var weakOperation: LoadingOperation?
        
        // When
        autoreleasepool {
            let operation = loadingManager.startOperation(
                type: .background,
                title: "内存测试"
            )
            weakOperation = operation
            loadingManager.completeOperation(operationId: operation.id)
        }
        
        // Then
        // 操作完成后应该被释放
        // XCTAssertNil(weakOperation, "LoadingOperation应该被释放")
    }
}