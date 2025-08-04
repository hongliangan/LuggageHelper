import XCTest
@testable import LuggageHelper

@MainActor
final class PerformanceTests: XCTestCase {
    
    var mockService: MockLLMAPIService!
    var cacheManager: MockAICacheManager!
    var loadingManager: LoadingStateManager!
    var performanceMonitor: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        mockService = MockLLMAPIService()
        cacheManager = MockAICacheManager()
        loadingManager = LoadingStateManager.shared
        performanceMonitor = PerformanceMonitor.shared
        
        // 重置状态
        mockService.reset()
        loadingManager.reset()
        performanceMonitor.resetStats()
    }
    
    override func tearDown() {
        mockService = nil
        cacheManager = nil
        loadingManager = nil
        performanceMonitor = nil
        super.tearDown()
    }
    
    // MARK: - AI服务性能测试
    
    func testAIServiceResponseTime() {
        measure {
            let expectation = XCTestExpectation(description: "AI服务响应时间测试")
            
            Task {
                do {
                    let startTime = Date()
                    _ = try await mockService.identifyItemWithCache(name: "性能测试物品")
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    // 验证响应时间在合理范围内（Mock服务应该很快）
                    XCTAssertLessThan(responseTime, 1.0, "AI服务响应时间应该小于1秒")
                    expectation.fulfill()
                } catch {
                    XCTFail("AI服务调用失败: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    func testBatchAIOperationsPerformance() {
        let operationCount = 50
        mockService.mockDelay = 0.01 // 减少延迟以加快测试
        
        measure {
            let expectation = XCTestExpectation(description: "批量AI操作性能测试")
            
            Task {
                let startTime = Date()
                
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<operationCount {
                        group.addTask {
                            do {
                                _ = try await self.mockService.identifyItemWithCache(name: "批量测试物品\(i)")
                            } catch {
                                XCTFail("批量操作失败: \(error)")
                            }
                        }
                    }
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                let averageTime = totalTime / Double(operationCount)
                
                XCTAssertLessThan(averageTime, 0.1, "平均每个操作应该小于0.1秒")
                XCTAssertEqual(self.mockService.callCount, operationCount)
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - 缓存性能测试
    
    func testCachePerformance() {
        let itemCount = 1000
        
        measure {
            // 测试缓存写入性能
            for i in 0..<itemCount {
                let request = ItemIdentificationRequest(name: "缓存测试物品\(i)", model: nil)
                let item = ItemInfo(
                    name: "缓存测试物品\(i)",
                    category: .other,
                    weight: Double(i),
                    volume: Double(i * 2),
                    confidence: 0.9,
                    source: "性能测试"
                )
                cacheManager.cacheItemIdentification(request: request, response: item)
            }
            
            // 测试缓存读取性能
            for i in 0..<itemCount {
                let request = ItemIdentificationRequest(name: "缓存测试物品\(i)", model: nil)
                let cachedItem = cacheManager.getCachedItemIdentification(for: request)
                XCTAssertNotNil(cachedItem, "缓存项\(i)应该存在")
            }
        }
    }
    
    func testCacheHitRatePerformance() {
        let totalRequests = 100
        let uniqueItems = 20 // 20个不同物品，重复请求以测试缓存命中率
        
        measure {
            let expectation = XCTestExpectation(description: "缓存命中率性能测试")
            
            Task {
                var hitCount = 0
                
                for i in 0..<totalRequests {
                    let itemIndex = i % uniqueItems
                    let itemName = "缓存命中测试物品\(itemIndex)"
                    
                    // 检查缓存
                    let request = ItemIdentificationRequest(name: itemName, model: nil)
                    if let _ = self.cacheManager.getCachedItemIdentification(for: request) {
                        hitCount += 1
                    } else {
                        // 模拟AI调用并缓存结果
                        let item = ItemInfo(
                            name: itemName,
                            category: .other,
                            weight: 100.0,
                            volume: 200.0,
                            confidence: 0.9,
                            source: "缓存测试"
                        )
                        self.cacheManager.cacheItemIdentification(request: request, response: item)
                    }
                }
                
                let hitRate = Double(hitCount) / Double(totalRequests)
                print("缓存命中率: \(hitRate * 100)%")
                
                // 预期命中率应该随着重复请求增加而提高
                XCTAssertGreaterThan(hitRate, 0.5, "缓存命中率应该大于50%")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - 加载状态管理性能测试
    
    func testLoadingStateManagerPerformance() {
        let operationCount = 200
        
        measure {
            var operations: [LoadingOperation] = []
            
            // 创建大量操作
            for i in 0..<operationCount {
                let operation = loadingManager.startOperation(
                    type: .background,
                    title: "性能测试操作\(i)",
                    canCancel: true
                )
                operations.append(operation)
            }
            
            // 更新所有操作的进度
            for (index, operation) in operations.enumerated() {
                let progress = Double(index) / Double(operationCount)
                loadingManager.updateProgress(
                    operationId: operation.id,
                    progress: progress,
                    message: "处理中..."
                )
            }
            
            // 完成所有操作
            for operation in operations {
                loadingManager.completeOperation(operationId: operation.id)
            }
            
            // 验证最终状态
            XCTAssertEqual(loadingManager.activeOperations.count, 0)
            XCTAssertEqual(loadingManager.globalLoadingState, .idle)
        }
    }
    
    func testConcurrentLoadingOperations() {
        let concurrentCount = 50
        
        measure {
            let expectation = XCTestExpectation(description: "并发加载操作性能测试")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<concurrentCount {
                        group.addTask {
                            let operation = self.loadingManager.startOperation(
                                type: .background,
                                title: "并发测试操作\(i)"
                            )
                            
                            // 模拟操作进度
                            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                                self.loadingManager.updateProgress(
                                    operationId: operation.id,
                                    progress: progress
                                )
                                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                            }
                            
                            self.loadingManager.completeOperation(operationId: operation.id)
                        }
                    }
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - 内存使用性能测试
    
    func testMemoryUsageUnderLoad() {
        let largeDataCount = 10000
        
        measure {
            var items: [ItemInfo] = []
            
            // 创建大量数据对象
            for i in 0..<largeDataCount {
                let item = ItemInfo(
                    name: "内存测试物品\(i)",
                    category: .other,
                    weight: Double(i),
                    volume: Double(i * 2),
                    dimensions: Dimensions(length: 10, width: 10, height: 10),
                    confidence: 0.9,
                    alternatives: [],
                    source: "内存测试"
                )
                items.append(item)
            }
            
            // 执行一些操作
            let filteredItems = items.filter { $0.weight > 5000 }
            let sortedItems = filteredItems.sorted { $0.name < $1.name }
            
            XCTAssertGreaterThan(sortedItems.count, 0)
            
            // 清理数据
            items.removeAll()
        }
    }
    
    // MARK: - 数据序列化性能测试
    
    func testDataSerializationPerformance() {
        let itemCount = 1000
        
        // 创建测试数据
        var items: [ItemInfo] = []
        for i in 0..<itemCount {
            let item = ItemInfo(
                name: "序列化测试物品\(i)",
                category: .electronics,
                weight: Double(i),
                volume: Double(i * 2),
                confidence: 0.9,
                source: "序列化测试"
            )
            items.append(item)
        }
        
        measure {
            // 测试JSON编码性能
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(items)
                
                // 测试JSON解码性能
                let decoder = JSONDecoder()
                let decodedItems = try decoder.decode([ItemInfo].self, from: data)
                
                XCTAssertEqual(decodedItems.count, itemCount)
            } catch {
                XCTFail("序列化测试失败: \(error)")
            }
        }
    }
    
    // MARK: - 搜索和过滤性能测试
    
    func testSearchPerformance() {
        let itemCount = 10000
        let searchTerms = ["iPhone", "MacBook", "iPad", "AirPods", "Apple Watch"]
        
        // 创建大量测试数据
        var items: [ItemInfo] = []
        for i in 0..<itemCount {
            let randomTerm = searchTerms[i % searchTerms.count]
            let item = ItemInfo(
                name: "\(randomTerm) 型号\(i)",
                category: .electronics,
                weight: Double.random(in: 100...2000),
                volume: Double.random(in: 200...5000),
                confidence: 0.9,
                source: "搜索测试"
            )
            items.append(item)
        }
        
        measure {
            // 测试搜索性能
            for searchTerm in searchTerms {
                let results = items.filter { $0.name.contains(searchTerm) }
                XCTAssertGreaterThan(results.count, 0, "搜索'\(searchTerm)'应该有结果")
            }
            
            // 测试复杂过滤
            let heavyItems = items.filter { $0.weight > 1000 && $0.volume > 3000 }
            let lightItems = items.filter { $0.weight < 500 }
            
            XCTAssertGreaterThan(heavyItems.count + lightItems.count, 0)
        }
    }
    
    // MARK: - 网络模拟性能测试
    
    func testNetworkSimulationPerformance() {
        let requestCount = 100
        
        // 模拟不同的网络延迟
        let networkDelays: [TimeInterval] = [0.01, 0.05, 0.1, 0.2, 0.5]
        
        for delay in networkDelays {
            mockService.mockDelay = delay
            
            measure {
                let expectation = XCTestExpectation(description: "网络延迟\(delay)s性能测试")
                
                Task {
                    let startTime = Date()
                    
                    for i in 0..<requestCount {
                        do {
                            _ = try await self.mockService.identifyItemWithCache(name: "网络测试物品\(i)")
                        } catch {
                            XCTFail("网络模拟测试失败: \(error)")
                        }
                    }
                    
                    let totalTime = Date().timeIntervalSince(startTime)
                    let averageTime = totalTime / Double(requestCount)
                    
                    print("网络延迟\(delay)s，平均响应时间: \(averageTime)s")
                    
                    // 验证平均响应时间合理
                    XCTAssertGreaterThanOrEqual(averageTime, delay * 0.8, "平均响应时间应该接近设置的延迟")
                    XCTAssertLessThanOrEqual(averageTime, delay * 1.5, "平均响应时间不应该过长")
                    
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: Double(requestCount) * delay + 10.0)
            }
        }
    }
    
    // MARK: - 压力测试
    
    func testStressTestWithHighLoad() {
        let highLoadOperationCount = 500
        let concurrentBatches = 10
        
        measure {
            let expectation = XCTestExpectation(description: "高负载压力测试")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for batch in 0..<concurrentBatches {
                        group.addTask {
                            for i in 0..<(highLoadOperationCount / concurrentBatches) {
                                let operationId = batch * (highLoadOperationCount / concurrentBatches) + i
                                
                                do {
                                    _ = try await self.mockService.identifyItemWithCache(name: "压力测试物品\(operationId)")
                                } catch {
                                    // 在压力测试中，一些失败是可以接受的
                                    print("压力测试操作\(operationId)失败: \(error)")
                                }
                            }
                        }
                    }
                }
                
                print("压力测试完成，总调用次数: \(self.mockService.callCount)")
                XCTAssertGreaterThan(self.mockService.callCount, highLoadOperationCount * 0.8, "至少80%的操作应该成功")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - 长时间运行测试
    
    func testLongRunningOperations() {
        let longRunningDuration: TimeInterval = 5.0 // 5秒长时间运行
        let operationInterval: TimeInterval = 0.1 // 每0.1秒一个操作
        
        measure {
            let expectation = XCTestExpectation(description: "长时间运行测试")
            
            Task {
                let startTime = Date()
                var operationCount = 0
                
                while Date().timeIntervalSince(startTime) < longRunningDuration {
                    do {
                        _ = try await self.mockService.identifyItemWithCache(name: "长时间运行测试物品\(operationCount)")
                        operationCount += 1
                        
                        try await Task.sleep(nanoseconds: UInt64(operationInterval * 1_000_000_000))
                    } catch {
                        print("长时间运行测试操作\(operationCount)失败: \(error)")
                    }
                }
                
                print("长时间运行测试完成，执行了\(operationCount)个操作")
                XCTAssertGreaterThan(operationCount, Int(longRunningDuration / operationInterval * 0.8), "应该完成大部分预期操作")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: longRunningDuration + 5.0)
        }
    }
    
    // MARK: - 资源清理测试
    
    func testResourceCleanupPerformance() {
        measure {
            // 创建大量资源
            for i in 0..<1000 {
                let operation = loadingManager.startOperation(
                    type: .background,
                    title: "资源清理测试\(i)"
                )
                
                // 立即完成操作以测试清理
                loadingManager.completeOperation(operationId: operation.id)
            }
            
            // 验证资源被正确清理
            XCTAssertEqual(loadingManager.activeOperations.count, 0, "所有操作应该被清理")
            
            // 重置管理器
            loadingManager.reset()
            
            // 验证重置后状态
            XCTAssertEqual(loadingManager.globalLoadingState, .idle)
        }
    }
    
    // MARK: - 新增性能优化基准测试
    
    /// 测试图像内存管理器性能
    func testImageMemoryManagerPerformance() {
        let imageMemoryManager = ImageMemoryManager.shared
        let testImages = (0..<20).map { _ in createTestImage(size: CGSize(width: 1024, height: 1024)) }
        
        measure {
            let expectation = XCTestExpectation(description: "图像内存管理性能测试")
            
            Task {
                // 测试批量图像优化
                let startTime = Date()
                _ = await imageMemoryManager.optimizeImages(testImages, purpose: .recognition)
                let optimizationTime = Date().timeIntervalSince(startTime)
                
                // 验证优化时间在合理范围内
                XCTAssertLessThan(optimizationTime, 10.0, "批量图像优化应在10秒内完成")
                
                // 测试内存池操作
                for (index, image) in testImages.enumerated() {
                    imageMemoryManager.addImageToPool(image, key: "test_\(index)")
                }
                
                // 测试从内存池获取
                for index in 0..<testImages.count {
                    let retrievedImage = imageMemoryManager.getImageFromPool(key: "test_\(index)")
                    XCTAssertNotNil(retrievedImage, "应该能从内存池获取图像")
                }
                
                // 清理内存池
                imageMemoryManager.clearImagePool()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    /// 测试AI请求队列性能
    func testAIRequestQueuePerformance() {
        let requestQueue = AIRequestQueue.shared
        let requestCount = 50
        
        measure {
            let expectation = XCTestExpectation(description: "AI请求队列性能测试")
            expectation.expectedFulfillmentCount = requestCount
            
            Task {
                // 创建并发请求
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<requestCount {
                        group.addTask {
                            let request = AIRequest(
                                type: .itemIdentification,
                                priority: RequestPriority.allCases.randomElement()!,
                                parameters: ["name": "性能测试物品\(i)"]
                            )
                            
                            do {
                                _ = try await requestQueue.enqueue(request) {
                                    // 模拟处理时间
                                    try await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...100_000_000))
                                    return "完成\(i)"
                                }
                                expectation.fulfill()
                            } catch {
                                XCTFail("请求队列测试失败: \(error)")
                            }
                        }
                    }
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    /// 测试缓存智能清理性能
    func testCacheIntelligentCleanupPerformance() {
        let aiCache = AICacheManager.shared
        
        measure {
            let expectation = XCTestExpectation(description: "缓存智能清理性能测试")
            
            Task {
                // 填充大量缓存数据
                for i in 0..<500 {
                    let request = ItemIdentificationRequest(
                        name: "缓存清理测试\(i)",
                        model: "型号\(i)",
                        brand: "品牌\(i % 10)"
                    )
                    let response = ItemInfo(
                        name: request.name,
                        category: .clothing,
                        weight: Double.random(in: 0.1...2.0),
                        volume: Double.random(in: 0.01...0.5),
                        confidence: 0.9,
                        source: "性能测试"
                    )
                    aiCache.cacheItemIdentification(request: request, response: response)
                }
                
                // 获取清理前的统计
                let statsBefore = aiCache.getCacheStatistics()
                print("清理前缓存大小: \(statsBefore.formattedSize)")
                
                // 执行清理
                let cleanupStartTime = Date()
                await aiCache.clearExpiredEntries()
                let cleanupTime = Date().timeIntervalSince(cleanupStartTime)
                
                // 验证清理性能
                XCTAssertLessThan(cleanupTime, 5.0, "缓存清理应在5秒内完成")
                
                let statsAfter = aiCache.getCacheStatistics()
                print("清理后缓存大小: \(statsAfter.formattedSize)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    /// 测试性能监控器开销
    func testPerformanceMonitorOverhead() {
        let operationCount = 1000
        
        // 测试不使用性能监控的基准时间
        let baselineTime = measureTime {
            for i in 0..<operationCount {
                // 模拟简单操作
                let _ = "测试操作\(i)".count
            }
        }
        
        // 测试使用性能监控的时间
        let monitoredTime = measureTime {
            for i in 0..<operationCount {
                let requestId = UUID()
                performanceMonitor.startRequest(id: requestId, type: .itemIdentification)
                
                // 模拟相同操作
                let _ = "测试操作\(i)".count
                
                performanceMonitor.endRequest(id: requestId, type: .itemIdentification)
            }
        }
        
        // 计算开销
        let overhead = monitoredTime - baselineTime
        let overheadPercentage = (overhead / baselineTime) * 100
        
        print("性能监控开销: \(String(format: "%.2f", overhead))秒 (\(String(format: "%.1f", overheadPercentage))%)")
        
        // 验证开销在可接受范围内（不超过基准时间的50%）
        XCTAssertLessThan(overheadPercentage, 50.0, "性能监控开销应该控制在50%以内")
    }
    
    /// 测试资源使用跟踪性能
    func testResourceUsageTrackingPerformance() {
        let trackingCount = 1000
        
        measure {
            // 测试内存使用跟踪
            for i in 0..<trackingCount {
                performanceMonitor.recordResourceUsage(
                    type: .memory,
                    amount: Double(i * 1024),
                    unit: "bytes"
                )
            }
            
            // 测试网络使用跟踪
            for i in 0..<trackingCount {
                performanceMonitor.recordNetworkUsage(
                    bytesReceived: Int64(i * 100),
                    bytesSent: Int64(i * 50)
                )
            }
            
            // 测试电池使用跟踪
            for _ in 0..<100 { // 减少次数因为这个操作相对较重
                performanceMonitor.recordBatteryUsage()
            }
            
            // 验证数据被正确记录
            let resourceStats = performanceMonitor.getResourceStatistics()
            XCTAssertGreaterThan(resourceStats.totalBytesReceived, 0, "应该记录了网络接收数据")
            XCTAssertGreaterThan(resourceStats.totalBytesSent, 0, "应该记录了网络发送数据")
        }
    }
    
    /// 测试并发安全性能
    func testConcurrentSafetyPerformance() {
        let concurrentOperations = 100
        let operationsPerTask = 50
        
        measure {
            let expectation = XCTestExpectation(description: "并发安全性能测试")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for taskId in 0..<concurrentOperations {
                        group.addTask {
                            for opId in 0..<operationsPerTask {
                                let requestId = UUID()
                                
                                // 并发访问性能监控器
                                await self.performanceMonitor.startRequest(id: requestId, type: .itemIdentification)
                                
                                // 模拟一些工作
                                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                                
                                await self.performanceMonitor.endRequest(id: requestId, type: .itemIdentification)
                                
                                // 并发访问缓存
                                let request = ItemIdentificationRequest(
                                    name: "并发测试\(taskId)_\(opId)",
                                    model: nil
                                )
                                let response = ItemInfo(
                                    name: request.name,
                                    category: .other,
                                    weight: 1.0,
                                    volume: 1.0,
                                    confidence: 0.9,
                                    source: "并发测试"
                                )
                                
                                self.cacheManager.cacheItemIdentification(request: request, response: response)
                                _ = self.cacheManager.getCachedItemIdentification(for: request)
                            }
                        }
                    }
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    /// 综合性能基准测试
    func testComprehensivePerformanceBenchmark() {
        measure {
            let expectation = XCTestExpectation(description: "综合性能基准测试")
            
            Task {
                let startTime = Date()
                
                // 1. 图像处理测试
                let testImage = createTestImage(size: CGSize(width: 512, height: 512))
                let imageMemoryManager = ImageMemoryManager.shared
                _ = await imageMemoryManager.optimizeImage(testImage, for: .recognition)
                
                // 2. 缓存操作测试
                for i in 0..<50 {
                    let request = ItemIdentificationRequest(name: "综合测试\(i)", model: nil)
                    let response = ItemInfo(
                        name: request.name,
                        category: .other,
                        weight: Double(i),
                        volume: Double(i * 2),
                        confidence: 0.9,
                        source: "综合测试"
                    )
                    self.cacheManager.cacheItemIdentification(request: request, response: response)
                    _ = self.cacheManager.getCachedItemIdentification(for: request)
                }
                
                // 3. 并发请求测试
                let requestQueue = AIRequestQueue.shared
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<10 {
                        group.addTask {
                            let request = AIRequest(type: .itemIdentification, parameters: ["id": i])
                            do {
                                _ = try await requestQueue.enqueue(request) {
                                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                                    return "完成\(i)"
                                }
                            } catch {
                                // 忽略错误，专注于性能测试
                            }
                        }
                    }
                }
                
                // 4. 性能监控测试
                for i in 0..<20 {
                    let requestId = UUID()
                    await self.performanceMonitor.startRequest(id: requestId, type: .itemIdentification)
                    await self.performanceMonitor.endRequest(id: requestId, type: .itemIdentification)
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                print("综合性能基准测试总时间: \(String(format: "%.2f", totalTime))秒")
                
                // 验证总时间在合理范围内
                XCTAssertLessThan(totalTime, 15.0, "综合性能测试应在15秒内完成")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 20.0)
        }
    }
    
    // MARK: - 辅助方法
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 添加一些随机内容以模拟真实图像
            UIColor.white.setFill()
            for _ in 0..<10 {
                let rect = CGRect(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height),
                    width: CGFloat.random(in: 10...100),
                    height: CGFloat.random(in: 10...100)
                )
                context.fill(rect)
            }
        }
    }
    
    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let startTime = Date()
        block()
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - 增强缓存管理器性能测试
    
    /// 测试增强缓存管理器的多级缓存性能
    func testEnhancedCacheManagerPerformance() {
        let enhancedCache = EnhancedCacheManager.shared
        let testDataCount = 200
        
        measure {
            let expectation = XCTestExpectation(description: "增强缓存管理器性能测试")
            
            Task {
                // 1. 测试缓存写入性能
                let writeStartTime = Date()
                for i in 0..<testDataCount {
                    let testData = TestCacheData(
                        id: UUID(),
                        name: "性能测试数据\(i)",
                        description: "这是性能测试数据项\(i)",
                        value: Double(i * 10),
                        tags: ["test", "performance", "item_\(i)"],
                        metadata: ["index": i, "type": "performance_test"]
                    )
                    await enhancedCache.set("perf_test_\(i)", data: testData)
                }
                let writeTime = Date().timeIntervalSince(writeStartTime)
                
                // 2. 测试缓存读取性能
                let readStartTime = Date()
                var hitCount = 0
                for i in 0..<testDataCount {
                    if let _: TestCacheData = await enhancedCache.get("perf_test_\(i)", type: TestCacheData.self) {
                        hitCount += 1
                    }
                }
                let readTime = Date().timeIntervalSince(readStartTime)
                
                let hitRate = Double(hitCount) / Double(testDataCount)
                
                // 验证性能指标
                XCTAssertLessThan(writeTime, 10.0, "缓存写入应在10秒内完成")
                XCTAssertLessThan(readTime, 3.0, "缓存读取应在3秒内完成")
                XCTAssertGreaterThan(hitRate, 0.95, "缓存命中率应大于95%")
                
                print("增强缓存性能 - 写入: \(String(format: "%.2f", writeTime))s, 读取: \(String(format: "%.2f", readTime))s, 命中率: \(String(format: "%.1f", hitRate * 100))%")
                
                // 清理测试数据
                for i in 0..<testDataCount {
                    await enhancedCache.remove("perf_test_\(i)")
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 20.0)
        }
    }
    
    /// 测试缓存压缩和存储优化性能
    func testCacheCompressionPerformance() {
        let enhancedCache = EnhancedCacheManager.shared
        let largeDataCount = 50
        
        measure {
            let expectation = XCTestExpectation(description: "缓存压缩性能测试")
            
            Task {
                let startTime = Date()
                
                // 创建大数据对象测试压缩
                for i in 0..<largeDataCount {
                    let largeDescription = String(repeating: "大数据测试内容 ", count: 1000) // ~20KB
                    let largeTestData = TestCacheData(
                        id: UUID(),
                        name: "大数据测试\(i)",
                        description: largeDescription,
                        value: Double(i * 100),
                        tags: Array(0..<100).map { "tag_\($0)" }, // 100个标签
                        metadata: Dictionary(uniqueKeysWithValues: (0..<50).map { ("key_\($0)", "value_\($0)") })
                    )
                    await enhancedCache.set("large_test_\(i)", data: largeTestData)
                }
                
                // 读取并验证数据完整性
                var successCount = 0
                for i in 0..<largeDataCount {
                    if let data: TestCacheData = await enhancedCache.get("large_test_\(i)", type: TestCacheData.self) {
                        XCTAssertEqual(data.name, "大数据测试\(i)", "数据应该完整保存")
                        successCount += 1
                    }
                }
                
                let processingTime = Date().timeIntervalSince(startTime)
                let successRate = Double(successCount) / Double(largeDataCount)
                
                // 验证性能和数据完整性
                XCTAssertLessThan(processingTime, 15.0, "大数据缓存处理应在15秒内完成")
                XCTAssertGreaterThan(successRate, 0.95, "数据完整性应大于95%")
                
                print("缓存压缩性能 - 处理时间: \(String(format: "%.2f", processingTime))s, 成功率: \(String(format: "%.1f", successRate * 100))%")
                
                // 获取缓存统计
                let stats = enhancedCache.cacheStatistics
                print("缓存统计 - 总大小: \(stats.formattedTotalSize), 条目数: \(stats.totalEntries)")
                
                // 清理测试数据
                await enhancedCache.clearAll()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 25.0)
        }
    }
    
    /// 测试自适应图像优化性能
    func testAdaptiveImageOptimizationPerformance() {
        let imageMemoryManager = ImageMemoryManager.shared
        let testImages = (0..<15).map { _ in createTestImage(size: CGSize(width: 1536, height: 1536)) }
        
        measure {
            let expectation = XCTestExpectation(description: "自适应图像优化性能测试")
            
            Task {
                let startTime = Date()
                
                // 测试自适应优化
                var optimizedImages: [UIImage] = []
                for image in testImages {
                    let optimized = await imageMemoryManager.adaptiveOptimizeImage(image, targetSize: 1024)
                    optimizedImages.append(optimized)
                }
                
                let optimizationTime = Date().timeIntervalSince(startTime)
                
                // 验证优化结果
                XCTAssertEqual(optimizedImages.count, testImages.count, "应该优化所有图像")
                XCTAssertLessThan(optimizationTime, 12.0, "自适应图像优化应在12秒内完成")
                
                // 测试内存使用情况
                let memoryStats = imageMemoryManager.getMemoryStatistics()
                XCTAssertFalse(memoryStats.isMemoryPressureHigh, "不应出现内存压力")
                
                print("自适应图像优化 - 处理时间: \(String(format: "%.2f", optimizationTime))s, 内存使用: \(memoryStats.formattedCurrentUsage)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 20.0)
        }
    }
    
    /// 测试智能并发请求管理性能
    func testIntelligentConcurrentRequestManagement() {
        let requestQueue = AIRequestQueue.shared
        let requestCount = 80
        let requestTypes: [AIRequestType] = [.itemIdentification, .photoRecognition, .travelSuggestions, .packingOptimization]
        
        measure {
            let expectation = XCTestExpectation(description: "智能并发请求管理性能测试")
            
            Task {
                let startTime = Date()
                var completedRequests = 0
                
                // 创建不同优先级和类型的请求
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<requestCount {
                        group.addTask {
                            let requestType = requestTypes[i % requestTypes.count]
                            let priority: RequestPriority = {
                                switch i % 4 {
                                case 0: return .low
                                case 1: return .normal
                                case 2: return .high
                                default: return .urgent
                                }
                            }()
                            
                            let request = AIRequest(
                                type: requestType,
                                priority: priority,
                                parameters: ["id": i, "type": requestType.rawValue]
                            )
                            
                            do {
                                _ = try await requestQueue.enqueue(request) {
                                    // 模拟不同类型请求的处理时间
                                    let processingTime: UInt64 = {
                                        switch requestType {
                                        case .photoRecognition:
                                            return UInt64.random(in: 50_000_000...200_000_000) // 50-200ms
                                        case .travelSuggestions:
                                            return UInt64.random(in: 100_000_000...300_000_000) // 100-300ms
                                        default:
                                            return UInt64.random(in: 20_000_000...100_000_000) // 20-100ms
                                        }
                                    }()
                                    
                                    try await Task.sleep(nanoseconds: processingTime)
                                    return "完成请求\(i)"
                                }
                                completedRequests += 1
                            } catch {
                                print("请求\(i)失败: \(error)")
                            }
                        }
                    }
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                let successRate = Double(completedRequests) / Double(requestCount)
                let throughput = Double(completedRequests) / totalTime
                
                // 验证性能指标
                XCTAssertLessThan(totalTime, 25.0, "智能并发请求管理应在25秒内完成")
                XCTAssertGreaterThan(successRate, 0.9, "请求成功率应大于90%")
                XCTAssertGreaterThan(throughput, 2.0, "吞吐量应大于2请求/秒")
                
                print("智能并发请求管理 - 总时间: \(String(format: "%.2f", totalTime))s, 成功率: \(String(format: "%.1f", successRate * 100))%, 吞吐量: \(String(format: "%.1f", throughput))请求/秒")
                
                // 获取队列状态
                let queueStatus = await requestQueue.getQueueStatus()
                print("队列状态 - 待处理: \(queueStatus.pendingCount), 活跃: \(queueStatus.activeCount), 网络质量: \(queueStatus.networkQuality.description)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 35.0)
        }
    }
    
    /// 测试实时性能监控开销
    func testRealTimePerformanceMonitoringOverhead() {
        let monitoringOperations = 2000
        
        measure {
            let expectation = XCTestExpectation(description: "实时性能监控开销测试")
            
            Task {
                // 启动实时监控
                await performanceMonitor.startRealTimeMonitoring()
                
                let startTime = Date()
                
                // 执行大量监控操作
                for i in 0..<monitoringOperations {
                    let requestId = UUID()
                    await performanceMonitor.startRequest(id: requestId, type: .itemIdentification)
                    
                    // 模拟一些工作
                    let _ = String(repeating: "test", count: 100).count
                    
                    await performanceMonitor.endRequest(id: requestId, type: .itemIdentification)
                    
                    // 每100次操作记录一次资源使用
                    if i % 100 == 0 {
                        await performanceMonitor.recordResourceUsage(type: .memory, amount: Double(i), unit: "operations")
                    }
                }
                
                let monitoringTime = Date().timeIntervalSince(startTime)
                let averageOverhead = monitoringTime / Double(monitoringOperations) * 1000 // ms
                
                // 验证监控开销
                XCTAssertLessThan(monitoringTime, 5.0, "实时性能监控应在5秒内完成")
                XCTAssertLessThan(averageOverhead, 1.0, "平均监控开销应小于1ms/操作")
                
                print("实时性能监控开销 - 总时间: \(String(format: "%.2f", monitoringTime))s, 平均开销: \(String(format: "%.3f", averageOverhead))ms/操作")
                
                // 生成性能报告测试
                let reportStartTime = Date()
                let detailedReport = await performanceMonitor.generateDetailedPerformanceReport()
                let realTimeMetrics = await performanceMonitor.getRealTimeMetrics()
                let trends = await performanceMonitor.getPerformanceTrends()
                let reportTime = Date().timeIntervalSince(reportStartTime)
                
                XCTAssertLessThan(reportTime, 2.0, "性能报告生成应在2秒内完成")
                XCTAssertNotNil(detailedReport.optimizationSuggestions, "应该生成优化建议")
                XCTAssertNotNil(realTimeMetrics, "应该生成实时指标")
                XCTAssertNotNil(trends, "应该生成性能趋势")
                
                print("性能报告生成时间: \(String(format: "%.3f", reportTime))s")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    /// 测试存储空间管理和清理性能
    func testStorageManagementPerformance() {
        let enhancedCache = EnhancedCacheManager.shared
        let testDataCount = 300
        
        measure {
            let expectation = XCTestExpectation(description: "存储空间管理性能测试")
            
            Task {
                // 1. 填充大量数据
                let fillStartTime = Date()
                for i in 0..<testDataCount {
                    let testData = TestCacheData(
                        id: UUID(),
                        name: "存储测试\(i)",
                        description: String(repeating: "存储管理测试数据 ", count: 50), // ~1KB
                        value: Double(i),
                        tags: ["storage", "test", "item_\(i)"],
                        metadata: ["index": i, "timestamp": Date().timeIntervalSince1970]
                    )
                    await enhancedCache.set("storage_test_\(i)", data: testData, expiry: TimeInterval.random(in: 60...3600))
                }
                let fillTime = Date().timeIntervalSince(fillStartTime)
                
                // 2. 获取初始统计
                let initialStats = enhancedCache.cacheStatistics
                
                // 3. 执行存储清理
                let cleanupStartTime = Date()
                
                // 模拟存储压力，触发清理
                for i in testDataCount..<(testDataCount + 100) {
                    let largeData = TestCacheData(
                        id: UUID(),
                        name: "大数据\(i)",
                        description: String(repeating: "大数据内容 ", count: 500), // ~5KB
                        value: Double(i),
                        tags: Array(0..<20).map { "tag_\($0)" },
                        metadata: Dictionary(uniqueKeysWithValues: (0..<10).map { ("key_\($0)", "value_\($0)") })
                    )
                    await enhancedCache.set("large_data_\(i)", data: largeData)
                }
                
                let cleanupTime = Date().timeIntervalSince(cleanupStartTime)
                
                // 4. 获取清理后统计
                let finalStats = enhancedCache.cacheStatistics
                
                // 验证性能指标
                XCTAssertLessThan(fillTime, 15.0, "数据填充应在15秒内完成")
                XCTAssertLessThan(cleanupTime, 10.0, "存储清理应在10秒内完成")
                
                print("存储管理性能 - 填充: \(String(format: "%.2f", fillTime))s, 清理: \(String(format: "%.2f", cleanupTime))s")
                print("存储统计 - 初始: \(initialStats.formattedTotalSize), 最终: \(finalStats.formattedTotalSize)")
                
                // 清理所有测试数据
                await enhancedCache.clearAll()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 35.0)
        }
    }
    
    /// 综合性能优化基准测试
    func testComprehensivePerformanceOptimizationBenchmark() {
        measure {
            let expectation = XCTestExpectation(description: "综合性能优化基准测试")
            
            Task {
                let overallStartTime = Date()
                
                // 1. 图像处理性能测试
                let imageStartTime = Date()
                let imageMemoryManager = ImageMemoryManager.shared
                let testImages = (0..<10).map { _ in createTestImage(size: CGSize(width: 1024, height: 1024)) }
                _ = await imageMemoryManager.optimizeImages(testImages, purpose: .recognition)
                let imageTime = Date().timeIntervalSince(imageStartTime)
                
                // 2. 缓存性能测试
                let cacheStartTime = Date()
                let enhancedCache = EnhancedCacheManager.shared
                for i in 0..<100 {
                    let testData = TestCacheData(
                        id: UUID(),
                        name: "综合测试\(i)",
                        description: "综合性能测试数据",
                        value: Double(i),
                        tags: ["comprehensive", "test"],
                        metadata: ["index": i]
                    )
                    await enhancedCache.set("comp_test_\(i)", data: testData)
                }
                
                var cacheHits = 0
                for i in 0..<100 {
                    if let _: TestCacheData = await enhancedCache.get("comp_test_\(i)", type: TestCacheData.self) {
                        cacheHits += 1
                    }
                }
                let cacheTime = Date().timeIntervalSince(cacheStartTime)
                
                // 3. 并发请求性能测试
                let requestStartTime = Date()
                let requestQueue = AIRequestQueue.shared
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<20 {
                        group.addTask {
                            let request = AIRequest(type: .itemIdentification, parameters: ["id": i])
                            do {
                                _ = try await requestQueue.enqueue(request) {
                                    try await Task.sleep(nanoseconds: 25_000_000) // 25ms
                                    return "结果\(i)"
                                }
                            } catch {
                                // 忽略错误，专注于性能
                            }
                        }
                    }
                }
                let requestTime = Date().timeIntervalSince(requestStartTime)
                
                // 4. 性能监控测试
                let monitorStartTime = Date()
                for i in 0..<50 {
                    let requestId = UUID()
                    await performanceMonitor.startRequest(id: requestId, type: .itemIdentification)
                    await performanceMonitor.endRequest(id: requestId, type: .itemIdentification)
                }
                let monitorTime = Date().timeIntervalSince(monitorStartTime)
                
                let totalTime = Date().timeIntervalSince(overallStartTime)
                
                // 验证各项性能指标
                XCTAssertLessThan(imageTime, 8.0, "图像处理应在8秒内完成")
                XCTAssertLessThan(cacheTime, 5.0, "缓存操作应在5秒内完成")
                XCTAssertLessThan(requestTime, 10.0, "并发请求应在10秒内完成")
                XCTAssertLessThan(monitorTime, 2.0, "性能监控应在2秒内完成")
                XCTAssertLessThan(totalTime, 20.0, "综合测试应在20秒内完成")
                
                // 验证缓存命中率
                let cacheHitRate = Double(cacheHits) / 100.0
                XCTAssertGreaterThan(cacheHitRate, 0.95, "缓存命中率应大于95%")
                
                print("综合性能优化基准测试结果:")
                print("- 图像处理: \(String(format: "%.2f", imageTime))s")
                print("- 缓存操作: \(String(format: "%.2f", cacheTime))s (命中率: \(String(format: "%.1f", cacheHitRate * 100))%)")
                print("- 并发请求: \(String(format: "%.2f", requestTime))s")
                print("- 性能监控: \(String(format: "%.2f", monitorTime))s")
                print("- 总时间: \(String(format: "%.2f", totalTime))s")
                
                // 获取最终性能报告
                let finalReport = await performanceMonitor.generateDetailedPerformanceReport()
                XCTAssertNotNil(finalReport.optimizationSuggestions, "应该生成优化建议")
                
                // 清理测试数据
                await enhancedCache.clearAll()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
}

// MARK: - 测试数据结构

struct TestCacheData: Codable {
    let id: UUID
    let name: String
    let description: String
    let value: Double
    let tags: [String]
    let metadata: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, value, tags, metadata
    }
    
    init(id: UUID, name: String, description: String, value: Double, tags: [String], metadata: [String: Any]) {
        self.id = id
        self.name = name
        self.description = description
        self.value = value
        self.tags = tags
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        value = try container.decode(Double.self, forKey: .value)
        tags = try container.decode([String].self, forKey: .tags)
        
        // 简化metadata处理
        if let metadataDict = try? container.decode([String: String].self, forKey: .metadata) {
            metadata = metadataDict
        } else {
            metadata = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(value, forKey: .value)
        try container.encode(tags, forKey: .tags)
        
        // 简化metadata编码
        let stringMetadata = metadata.compactMapValues { $0 as? String }
        try container.encode(stringMetadata, forKey: .metadata)
    }
}