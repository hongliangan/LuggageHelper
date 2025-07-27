import Foundation
@testable import LuggageHelper

// MARK: - 测试配置
struct TestConfiguration {
    
    // MARK: - 测试环境配置
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
    static let isMockingEnabled = ProcessInfo.processInfo.environment["MOCK_AI_SERVICE"] == "true"
    static let shouldSimulateNetworkError = ProcessInfo.processInfo.environment["SIMULATE_NETWORK_ERROR"] == "true"
    static let shouldSetupTestData = ProcessInfo.processInfo.environment["SETUP_TEST_DATA"] == "true"
    
    // MARK: - 测试数据配置
    static let testTimeout: TimeInterval = 10.0
    static let performanceTestTimeout: TimeInterval = 30.0
    static let longRunningTestTimeout: TimeInterval = 60.0
    
    // MARK: - Mock配置
    static let mockAIDelay: TimeInterval = 0.1
    static let mockNetworkDelay: TimeInterval = 0.05
    static let mockCacheSize: Int = 1024 * 1024 // 1MB
    
    // MARK: - 性能测试阈值
    struct PerformanceThresholds {
        static let aiResponseTime: TimeInterval = 5.0 // AI响应时间应小于5秒
        static let cacheHitTime: TimeInterval = 0.1 // 缓存命中应小于0.1秒
        static let uiResponseTime: TimeInterval = 0.2 // UI响应应小于0.2秒
        static let memoryUsage: Double = 200.0 // 内存使用应小于200MB
        static let cacheHitRate: Double = 0.3 // 缓存命中率应大于30%
        static let successRate: Double = 0.9 // 成功率应大于90%
    }
    
    // MARK: - 测试数据生成器
    struct TestDataGenerator {
        
        static func createTestItems(count: Int = 10) -> [ItemInfo] {
            return (0..<count).map { index in
                ItemInfo(
                    name: "测试物品\(index)",
                    category: ItemCategory.allCases[index % ItemCategory.allCases.count],
                    weight: Double.random(in: 50...2000),
                    volume: Double.random(in: 100...5000),
                    dimensions: Dimensions(
                        length: Double.random(in: 5...50),
                        width: Double.random(in: 5...50),
                        height: Double.random(in: 1...20)
                    ),
                    confidence: Double.random(in: 0.7...1.0),
                    source: "测试数据"
                )
            }
        }
        
