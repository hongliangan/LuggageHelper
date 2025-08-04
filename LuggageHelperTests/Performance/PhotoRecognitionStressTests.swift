import XCTest
@testable import LuggageHelper

/// 照片识别功能压力测试
/// 测试系统在高负载、长时间运行和极端条件下的性能和稳定性
@MainActor
final class PhotoRecognitionStressTests: XCTestCase {
    
    // MARK: - 测试组件
    
    var stressTestManager: StressTestManager!
    var performanceMonitor: PerformanceMonitor!
    var memoryMonitor: MemoryMonitor!
    var resourceMonitor: ResourceMonitor!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        stressTestManager = StressTestManager()
        performanceMonitor = PerformanceMonitor.shared
        memoryMonitor = MemoryMonitor()
        resourceMonitor = ResourceMonitor()
        
        // 重置监控状态
        performanceMonitor.resetStats()
        memoryMonitor.startMonitoring()
        resourceMonitor.startMonitoring()
    }
    
    override func tearDownWithError() throws {
        // 停止监控
        memoryMonitor.stopMonitoring()
        resourceMonitor.stopMonitoring()
        
        // 清理资源
        stressTestManager.cleanup()
        
        stressTestManager = nil
        performanceMonitor = nil
        memoryMonitor = nil
        resourceMonitor = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - 高并发压力测试
    
    /// 测试高并发图像识别处理
    func testHighConcurrencyImageRecognition() async throws {
        let concurrentRequests = 50
        let testDuration: TimeInterval = 60.0 // 1分钟
        
        print("🚀 开始高并发压力测试: \(concurrentRequests)个并发请求，持续\(testDuration)秒")
        
        let stressTestId = UUID()
        await performanceMonitor.startRequest(id: stressTestId, type: .stressTest)
        
        let startTime = Date()
        var completedRequests = 0
        var failedRequests = 0
        var totalResponseTime: TimeInterval = 0
        
        do {
            await withTaskGroup(of: Void.self) { group in
                while Date().timeIntervalSince(startTime) < testDuration {
                    // 限制并发数量
                    if group.isEmpty || await getCurrentConcurrency() < concurrentRequests {
                        group.addTask {
                            let requestStartTime = Date()
                            
                            do {
                                let testImage = self.createRandomTestImage()
                                _ = try await self.stressTestManager.performImageRecognition(testImage)
                                
                                let responseTime = Date().timeIntervalSince(requestStartTime)
                                await MainActor.run {
                                    completedRequests += 1
                                    totalResponseTime += responseTime
                                }
                                
                            } catch {
                                await MainActor.run {
                                    failedRequests += 1
                                }
                                print("并发请求失败: \(error)")
                            }
                        }
                    }
                    
                    // 短暂等待以控制请求频率
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                }
            }
            
            let totalRequests = completedRequests + failedRequests
            let successRate = Double(completedRequests) / Double(totalRequests)
            let averageResponseTime = totalResponseTime / Double(completedRequests)
            
            print("📊 高并发压力测试结果:")
            print("- 总请求数: \(totalRequests)")
            print("- 成功请求: \(completedRequests)")
            print("- 失败请求: \(failedRequests)")
            print("- 成功率: \(String(format: "%.1f", successRate * 100))%")
            print("- 平均响应时间: \(String(format: "%.2f", averageResponseTime))秒")
            
            // 验证性能指标
            XCTAssertGreaterThan(successRate, 0.8, "高并发下成功率应大于80%")
            XCTAssertLessThan(averageResponseTime, 10.0, "高并发下平均响应时间应小于10秒")
            XCTAssertGreaterThan(totalRequests, concurrentRequests, "应该处理了足够数量的请求")
            
            await performanceMonitor.endRequest(id: stressTestId, type: .stressTest)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: stressTestId, type: .stressTest, error: error)
            throw error
        }
    }
    
    /// 测试批量处理的并发性能
    func testBatchProcessingConcurrency() async throws {
        let batchSize = 20
        let concurrentBatches = 5
        let totalImages = batchSize * concurrentBatches
        
        print("📦 开始批量处理并发测试: \(concurrentBatches)个批次，每批\(batchSize)张图像")
        
        let batchTestId = UUID()
        await performanceMonitor.startRequest(id: batchTestId, type: .batchStressTest)
        
        let startTime = Date()
        var processedImages = 0
        var failedBatches = 0
        
        do {
            await withTaskGroup(of: Void.self) { group in
                for batchIndex in 0..<concurrentBatches {
                    group.addTask {
                        do {
                            let batchImages = (0..<batchSize).map { _ in
                                self.createRandomTestImage()
                            }
                            
                            let results = try await self.stressTestManager.performBatchRecognition(batchImages)
                            
                            await MainActor.run {
                                processedImages += results.count
                            }
                            
                            print("批次\(batchIndex + 1)完成，处理了\(results.count)张图像")
                            
                        } catch {
                            await MainActor.run {
                                failedBatches += 1
                            }
                            print("批次\(batchIndex + 1)失败: \(error)")
                        }
                    }
                }
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            let throughput = Double(processedImages) / totalTime
            let batchSuccessRate = Double(concurrentBatches - failedBatches) / Double(concurrentBatches)
            
            print("📈 批量处理并发测试结果:")
            print("- 总图像数: \(totalImages)")
            print("- 处理成功: \(processedImages)")
            print("- 失败批次: \(failedBatches)")
            print("- 批次成功率: \(String(format: "%.1f", batchSuccessRate * 100))%")
            print("- 总耗时: \(String(format: "%.2f", totalTime))秒")
            print("- 吞吐量: \(String(format: "%.1f", throughput))张/秒")
            
            // 验证批量处理性能
            XCTAssertGreaterThan(batchSuccessRate, 0.8, "批次成功率应大于80%")
            XCTAssertGreaterThan(throughput, 1.0, "吞吐量应大于1张/秒")
            XCTAssertGreaterThan(processedImages, totalImages * 0.8, "应该处理大部分图像")
            
            await performanceMonitor.endRequest(id: batchTestId, type: .batchStressTest)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: batchTestId, type: .batchStressTest, error: error)
            throw error
        }
    }
    
    // MARK: - 内存压力测试
    
    /// 测试大量图像处理的内存使用
    func testMemoryStressWithLargeImages() async throws {
        let imageCount = 100
        let largeImageSize = CGSize(width: 2048, height: 1536) // 2K图像
        
        print("💾 开始内存压力测试: \(imageCount)张大尺寸图像")
        
        let initialMemory = memoryMonitor.getCurrentMemoryUsage()
        var peakMemory: UInt64 = initialMemory
        var processedCount = 0
        
        let memoryTestId = UUID()
        await performanceMonitor.startRequest(id: memoryTestId, type: .memoryStressTest)
        
        do {
            for i in 0..<imageCount {
                // 创建大尺寸测试图像
                let largeImage = createTestImage(size: largeImageSize, complexity: .high)
                
                // 处理图像
                _ = try await stressTestManager.performImageRecognition(largeImage)
                processedCount += 1
                
                // 监控内存使用
                let currentMemory = memoryMonitor.getCurrentMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
                
                // 每10张图像检查一次内存状态
                if i % 10 == 0 {
                    let memoryIncrease = currentMemory - initialMemory
                    print("处理\(i + 1)张图像，内存增长: \(memoryIncrease / 1024 / 1024)MB")
                    
                    // 如果内存增长过快，触发警告
                    if memoryIncrease > 500 * 1024 * 1024 { // 500MB
                        print("⚠️ 内存使用过高，当前增长: \(memoryIncrease / 1024 / 1024)MB")
                    }
                }
                
                // 短暂延迟以观察内存变化
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            // 强制垃圾回收
            autoreleasepool {
                // 清理可能的缓存
            }
            
            // 等待内存释放
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            
            let finalMemory = memoryMonitor.getCurrentMemoryUsage()
            let totalMemoryIncrease = finalMemory - initialMemory
            let peakMemoryIncrease = peakMemory - initialMemory
            
            print("📊 内存压力测试结果:")
            print("- 处理图像数: \(processedCount)")
            print("- 初始内存: \(initialMemory / 1024 / 1024)MB")
            print("- 峰值内存: \(peakMemory / 1024 / 1024)MB")
            print("- 最终内存: \(finalMemory / 1024 / 1024)MB")
            print("- 峰值内存增长: \(peakMemoryIncrease / 1024 / 1024)MB")
            print("- 最终内存增长: \(totalMemoryIncrease / 1024 / 1024)MB")
            
            // 验证内存使用
            XCTAssertEqual(processedCount, imageCount, "应该处理所有图像")
            XCTAssertLessThan(peakMemoryIncrease, 1024 * 1024 * 1024, "峰值内存增长应小于1GB") // 1GB
            XCTAssertLessThan(totalMemoryIncrease, 200 * 1024 * 1024, "最终内存增长应小于200MB")
            
            await performanceMonitor.endRequest(id: memoryTestId, type: .memoryStressTest)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: memoryTestId, type: .memoryStressTest, error: error)
            throw error
        }
    }
    
    /// 测试内存泄漏检测
    func testMemoryLeakDetection() async throws {
        let cycleCount = 50
        let imagesPerCycle = 10
        
        print("🔍 开始内存泄漏检测: \(cycleCount)个周期，每周期\(imagesPerCycle)张图像")
        
        var memoryReadings: [UInt64] = []
        
        for cycle in 0..<cycleCount {
            let cycleStartMemory = memoryMonitor.getCurrentMemoryUsage()
            
            // 在每个周期中处理图像
            for _ in 0..<imagesPerCycle {
                let testImage = createRandomTestImage()
                _ = try await stressTestManager.performImageRecognition(testImage)
            }
            
            // 强制垃圾回收
            autoreleasepool {}
            
            // 短暂等待内存释放
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            
            let cycleEndMemory = memoryMonitor.getCurrentMemoryUsage()
            memoryReadings.append(cycleEndMemory)
            
            if cycle % 10 == 0 {
                print("周期\(cycle + 1)完成，内存: \(cycleEndMemory / 1024 / 1024)MB")
            }
        }
        
        // 分析内存趋势
        let memoryTrend = analyzeMemoryTrend(memoryReadings)
        
        print("📈 内存泄漏检测结果:")
        print("- 初始内存: \(memoryReadings.first! / 1024 / 1024)MB")
        print("- 最终内存: \(memoryReadings.last! / 1024 / 1024)MB")
        print("- 内存趋势: \(memoryTrend.description)")
        print("- 平均增长率: \(String(format: "%.2f", memoryTrend.averageGrowthRate))MB/周期")
        
        // 验证内存泄漏
        XCTAssertLessThan(memoryTrend.averageGrowthRate, 5.0, "平均内存增长率应小于5MB/周期")
        XCTAssertLessThan(memoryTrend.totalGrowth, 100 * 1024 * 1024, "总内存增长应小于100MB")
        
        if memoryTrend.hasLeak {
            XCTFail("检测到潜在的内存泄漏")
        }
    }
    
    // MARK: - 长时间运行稳定性测试
    
    /// 测试长时间连续运行的稳定性
    func testLongRunningStability() async throws {
        let runDuration: TimeInterval = 300.0 // 5分钟
        let operationInterval: TimeInterval = 2.0 // 每2秒一个操作
        
        print("⏱️ 开始长时间稳定性测试: 持续\(runDuration / 60)分钟")
        
        let stabilityTestId = UUID()
        await performanceMonitor.startRequest(id: stabilityTestId, type: .stabilityTest)
        
        let startTime = Date()
        var operationCount = 0
        var successCount = 0
        var errorCount = 0
        var errorTypes: [String: Int] = [:]
        
        var lastMemoryCheck = Date()
        var memoryCheckInterval: TimeInterval = 30.0 // 每30秒检查一次内存
        
        while Date().timeIntervalSince(startTime) < runDuration {
            let operationStartTime = Date()
            
            do {
                let testImage = createRandomTestImage()
                _ = try await stressTestManager.performImageRecognition(testImage)
                successCount += 1
                
            } catch {
                errorCount += 1
                let errorType = String(describing: type(of: error))
                errorTypes[errorType, default: 0] += 1
                
                print("操作\(operationCount + 1)失败: \(error)")
            }
            
            operationCount += 1
            
            // 定期检查内存状态
            if Date().timeIntervalSince(lastMemoryCheck) >= memoryCheckInterval {
                let currentMemory = memoryMonitor.getCurrentMemoryUsage()
                print("运行\(String(format: "%.1f", Date().timeIntervalSince(startTime) / 60))分钟，内存使用: \(currentMemory / 1024 / 1024)MB")
                lastMemoryCheck = Date()
            }
            
            // 控制操作间隔
            let operationTime = Date().timeIntervalSince(operationStartTime)
            let remainingInterval = operationInterval - operationTime
            if remainingInterval > 0 {
                try await Task.sleep(nanoseconds: UInt64(remainingInterval * 1_000_000_000))
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let successRate = Double(successCount) / Double(operationCount)
        let operationsPerMinute = Double(operationCount) / (totalTime / 60.0)
        
        print("📊 长时间稳定性测试结果:")
        print("- 运行时间: \(String(format: "%.1f", totalTime / 60))分钟")
        print("- 总操作数: \(operationCount)")
        print("- 成功操作: \(successCount)")
        print("- 失败操作: \(errorCount)")
        print("- 成功率: \(String(format: "%.1f", successRate * 100))%")
        print("- 操作频率: \(String(format: "%.1f", operationsPerMinute))次/分钟")
        
        if !errorTypes.isEmpty {
            print("- 错误类型分布:")
            for (errorType, count) in errorTypes.sorted(by: { $0.value > $1.value }) {
                print("  - \(errorType): \(count)次")
            }
        }
        
        // 验证稳定性指标
        XCTAssertGreaterThan(successRate, 0.85, "长时间运行成功率应大于85%")
        XCTAssertGreaterThan(operationCount, Int(runDuration / operationInterval * 0.8), "应该完成大部分预期操作")
        XCTAssertLessThan(errorCount, operationCount / 10, "错误数量应该少于总操作数的10%")
        
        await performanceMonitor.endRequest(id: stabilityTestId, type: .stabilityTest)
    }
    
    /// 测试系统资源耗尽情况下的行为
    func testResourceExhaustionHandling() async throws {
        print("⚠️ 开始资源耗尽测试")
        
        let resourceTestId = UUID()
        await performanceMonitor.startRequest(id: resourceTestId, type: .resourceExhaustionTest)
        
        var largeImages: [UIImage] = []
        var operationCount = 0
        var lastSuccessfulOperation = 0
        
        do {
            // 逐渐增加内存压力
            while operationCount < 200 { // 最多200次操作
                let currentMemory = memoryMonitor.getCurrentMemoryUsage()
                
                // 如果内存使用过高，停止测试
                if currentMemory > 1024 * 1024 * 1024 { // 1GB
                    print("内存使用达到限制，停止测试")
                    break
                }
                
                do {
                    // 创建越来越大的图像
                    let imageSize = CGSize(
                        width: 1024 + operationCount * 10,
                        height: 768 + operationCount * 8
                    )
                    let largeImage = createTestImage(size: imageSize, complexity: .high)
                    largeImages.append(largeImage) // 故意不释放以增加内存压力
                    
                    _ = try await stressTestManager.performImageRecognition(largeImage)
                    lastSuccessfulOperation = operationCount
                    
                } catch {
                    print("资源耗尽导致操作失败: \(error)")
                    
                    // 验证系统是否优雅地处理了资源耗尽
                    if let photoError = error as? PhotoRecognitionError {
                        switch photoError {
                        case .imageTooBig, .processingTimeout:
                            print("✅ 系统正确处理了资源限制")
                        default:
                            print("⚠️ 意外的错误类型: \(photoError)")
                        }
                    }
                    
                    break
                }
                
                operationCount += 1
                
                if operationCount % 20 == 0 {
                    print("完成\(operationCount)次操作，内存: \(currentMemory / 1024 / 1024)MB")
                }
            }
            
            print("📊 资源耗尽测试结果:")
            print("- 总操作尝试: \(operationCount)")
            print("- 最后成功操作: \(lastSuccessfulOperation)")
            print("- 累积图像数: \(largeImages.count)")
            print("- 最终内存: \(memoryMonitor.getCurrentMemoryUsage() / 1024 / 1024)MB")
            
            // 验证系统在资源压力下的表现
            XCTAssertGreaterThan(lastSuccessfulOperation, 10, "应该能够处理一定数量的操作")
            XCTAssertLessThan(operationCount - lastSuccessfulOperation, 50, "失败操作数量应该在合理范围内")
            
            await performanceMonitor.endRequest(id: resourceTestId, type: .resourceExhaustionTest)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: resourceTestId, type: .resourceExhaustionTest, error: error)
            throw error
        } finally {
            // 清理大图像数组以释放内存
            largeImages.removeAll()
        }
    }
    
    // MARK: - 网络压力测试
    
    /// 测试网络不稳定情况下的表现
    func testNetworkInstabilityStress() async throws {
        let testDuration: TimeInterval = 120.0 // 2分钟
        let networkConditions: [NetworkCondition] = [.good, .poor, .offline, .unstable]
        
        print("🌐 开始网络不稳定压力测试: 持续\(testDuration / 60)分钟")
        
        let networkTestId = UUID()
        await performanceMonitor.startRequest(id: networkTestId, type: .networkStressTest)
        
        let startTime = Date()
        var operationCount = 0
        var networkConditionResults: [NetworkCondition: (success: Int, failure: Int)] = [:]
        
        // 初始化结果统计
        for condition in networkConditions {
            networkConditionResults[condition] = (success: 0, failure: 0)
        }
        
        do {
            while Date().timeIntervalSince(startTime) < testDuration {
                // 随机选择网络条件
                let currentCondition = networkConditions.randomElement()!
                
                // 模拟网络条件
                stressTestManager.simulateNetworkCondition(currentCondition)
                
                do {
                    let testImage = createRandomTestImage()
                    _ = try await stressTestManager.performImageRecognition(testImage)
                    
                    // 记录成功
                    var result = networkConditionResults[currentCondition]!
                    result.success += 1
                    networkConditionResults[currentCondition] = result
                    
                } catch {
                    // 记录失败
                    var result = networkConditionResults[currentCondition]!
                    result.failure += 1
                    networkConditionResults[currentCondition] = result
                    
                    print("网络条件\(currentCondition)下操作失败: \(error)")
                }
                
                operationCount += 1
                
                // 短暂延迟
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
            
            print("📊 网络不稳定压力测试结果:")
            for condition in networkConditions {
                let result = networkConditionResults[condition]!
                let total = result.success + result.failure
                let successRate = total > 0 ? Double(result.success) / Double(total) : 0.0
                
                print("- \(condition): 成功\(result.success), 失败\(result.failure), 成功率\(String(format: "%.1f", successRate * 100))%")
            }
            
            // 验证网络适应性
            let goodNetworkResult = networkConditionResults[.good]!
            let goodNetworkTotal = goodNetworkResult.success + goodNetworkResult.failure
            let goodNetworkSuccessRate = goodNetworkTotal > 0 ? Double(goodNetworkResult.success) / Double(goodNetworkTotal) : 0.0
            
            XCTAssertGreaterThan(goodNetworkSuccessRate, 0.9, "良好网络条件下成功率应大于90%")
            XCTAssertGreaterThan(operationCount, 100, "应该执行足够数量的操作")
            
            await performanceMonitor.endRequest(id: networkTestId, type: .networkStressTest)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: networkTestId, type: .networkStressTest, error: error)
            throw error
        }
    }
    
    // MARK: - 缓存压力测试
    
    /// 测试缓存系统在高负载下的表现
    func testCacheSystemStress() async throws {
        let cacheOperations = 1000
        let uniqueImages = 100 // 重复使用以测试缓存效果
        
        print("💾 开始缓存系统压力测试: \(cacheOperations)次操作，\(uniqueImages)张不同图像")
        
        let cacheTestId = UUID()
        await performanceMonitor.startRequest(id: cacheTestId, type: .cacheStressTest)
        
        // 预生成测试图像
        let testImages = (0..<uniqueImages).map { _ in createRandomTestImage() }
        
        var cacheHits = 0
        var cacheMisses = 0
        var totalResponseTime: TimeInterval = 0
        
        do {
            for i in 0..<cacheOperations {
                let randomImage = testImages.randomElement()!
                let operationStartTime = Date()
                
                let result = try await stressTestManager.performImageRecognitionWithCache(randomImage)
                
                let responseTime = Date().timeIntervalSince(operationStartTime)
                totalResponseTime += responseTime
                
                // 判断是否为缓存命中（响应时间较短）
                if responseTime < 0.5 { // 0.5秒以下认为是缓存命中
                    cacheHits += 1
                } else {
                    cacheMisses += 1
                }
                
                if i % 100 == 0 {
                    print("完成\(i + 1)次缓存操作")
                }
            }
            
            let cacheHitRate = Double(cacheHits) / Double(cacheOperations)
            let averageResponseTime = totalResponseTime / Double(cacheOperations)
            
            print("📊 缓存系统压力测试结果:")
            print("- 总操作数: \(cacheOperations)")
            print("- 缓存命中: \(cacheHits)")
            print("- 缓存未命中: \(cacheMisses)")
            print("- 缓存命中率: \(String(format: "%.1f", cacheHitRate * 100))%")
            print("- 平均响应时间: \(String(format: "%.3f", averageResponseTime))秒")
            
            // 验证缓存性能
            XCTAssertGreaterThan(cacheHitRate, 0.5, "缓存命中率应大于50%")
            XCTAssertLessThan(averageResponseTime, 2.0, "平均响应时间应小于2秒")
            
            await performanceMonitor.endRequest(id: cacheTestId, type: .cacheStressTest)
            
        } catch {
            await performanceMonitor.recordRequestFailure(id: cacheTestId, type: .cacheStressTest, error: error)
            throw error
        }
    }
    
    // MARK: - 辅助方法
    
    private func createRandomTestImage() -> UIImage {
        let sizes = [
            CGSize(width: 300, height: 200),
            CGSize(width: 600, height: 400),
            CGSize(width: 800, height: 600),
            CGSize(width: 1024, height: 768)
        ]
        
        let randomSize = sizes.randomElement()!
        return createTestImage(size: randomSize, complexity: .medium)
    }
    
    private func createTestImage(size: CGSize, complexity: ImageComplexity) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 设置背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 根据复杂度添加内容
            let objectCount: Int
            switch complexity {
            case .low:
                objectCount = 1
            case .medium:
                objectCount = 5
            case .high:
                objectCount = 20
            }
            
            // 添加随机形状
            for _ in 0..<objectCount {
                let color = UIColor(
                    red: CGFloat.random(in: 0...1),
                    green: CGFloat.random(in: 0...1),
                    blue: CGFloat.random(in: 0...1),
                    alpha: 0.8
                )
                color.setFill()
                
                let rect = CGRect(
                    x: CGFloat.random(in: 0...size.width * 0.8),
                    y: CGFloat.random(in: 0...size.height * 0.8),
                    width: CGFloat.random(in: 20...size.width * 0.2),
                    height: CGFloat.random(in: 20...size.height * 0.2)
                )
                
                if Bool.random() {
                    context.fill(rect)
                } else {
                    context.fillEllipse(in: rect)
                }
            }
        }
    }
    
    private func getCurrentConcurrency() async -> Int {
        // 模拟获取当前并发数
        return Int.random(in: 0...50)
    }
    
    private func analyzeMemoryTrend(_ readings: [UInt64]) -> MemoryTrend {
        guard readings.count > 1 else {
            return MemoryTrend(averageGrowthRate: 0, totalGrowth: 0, hasLeak: false, description: "数据不足")
        }
        
        let initialMemory = readings.first!
        let finalMemory = readings.last!
        let totalGrowth = Int64(finalMemory) - Int64(initialMemory)
        
        // 计算平均增长率
        var totalGrowthRate: Double = 0
        for i in 1..<readings.count {
            let growth = Int64(readings[i]) - Int64(readings[i-1])
            totalGrowthRate += Double(growth) / 1024 / 1024 // 转换为MB
        }
        let averageGrowthRate = totalGrowthRate / Double(readings.count - 1)
        
        // 检测是否有内存泄漏
        let hasLeak = averageGrowthRate > 2.0 && totalGrowth > 50 * 1024 * 1024 // 平均增长>2MB且总增长>50MB
        
        let description: String
        if hasLeak {
            description = "检测到内存泄漏"
        } else if averageGrowthRate > 1.0 {
            description = "内存增长较快"
        } else if averageGrowthRate < -1.0 {
            description = "内存使用下降"
        } else {
            description = "内存使用稳定"
        }
        
        return MemoryTrend(
            averageGrowthRate: averageGrowthRate,
            totalGrowth: totalGrowth,
            hasLeak: hasLeak,
            description: description
        )
    }
}

