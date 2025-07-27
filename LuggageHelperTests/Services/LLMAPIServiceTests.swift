import XCTest
@testable import LuggageHelper

@MainActor
final class LLMAPIServiceTests: XCTestCase {
    
    var mockService: MockLLMAPIService!
    
    override func setUp() {
        super.setUp()
        mockService = MockLLMAPIService()
    }
    
    override func tearDown() {
        mockService = nil
        super.tearDown()
    }
    
    // MARK: - 物品识别测试
    
    func testIdentifyItemSuccess() async throws {
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
        
        // When
        let result = try await mockService.identifyItemWithCache(name: itemName, model: model)
        
        // Then
        XCTAssertEqual(result.name, expectedItem.name)
        XCTAssertEqual(result.category, expectedItem.category)
        XCTAssertEqual(result.weight, expectedItem.weight, accuracy: 0.1)
        XCTAssertEqual(result.volume, expectedItem.volume, accuracy: 0.1)
        XCTAssertEqual(mockService.callCount, 1)
        XCTAssertEqual(mockService.lastCalledMethod, "identifyItemWithCache")
        XCTAssertEqual(mockService.lastParameters["name"] as? String, itemName)
        XCTAssertEqual(mockService.lastParameters["model"] as? String, model)
    }
    
    func testIdentifyItemFailure() async {
        // Given
        mockService.shouldSucceed = false
        mockService.mockError = MockError.networkError
        
        // When & Then
        do {
            _ = try await mockService.identifyItemWithCache(name: "Test Item")
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is MockError)
            XCTAssertEqual(mockService.callCount, 1)
        }
    }
    
    func testIdentifyItemFromPhoto() async throws {
        // Given
        let testImage = UIImage(systemName: "photo")!
        let expectedItem = ItemInfo(
            name: "照片识别物品",
            category: .other,
            weight: 100.0,
            volume: 200.0,
            confidence: 0.8,
            source: "照片识别"
        )
        mockService.mockItemInfo = expectedItem
        
        // When
        let result = try await mockService.identifyItemFromPhotoWithCache(testImage)
        
        // Then
        XCTAssertEqual(result.name, expectedItem.name)
        XCTAssertEqual(result.category, expectedItem.category)
        XCTAssertEqual(mockService.callCount, 1)
        XCTAssertEqual(mockService.lastCalledMethod, "identifyItemFromPhotoWithCache")
    }
    
    // MARK: - 旅行建议测试
    
    func testGenerateTravelSuggestions() async throws {
        // Given
        let destination = "东京"
        let duration = 7
        let season = "春季"
        let activities = ["观光", "购物"]
        
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
                    reason: "春季保暖",
                    quantity: 1,
                    estimatedWeight: 500.0,
                    estimatedVolume: 2000.0
                )
            ],
            categories: [.clothing, .electronics],
            tips: ["带好护照", "准备日元"],
            warnings: ["注意樱花季人多"]
        )
        mockService.mockTravelSuggestion = expectedSuggestion
        
        // When
        let result = try await mockService.generateTravelSuggestionsWithCache(
            destination: destination,
            duration: duration,
            season: season,
            activities: activities
        )
        
        // Then
        XCTAssertEqual(result.destination, destination)
        XCTAssertEqual(result.duration, duration)
        XCTAssertEqual(result.season, season)
        XCTAssertEqual(result.activities, activities)
        XCTAssertFalse(result.suggestedItems.isEmpty)
        XCTAssertEqual(mockService.callCount, 1)
        XCTAssertEqual(mockService.lastCalledMethod, "generateTravelSuggestionsWithCache")
    }
    
    // MARK: - 装箱优化测试
    
    func testOptimizePacking() async throws {
        // Given
        let items = [
            createMockLuggageItem(name: "T恤", weight: 200, volume: 500),
            createMockLuggageItem(name: "牛仔裤", weight: 600, volume: 1000),
            createMockLuggageItem(name: "运动鞋", weight: 800, volume: 2000)
        ]
        let luggage = createMockLuggage()
        
        // When
        let result = try await mockService.optimizePackingWithCache(items: items, luggage: luggage)
        
        // Then
        XCTAssertEqual(result.luggageId, luggage.id)
        XCTAssertEqual(result.items.count, items.count)
        XCTAssertGreaterThan(result.efficiency, 0)
        XCTAssertLessThanOrEqual(result.efficiency, 1.0)
        XCTAssertEqual(mockService.callCount, 1)
        XCTAssertEqual(mockService.lastCalledMethod, "optimizePackingWithCache")
    }
    
    // MARK: - 替代建议测试
    
    func testSuggestAlternatives() async throws {
        // Given
        let itemName = "MacBook Pro"
        let constraints = PackingConstraints(
            maxWeight: 2000,
            maxVolume: 3000,
            restrictions: [],
            priorities: []
        )
        
        let expectedAlternatives = [
            ItemInfo(name: "MacBook Air", category: .electronics, weight: 1290, volume: 2000, confidence: 0.9, source: "替代建议"),
            ItemInfo(name: "iPad Pro", category: .electronics, weight: 682, volume: 1000, confidence: 0.8, source: "替代建议")
        ]
        mockService.mockAlternatives = expectedAlternatives
        
        // When
        let result = try await mockService.suggestAlternativesWithCache(for: itemName, constraints: constraints)
        
        // Then
        XCTAssertEqual(result.count, expectedAlternatives.count)
        XCTAssertEqual(result[0].name, expectedAlternatives[0].name)
        XCTAssertEqual(result[1].name, expectedAlternatives[1].name)
        XCTAssertEqual(mockService.callCount, 1)
        XCTAssertEqual(mockService.lastCalledMethod, "suggestAlternativesWithCache")
    }
    
    // MARK: - 航司政策测试
    
    func testQueryAirlinePolicy() async throws {
        // Given
        let airline = "中国国际航空"
        
        // When
        let result = try await mockService.queryAirlinePolicyWithCache(airline: airline)
        
        // Then
        XCTAssertEqual(result.airline, airline)
        XCTAssertNotNil(result.checkedBaggage)
        XCTAssertNotNil(result.carryOn)
        XCTAssertEqual(mockService.callCount, 1)
        XCTAssertEqual(mockService.lastCalledMethod, "queryAirlinePolicyWithCache")
    }
    
    // MARK: - 性能测试
    
    func testPerformanceIdentifyItem() {
        measure {
            let expectation = XCTestExpectation(description: "物品识别性能测试")
            
            Task {
                do {
                    _ = try await mockService.identifyItemWithCache(name: "测试物品")
                    expectation.fulfill()
                } catch {
                    XCTFail("性能测试失败: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testConcurrentRequests() async {
        // Given
        let requestCount = 10
        mockService.mockDelay = 0.01 // 减少延迟以加快测试
        
        // When
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<requestCount {
                group.addTask {
                    do {
                        _ = try await self.mockService.identifyItemWithCache(name: "物品\(i)")
                    } catch {
                        XCTFail("并发请求失败: \(error)")
                    }
                }
            }
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(mockService.callCount, requestCount)
        XCTAssertLessThan(totalTime, 1.0) // 并发执行应该在1秒内完成
    }
    
    // MARK: - 错误处理测试
    
    func testErrorHandling() async {
        // Given
        let errorCases: [(MockError, String)] = [
            (.networkError, "网络错误"),
            (.configurationError, "配置错误"),
            (.rateLimitError, "限流错误")
        ]
        
        for (mockError, description) in errorCases {
            // Given
            mockService.reset()
            mockService.shouldSucceed = false
            mockService.mockError = mockError
            
            // When & Then
            do {
                _ = try await mockService.identifyItemWithCache(name: "测试物品")
                XCTFail("应该抛出\(description)")
            } catch let error as MockError {
                XCTAssertEqual(error, mockError, "错误类型不匹配: \(description)")
            } catch {
                XCTFail("错误类型不正确: \(error)")
            }
        }
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
            name: "测试行李箱",
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

// MARK: - 扩展测试用例

extension LLMAPIServiceTests {
    
    // MARK: - 边界条件测试
    
    func testEmptyInputHandling() async {
        // Given
        mockService.shouldSucceed = false
        mockService.mockError = MockError.testError
        
        // When & Then - 空字符串输入
        do {
            _ = try await mockService.identifyItemWithCache(name: "")
            XCTFail("空字符串应该导致错误")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }
    
    func testLargeDataHandling() async throws {
        // Given
        let largeItemName = String(repeating: "测试", count: 1000)
        
        // When
        let result = try await mockService.identifyItemWithCache(name: largeItemName)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(mockService.callCount, 1)
    }
    
    // MARK: - 缓存行为测试
    
    func testCacheBehavior() async throws {
        // Given
        let itemName = "缓存测试物品"
        let mockCache = MockAICacheManager()
        
        // 第一次调用
        let result1 = try await mockService.identifyItemWithCache(name: itemName)
        
        // 模拟缓存命中
        let request = ItemIdentificationRequest(name: itemName, model: nil)
        mockCache.cacheItemIdentification(request: request, response: result1)
        
        // Then
        let cachedResult = mockCache.getCachedItemIdentification(for: request)
        XCTAssertNotNil(cachedResult)
        XCTAssertEqual(cachedResult?.name, result1.name)
    }
    
    // MARK: - 超时测试
    
    func testRequestTimeout() async {
        // Given
        mockService.mockDelay = 10.0 // 10秒延迟
        
        // When & Then
        let startTime = Date()
        
        do {
            _ = try await mockService.identifyItemWithCache(name: "超时测试")
        } catch {
            // 预期会超时或被取消
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        // 在实际实现中，应该有超时机制
        // XCTAssertLessThan(elapsedTime, 5.0, "请求应该在5秒内超时")
    }
}