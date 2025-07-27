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
}