// MARK: - 支持类和枚举

enum ImageComplexity {
    case low, medium, high
}

enum NetworkCondition {
    case good, poor, offline, unstable
}

struct MemoryTrend {
    let averageGrowthRate: Double // MB per cycle
    let totalGrowth: Int64 // bytes
    let hasLeak: Bool
    let description: String
}

/// 压力测试管理器
class StressTestManager {
    private var currentNetworkCondition: NetworkCondition = .good
    
    func performImageRecognition(_ image: UIImage) async throws -> String {
        // 模拟图像识别处理
        let processingTime = getProcessingTime(for: currentNetworkCondition)
        try await Task.sleep(nanoseconds: UInt64(processingTime * 1_000_000_000))
        
        // 模拟可能的失败
        if shouldSimulateFailure(for: currentNetworkCondition) {
            throw PhotoRecognitionError.networkUnavailable
        }
        
        return "识别结果"
    }
    
    func performBatchRecognition(_ images: [UIImage]) async throws -> [String] {
        var results: [String] = []
        
        for image in images {
            let result = try await performImageRecognition(image)
            results.append(result)
        }
        
        return results
    }
    
    func performImageRecognitionWithCache(_ image: UIImage) async throws -> String {
        // 模拟缓存检查
        if Bool.random() && currentNetworkCondition == .good {
            // 缓存命中，快速返回
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            return "缓存结果"
        } else {
            // 缓存未命中，正常处理
            return try await performImageRecognition(image)
        }
    }
    
