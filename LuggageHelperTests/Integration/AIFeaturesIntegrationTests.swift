import XCTest
@testable import LuggageHelper

@MainActor
final class AIFeaturesIntegrationTests: XCTestCase {
    
    var mockService: MockLLMAPIService!
    var mockNetworkMonitor: MockNetworkMonitor!
    var mockCacheManager: MockAICacheManager!
    var errorHandler: ErrorHandlingService!
    var loadingManager: LoadingStateManager!
    var performanceMonitor: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        
        // 初始化Mock服务
        mockService = MockLLMAPIService()
        mockNetworkMonitor = MockNetworkMonitor()
        mockCacheManager = MockAICacheManager()
        
        // 初始化真实服务
        errorHandler = ErrorHandlingService.shared
        loadingManager = LoadingStateManager.shared
        performanceMonitor = PerformanceMonitor.shared
        
        // 清理状态
        mockService.reset()
        errorHandler.clearErrorHistory()
        loadingManager.reset()
        performanceMonitor.resetStats()
    }
    
    override func tearDown() {
        mockService = nil
        mockNetworkMonitor = nil
        mockCacheManager = nil
        errorHandler = nil
        loadingManager = nil
        performanceMonitor = nil
        super.tearDown()
    }
    
    // MARK: - 端到端物品识别流程测试
    
    func testEndToEndItemIdentificationFlow() async throws {
        // Given
        let itemName = "iPhone 15 Pro"
        let model = "256GB"
        
        let expectedItem = ItemInfo(
            name: itemName,
            category: .electronics,
            weight: 221.0,
            volume: 150.0,
            confidence: 0.95,
            source: "AI识别"
        )
        mockService.mockItemInfo = expectedItem
        
        // When - 执行完整的识别流程
        let operationId = UUID()
        await performanceMonitor.startRequest(id: operationId, type: .itemIdentification)
        
        do {
            let result = try await mockService.identifyItemWithCache(name: itemName, model: model)
            
            // Then - 验证结果
            XCTAssertEqual(result.name, expectedItem.name)
            XCTAssertEqual(result.category, expectedItem.category)
            XCTAssertEqual(result.weight, expectedItem.weight, accuracy: 0.1)
            
            // 验证性能监控
            await performanceMonitor.endRequest(id: operationId, type: .itemIdentification, fromCache: false)
            
            let report = performanceMonitor.generatePerformanceReport()
            XCTAssertEqual(report.totalRequests, 1)
            XCTAssertEqual(report.successfulRequests, 1)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: operationId, type: .itemIdentification, error: error)
            XCTFail("物品识别流程失败: \(error)")
        }
    }
    
    // MARK: - 网络状态集成测试
    
    func testNetworkAwareAIOperations() async throws {
        // Given - 网络连接正常
        mockNetworkMonitor.mockIsConnected = true
        mockNetworkMonitor.mockConnectionType = .wifi
        
        // When - 执行AI操作
        if mockNetworkMonitor.isConnected {
            let result = try await mockService.identifyItemWithCache(name: "网络测试物品")
            XCTAssertNotNil(result)
        }
        
        // Given - 网络断开
        mockNetworkMonitor.mockIsConnected = false
        
        // When - 尝试执行AI操作
        if !mockNetworkMonitor.isConnected {
            // 应该显示离线提示或使用缓存
            let canUseOffline = mockNetworkMonitor.canUseOffline(.aiFeatures)
            XCTAssertFalse(canUseOffline, "AI功能不应该支持离线使用")
            
            // 模拟网络错误
            mockService.shouldSucceed = false
            mockService.mockError = MockError.networkError
            
            do {
                _ = try await mockService.identifyItemWithCache(name: "离线测试物品")
                XCTFail("离线状态下AI操作应该失败")
            } catch {
                // 验证错误被正确处理
                errorHandler.handleError(error, context: "网络集成测试", showToUser: false)
                XCTAssertEqual(errorHandler.errorHistory.count, 1)
            }
        }
    }
    
    // MARK: - 缓存集成测试
    
    func testCacheIntegrationWithAIService() async throws {
        // Given
        let itemName = "缓存集成测试物品"
        let request = ItemIdentificationRequest(name: itemName, model: nil)
        
        // When - 第一次调用（应该调用AI服务）
        let result1 = try await mockService.identifyItemWithCache(name: itemName)
        XCTAssertEqual(mockService.callCount, 1)
        
        // 手动缓存结果
        mockCacheManager.cacheItemIdentification(request: request, response: result1)
        
        // When - 第二次调用（应该从缓存获取）
        if let cachedResult = mockCacheManager.getCachedItemIdentification(for: request) {
            XCTAssertEqual(cachedResult.name, result1.name)
            
            // 验证缓存命中
            await performanceMonitor.recordCacheHit(type: .itemIdentification, size: MemoryLayout<ItemInfo>.size)
        } else {
            XCTFail("缓存应该命中")
        }
        
        // Then - 验证缓存统计
        let cacheStats = mockCacheManager.getCacheStatistics()
        XCTAssertGreaterThan(cacheStats.totalEntries, 0)
    }
    
    // MARK: - 错误处理集成测试
    
    func testErrorHandlingIntegration() async throws {
        // Given - 设置各种错误场景
        let errorScenarios: [(MockError, AppError.ErrorType)] = [
            (.networkError, .network),
            (.configurationError, .configuration),
            (.rateLimitError, .rateLimited)
        ]
        
        for (mockError, expectedType) in errorScenarios {
            // Given
            mockService.reset()
            mockService.shouldSucceed = false
            mockService.mockError = mockError
            
            // When
            do {
                _ = try await mockService.identifyItemWithCache(name: "错误测试物品")
                XCTFail("应该抛出错误")
            } catch {
                // Then - 验证错误处理
                errorHandler.handleError(error, context: "错误集成测试", showToUser: false)
                
                let lastError = errorHandler.errorHistory.first
                XCTAssertNotNil(lastError)
                // 注意：这里的断言可能需要根据实际的错误转换逻辑调整
            }
        }
        
        // 验证错误统计
        let errorStats = errorHandler.getErrorStatistics()
        XCTAssertEqual(errorStats.totalErrors, errorScenarios.count)
    }
    
    // MARK: - 加载状态集成测试
    
    func testLoadingStateIntegration() async throws {
        // Given
        let operationTitle = "集成测试AI操作"
        
        // When - 开始操作
        let operation = loadingManager.startOperation(
            type: .ai,
            title: operationTitle,
            canCancel: true,
            estimatedDuration: 2.0
        )
        
        XCTAssertEqual(loadingManager.activeOperations.count, 1)
        XCTAssertEqual(loadingManager.globalLoadingState, .loading)
        
        // When - 执行AI操作并更新进度
        Task {
            for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
                loadingManager.updateProgress(
                    operationId: operation.id,
                    progress: progress,
                    message: "处理进度 \(Int(progress * 100))%"
                )
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            // 执行实际的AI调用
            do {
                let result = try await mockService.identifyItemWithCache(name: "加载状态测试物品")
                
                // 完成操作
                loadingManager.completeOperation(
                    operationId: operation.id,
                    result: OperationResult(success: true, message: "识别完成", data: result)
                )
            } catch {
                // 操作失败
                loadingManager.failOperation(operationId: operation.id, error: error)
            }
        }
        
        // 等待操作完成
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // Then - 验证最终状态
        XCTAssertEqual(loadingManager.activeOperations.count, 0)
        XCTAssertEqual(loadingManager.globalLoadingState, .idle)
    }
    
    // MARK: - 批量操作集成测试
    
    func testBatchOperationIntegration() async throws {
        // Given
        let itemNames = ["物品1", "物品2", "物品3", "物品4", "物品5"]
        let batchItems = itemNames.map { BatchOperationItem(title: $0, estimatedDuration: 1.0) }
        
        // When - 开始批量操作
        let batchOperation = loadingManager.startBatchOperation(
            operations: batchItems,
            title: "批量物品识别",
            description: "正在识别多个物品"
        )
        
        XCTAssertEqual(batchOperation.totalBatchItems, itemNames.count)
        
        // When - 执行批量AI操作
        for (index, itemName) in itemNames.enumerated() {
            do {
                _ = try await mockService.identifyItemWithCache(name: itemName)
                
                // 更新批量进度
                loadingManager.updateBatchProgress(
                    operationId: batchOperation.id,
                    completedItems: index + 1,
                    currentItem: itemName
                )
                
            } catch {
                XCTFail("批量操作中的项目\(itemName)失败: \(error)")
            }
        }
        
        // 完成批量操作
        loadingManager.completeOperation(
            operationId: batchOperation.id,
            result: OperationResult(success: true, message: "批量识别完成")
        )
        
        // Then - 验证结果
        XCTAssertEqual(mockService.callCount, itemNames.count)
        XCTAssertEqual(batchOperation.completedBatchItems, itemNames.count)
        XCTAssertEqual(batchOperation.progress, 1.0, accuracy: 0.01)
    }
    
    // MARK: - 旅行规划集成测试
    
    func testTravelPlanningIntegration() async throws {
        // Given
        let destination = "巴黎"
        let duration = 7
        let season = "春季"
        let activities = ["观光", "购物", "美食"]
        
        let expectedSuggestion = TravelSuggestion(
            destination: destination,
            duration: duration,
            season: season,
            activities: activities,
            suggestedItems: [
                SuggestedItem(
                    name: "春装外套",
                    category: .clothing,
                    importance: .important,
                    reason: "巴黎春季多变天气",
                    quantity: 1,
                    estimatedWeight: 600.0,
                    estimatedVolume: 2500.0
                ),
                SuggestedItem(
                    name: "相机",
                    category: .electronics,
                    importance: .recommended,
                    reason: "记录美好旅程",
                    quantity: 1,
                    estimatedWeight: 800.0,
                    estimatedVolume: 1500.0
                )
            ],
            categories: [.clothing, .electronics, .toiletries],
            tips: ["准备欧元现金", "下载翻译应用"],
            warnings: ["注意扒手"]
        )
        mockService.mockTravelSuggestion = expectedSuggestion
        
        // When - 执行旅行规划流程
        let planningOperation = loadingManager.startOperation(
            type: .ai,
            title: "生成旅行建议",
            description: "为\(destination)\(duration)天行程生成建议"
        )
        
        do {
            let result = try await mockService.generateTravelSuggestionsWithCache(
                destination: destination,
                duration: duration,
                season: season,
                activities: activities
            )
            
            // Then - 验证结果
            XCTAssertEqual(result.destination, destination)
            XCTAssertEqual(result.duration, duration)
            XCTAssertEqual(result.suggestedItems.count, expectedSuggestion.suggestedItems.count)
            XCTAssertFalse(result.tips.isEmpty)
            
            // 完成操作
            loadingManager.completeOperation(
                operationId: planningOperation.id,
                result: OperationResult(success: true, message: "旅行建议生成完成", data: result)
            )
            
        } catch {
            loadingManager.failOperation(operationId: planningOperation.id, error: error)
            XCTFail("旅行规划集成测试失败: \(error)")
        }
    }
    
    // MARK: - 装箱优化集成测试
    
    func testPackingOptimizationIntegration() async throws {
        // Given - 创建测试数据
        let items = [
            createMockLuggageItem(name: "T恤", weight: 200, volume: 500),
            createMockLuggageItem(name: "牛仔裤", weight: 600, volume: 1200),
            createMockLuggageItem(name: "运动鞋", weight: 800, volume: 2000),
            createMockLuggageItem(name: "充电器", weight: 300, volume: 200),
            createMockLuggageItem(name: "洗漱包", weight: 400, volume: 800)
        ]
        let luggage = createMockLuggage()
        
        // When - 执行装箱优化
        let optimizationOperation = loadingManager.startOperation(
            type: .ai,
            title: "装箱优化",
            description: "为\(items.count)个物品优化装箱方案"
        )
        
        do {
            let result = try await mockService.optimizePackingWithCache(items: items, luggage: luggage)
            
            // Then - 验证结果
            XCTAssertEqual(result.luggageId, luggage.id)
            XCTAssertEqual(result.items.count, items.count)
            XCTAssertGreaterThan(result.efficiency, 0)
            XCTAssertLessThanOrEqual(result.efficiency, 1.0)
            
            // 验证重量和体积计算
            let expectedWeight = items.reduce(0) { $0 + $1.weight }
            let expectedVolume = items.reduce(0) { $0 + $1.volume }
            
            XCTAssertEqual(result.totalWeight, expectedWeight, accuracy: 0.1)
            XCTAssertEqual(result.totalVolume, expectedVolume, accuracy: 0.1)
            
            // 完成操作
            loadingManager.completeOperation(
                operationId: optimizationOperation.id,
                result: OperationResult(success: true, message: "装箱优化完成", data: result)
            )
            
        } catch {
            loadingManager.failOperation(operationId: optimizationOperation.id, error: error)
            XCTFail("装箱优化集成测试失败: \(error)")
        }
    }
    
    // MARK: - 性能监控集成测试
    
    func testPerformanceMonitoringIntegration() async throws {
        // Given
        let operationCount = 10
        
        // When - 执行多个操作并监控性能
        for i in 0..<operationCount {
            let operationId = UUID()
            await performanceMonitor.startRequest(id: operationId, type: .itemIdentification)
            
            do {
                _ = try await mockService.identifyItemWithCache(name: "性能监控测试物品\(i)")
                await performanceMonitor.endRequest(id: operationId, type: .itemIdentification, fromCache: false)
            } catch {
                await performanceMonitor.recordRequestFailure(id: operationId, type: .itemIdentification, error: error)
            }
        }
        
        // Then - 验证性能统计
        let report = performanceMonitor.generatePerformanceReport()
        XCTAssertEqual(report.totalRequests, operationCount)
        XCTAssertGreaterThan(report.overallSuccessRate, 0.8) // 至少80%成功率
        
        // 验证性能警告
        let warnings = performanceMonitor.getPerformanceWarnings()
        // 在正常情况下，不应该有严重的性能警告
        let criticalWarnings = warnings.filter { $0.severity == .critical || $0.severity == .high }
        XCTAssertEqual(criticalWarnings.count, 0, "不应该有严重的性能警告")
    }
    
    // MARK: - 完整用户流程集成测试
    
    func testCompleteUserWorkflowIntegration() async throws {
        // Given - 模拟完整的用户使用流程
        
        // 1. 用户添加物品并使用AI识别
        let itemName = "MacBook Pro"
        let identifyOperation = loadingManager.startAIOperation(
            title: "识别物品",
            description: "正在识别\(itemName)"
        )
        
        let identifiedItem = try await mockService.identifyItemWithCache(name: itemName)
        loadingManager.completeOperation(operationId: identifyOperation.id)
        
        // 2. 用户规划旅行并获取建议
        let travelOperation = loadingManager.startAIOperation(
            title: "生成旅行建议",
            description: "为商务出行生成建议"
        )
        
        let travelSuggestion = try await mockService.generateTravelSuggestionsWithCache(
            destination: "上海",
            duration: 3,
            season: "夏季",
            activities: ["商务会议", "客户拜访"]
        )
        loadingManager.completeOperation(operationId: travelOperation.id)
        
        // 3. 用户进行装箱优化
        let items = [createMockLuggageItem(name: identifiedItem.name, weight: identifiedItem.weight, volume: identifiedItem.volume)]
        let luggage = createMockLuggage()
        
        let packingOperation = loadingManager.startAIOperation(
            title: "装箱优化",
            description: "优化商务行李装箱"
        )
        
        let packingPlan = try await mockService.optimizePackingWithCache(items: items, luggage: luggage)
        loadingManager.completeOperation(operationId: packingOperation.id)
        
        // Then - 验证整个流程的结果
        XCTAssertNotNil(identifiedItem)
        XCTAssertNotNil(travelSuggestion)
        XCTAssertNotNil(packingPlan)
        
        // 验证所有操作都已完成
        XCTAssertEqual(loadingManager.activeOperations.count, 0)
        XCTAssertEqual(loadingManager.globalLoadingState, .idle)
        
        // 验证AI服务被正确调用
        XCTAssertEqual(mockService.callCount, 3) // 三次AI调用
        
        // 验证性能监控记录了所有操作
        let performanceReport = performanceMonitor.generatePerformanceReport()
        XCTAssertGreaterThan(performanceReport.totalRequests, 0)
    }
    
    // MARK: - 辅助方法
    
    private func createMockLuggageItem(name: String, weight: Double, volume: Double) -> LuggageItem {
        return LuggageItem(
            id: UUID(),
            name: name,
            weight: weight,
            volume: volume,
            category: .other,
            dimensions: Dimensions(length: 10, width: 10, height: 10),
            location: .home("测试位置"),
            notes: "",
            photos: [],
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMockLuggage() -> Luggage {
        return Luggage(
            id: UUID(),
            name: "集成测试行李箱",
            type: .suitcase,
            capacity: 50000, // 50L
            emptyWeight: 3000, // 3kg
            weightLimit: 23000, // 23kg
            dimensions: Dimensions(length: 55, width: 40, height: 20),
            color: "黑色",
            brand: "测试品牌",
            location: .home("家中"),
            notes: "",
            photos: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}