        static func createTestLuggage(count: Int = 5) -> [Luggage] {
            let luggageTypes: [LuggageType] = [.suitcase, .backpack, .duffelBag, .carryOn]
            
            return (0..<count).map { index in
                let type = luggageTypes[index % luggageTypes.count]
                return Luggage(
                    id: UUID(),
                    name: "测试\(type.displayName)\(index)",
                    type: type,
                    capacity: Double.random(in: 20000...80000), // 20L-80L
                    emptyWeight: Double.random(in: 1000...5000), // 1kg-5kg
                    weightLimit: Double.random(in: 15000...30000), // 15kg-30kg
                    dimensions: Dimensions(
                        length: Double.random(in: 40...70),
                        width: Double.random(in: 30...50),
                        height: Double.random(in: 15...30)
                    ),
                    color: ["黑色", "蓝色", "红色", "灰色"][index % 4],
                    brand: "测试品牌\(index)",
                    location: .home("测试位置\(index)"),
                    notes: "测试备注\(index)",
                    photos: [],
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }
        
        static func createTestTravelSuggestion() -> TravelSuggestion {
            let destinations = ["东京", "巴黎", "纽约", "伦敦", "悉尼"]
            let seasons = ["春季", "夏季", "秋季", "冬季"]
            let activities = ["观光", "购物", "美食", "商务", "休闲"]
            
            let destination = destinations.randomElement()!
            let season = seasons.randomElement()!
            let selectedActivities = Array(activities.shuffled().prefix(3))
            
            let suggestedItems = [
                SuggestedItem(
                    name: "基础T恤",
                    category: .clothing,
                    importance: .essential,
                    reason: "日常穿着必需",
                    quantity: 3,
                    estimatedWeight: 600.0,
                    estimatedVolume: 1500.0
                ),
                SuggestedItem(
                    name: "充电器",
                    category: .electronics,
                    importance: .important,
                    reason: "电子设备充电",
                    quantity: 1,
                    estimatedWeight: 300.0,
                    estimatedVolume: 200.0
                ),
                SuggestedItem(
                    name: "洗漱用品",
                    category: .toiletries,
                    importance: .essential,
                    reason: "个人卫生必需",
                    quantity: 1,
                    estimatedWeight: 500.0,
                    estimatedVolume: 800.0
                )
            ]
            
            return TravelSuggestion(
                destination: destination,
                duration: Int.random(in: 3...14),
                season: season,
                activities: selectedActivities,
                suggestedItems: suggestedItems,
                categories: [.clothing, .electronics, .toiletries],
                tips: ["检查天气预报", "准备当地货币", "下载翻译应用"],
                warnings: ["注意当地法规", "保管好重要证件"]
            )
        }
        
        static func createTestPackingPlan(itemCount: Int = 5) -> PackingPlan {
            let luggageId = UUID()
            let packingItems = (0..<itemCount).map { index in
                PackingItem(
                    itemId: UUID(),
                    position: PackingPosition.allCases[index % PackingPosition.allCases.count],
                    priority: Int.random(in: 1...10),
                    reason: "测试装箱建议\(index)"
                )
            }
            
            return PackingPlan(
                luggageId: luggageId,
                items: packingItems,
                totalWeight: Double.random(in: 5000...20000),
                totalVolume: Double.random(in: 10000...40000),
                efficiency: Double.random(in: 0.6...0.9),
                warnings: [],
                suggestions: ["测试装箱建议1", "测试装箱建议2"]
            )
        }
    }
    
    // MARK: - 测试断言辅助方法
    struct TestAssertions {
        
        static func assertItemInfoValid(_ item: ItemInfo, file: StaticString = #file, line: UInt = #line) {
            XCTAssertFalse(item.name.isEmpty, "物品名称不应为空", file: file, line: line)
            XCTAssertGreaterThan(item.weight, 0, "物品重量应大于0", file: file, line: line)
            XCTAssertGreaterThan(item.volume, 0, "物品体积应大于0", file: file, line: line)
            XCTAssertGreaterThanOrEqual(item.confidence, 0.0, "置信度应大于等于0", file: file, line: line)
            XCTAssertLessThanOrEqual(item.confidence, 1.0, "置信度应小于等于1", file: file, line: line)
        }
        
        static func assertTravelSuggestionValid(_ suggestion: TravelSuggestion, file: StaticString = #file, line: UInt = #line) {
            XCTAssertFalse(suggestion.destination.isEmpty, "目的地不应为空", file: file, line: line)
            XCTAssertGreaterThan(suggestion.duration, 0, "旅行天数应大于0", file: file, line: line)
            XCTAssertFalse(suggestion.suggestedItems.isEmpty, "建议物品列表不应为空", file: file, line: line)
            
            for item in suggestion.suggestedItems {
                XCTAssertFalse(item.name.isEmpty, "建议物品名称不应为空", file: file, line: line)
                XCTAssertGreaterThan(item.quantity, 0, "建议物品数量应大于0", file: file, line: line)
            }
        }
        
        static func assertPackingPlanValid(_ plan: PackingPlan, file: StaticString = #file, line: UInt = #line) {
            XCTAssertFalse(plan.items.isEmpty, "装箱物品列表不应为空", file: file, line: line)
            XCTAssertGreaterThanOrEqual(plan.totalWeight, 0, "总重量应大于等于0", file: file, line: line)
            XCTAssertGreaterThanOrEqual(plan.totalVolume, 0, "总体积应大于等于0", file: file, line: line)
            XCTAssertGreaterThanOrEqual(plan.efficiency, 0.0, "效率应大于等于0", file: file, line: line)
            XCTAssertLessThanOrEqual(plan.efficiency, 1.0, "效率应小于等于1", file: file, line: line)
        }
        
        static func assertPerformanceWithinThreshold(
            responseTime: TimeInterval,
            threshold: TimeInterval,
            operation: String,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            XCTAssertLessThan(
                responseTime,
                threshold,
                "\(operation)响应时间(\(responseTime)s)应小于阈值(\(threshold)s)",
                file: file,
                line: line
            )
        }
        
        static func assertCacheHitRate(
            hitRate: Double,
            minimumRate: Double = PerformanceThresholds.cacheHitRate,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            XCTAssertGreaterThanOrEqual(
                hitRate,
                minimumRate,
                "缓存命中率(\(hitRate * 100)%)应大于等于最小值(\(minimumRate * 100)%)",
                file: file,
                line: line
            )
        }
        
        static func assertSuccessRate(
            successRate: Double,
            minimumRate: Double = PerformanceThresholds.successRate,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            XCTAssertGreaterThanOrEqual(
                successRate,
                minimumRate,
                "成功率(\(successRate * 100)%)应大于等于最小值(\(minimumRate * 100)%)",
                file: file,
                line: line
            )
        }
    }
    
    // MARK: - 测试环境设置
    struct TestEnvironment {
        
        static func setupForUITesting() {
            if isUITesting {
                // 设置UI测试环境
                UserDefaults.standard.set(true, forKey: "UITestingMode")
                UserDefaults.standard.set(mockAIDelay, forKey: "MockAIDelay")
            }
        }
        
        static func setupMockServices() {
            if isMockingEnabled {
                // 配置Mock服务
                UserDefaults.standard.set(true, forKey: "MockServicesEnabled")
            }
        }
        
        static func setupTestData() {
            if shouldSetupTestData {
                // 创建测试数据
                let testItems = TestDataGenerator.createTestItems(count: 20)
                let testLuggage = TestDataGenerator.createTestLuggage(count: 5)
                
                // 这里可以将测试数据保存到Core Data或其他存储中
                // 实际实现需要根据应用的数据存储方式来调整
            }
        }
        
        static func cleanup() {
            // 清理测试环境
            UserDefaults.standard.removeObject(forKey: "UITestingMode")
            UserDefaults.standard.removeObject(forKey: "MockServicesEnabled")
            UserDefaults.standard.removeObject(forKey: "MockAIDelay")
        }
    }
    
    // MARK: - 测试工具方法
    struct TestUtilities {
        
        static func waitForCondition(
            timeout: TimeInterval = testTimeout,
            condition: () -> Bool
        ) -> Bool {
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                if condition() {
                    return true
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            
            return false
        }
        
        static func measureAsyncOperation<T>(
            operation: () async throws -> T
        ) async rethrows -> (result: T, duration: TimeInterval) {
            let startTime = Date()
            let result = try await operation()
            let duration = Date().timeIntervalSince(startTime)
            
            return (result, duration)
        }
        
        static func generateRandomString(length: Int = 10) -> String {
            let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            return String((0..<length).map { _ in letters.randomElement()! })
        }
        
        static func createTemporaryDirectory() -> URL {
            let tempDir = FileManager.default.temporaryDirectory
            let testDir = tempDir.appendingPathComponent("LuggageHelperTests_\(UUID().uuidString)")
            
            try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            return testDir
        }
        
        static func cleanupTemporaryDirectory(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - 测试基类
class BaseTestCase: XCTestCase {
    
    override func setUp() {
        super.setUp()
        TestConfiguration.TestEnvironment.setupForUITesting()
        TestConfiguration.TestEnvironment.setupMockServices()
        TestConfiguration.TestEnvironment.setupTestData()
    }
    
    override func tearDown() {
        TestConfiguration.TestEnvironment.cleanup()
        super.tearDown()
    }
    
    // MARK: - 便捷断言方法
    
    func assertItemValid(_ item: ItemInfo, file: StaticString = #file, line: UInt = #line) {
        TestConfiguration.TestAssertions.assertItemInfoValid(item, file: file, line: line)
    }
    
    func assertTravelSuggestionValid(_ suggestion: TravelSuggestion, file: StaticString = #file, line: UInt = #line) {
        TestConfiguration.TestAssertions.assertTravelSuggestionValid(suggestion, file: file, line: line)
    }
    
    func assertPackingPlanValid(_ plan: PackingPlan, file: StaticString = #file, line: UInt = #line) {
        TestConfiguration.TestAssertions.assertPackingPlanValid(plan, file: file, line: line)
    }
    
    func assertPerformance(
        responseTime: TimeInterval,
        threshold: TimeInterval,
        operation: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        TestConfiguration.TestAssertions.assertPerformanceWithinThreshold(
            responseTime: responseTime,
            threshold: threshold,
            operation: operation,
            file: file,
            line: line
        )
    }
    
    // MARK: - 便捷工具方法
    
    func waitForCondition(timeout: TimeInterval = TestConfiguration.testTimeout, condition: () -> Bool) -> Bool {
        return TestConfiguration.TestUtilities.waitForCondition(timeout: timeout, condition: condition)
    }
    
    func measureAsync<T>(operation: () async throws -> T) async rethrows -> (result: T, duration: TimeInterval) {
        return try await TestConfiguration.TestUtilities.measureAsyncOperation(operation: operation)
    }
}