    func simulateNetworkCondition(_ condition: NetworkCondition) {
        currentNetworkCondition = condition
    }
    
    func cleanup() {
        // 清理资源
    }
    
    private func getProcessingTime(for condition: NetworkCondition) -> TimeInterval {
        switch condition {
        case .good:
            return Double.random(in: 0.5...2.0)
        case .poor:
            return Double.random(in: 2.0...5.0)
        case .offline:
            return Double.random(in: 0.1...0.5) // 离线处理更快
        case .unstable:
            return Double.random(in: 1.0...8.0)
        }
    }
    
    private func shouldSimulateFailure(for condition: NetworkCondition) -> Bool {
        switch condition {
        case .good:
            return Double.random(in: 0...1) < 0.05 // 5%失败率
        case .poor:
            return Double.random(in: 0...1) < 0.2 // 20%失败率
        case .offline:
            return Double.random(in: 0...1) < 0.1 // 10%失败率（离线模式）
        case .unstable:
            return Double.random(in: 0...1) < 0.3 // 30%失败率
        }
    }
}

/// 内存监控器
class MemoryMonitor {
    private var isMonitoring = false
    
    func startMonitoring() {
        isMonitoring = true
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

/// 资源监控器
class ResourceMonitor {
    private var isMonitoring = false
    
    func startMonitoring() {
        isMonitoring = true
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    func getCurrentCPUUsage() -> Double {
        // 模拟CPU使用率
        return Double.random(in: 0...100)
    }
    
    func getCurrentDiskUsage() -> UInt64 {
        // 模拟磁盘使用
        return UInt64.random(in: 1024*1024*100...1024*1024*1000) // 100MB-1GB
    }
}

// MARK: - 扩展的性能监控类型

extension PerformanceMonitor {
    enum RequestType {
        case stressTest
        case batchStressTest
        case memoryStressTest
        case stabilityTest
        case resourceExhaustionTest
        case networkStressTest
        case cacheStressTest
    }
}