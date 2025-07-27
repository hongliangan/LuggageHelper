import Foundation
@testable import LuggageHelper

// MARK: - Mock LLM API Service
class MockLLMAPIService: LLMAPIService {
    
    // MARK: - Mock Configuration
    var shouldSucceed = true
    var mockDelay: TimeInterval = 0.1
    var mockError: Error?
    var callCount = 0
    var lastCalledMethod: String?
    var lastParameters: [String: Any] = [:]
    
    // MARK: - Mock Data
    var mockItemInfo: ItemInfo?
    var mockTravelSuggestion: TravelSuggestion?
    var mockPackingPlan: PackingPlan?
    var mockAlternatives: [ItemInfo] = []
    var mockAirlinePolicy: AirlinePolicy?
    
    // MARK: - Reset Method
    func reset() {
        shouldSucceed = true
        mockDelay = 0.1
        mockError = nil
        callCount = 0
        lastCalledMethod = nil
        lastParameters.removeAll()
        
        mockItemInfo = nil
        mockTravelSuggestion = nil
        mockPackingPlan = nil
        mockAlternatives.removeAll()
        mockAirlinePolicy = nil
    }
    
    // MARK: - Mock Implementation
    
    override func identifyItemWithCache(name: String, model: String? = nil) async throws -> ItemInfo {
        callCount += 1
        lastCalledMethod = "identifyItemWithCache"
        lastParameters = ["name": name, "model": model ?? ""]
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError ?? MockError.testError
        }
        
        return mockItemInfo ?? createMockItemInfo(name: name)
    }
    
    override func identifyItemFromPhotoWithCache(_ image: UIImage) async throws -> ItemInfo {
        callCount += 1
        lastCalledMethod = "identifyItemFromPhotoWithCache"
        lastParameters = ["imageSize": "\(image.size)"]
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError ?? MockError.testError
        }
        
        return mockItemInfo ?? createMockItemInfo(name: "照片识别物品")
    }
    
    override func generateTravelSuggestionsWithCache(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userPreferences: UserPreferences? = nil
    ) async throws -> TravelSuggestion {
        callCount += 1
        lastCalledMethod = "generateTravelSuggestionsWithCache"
        lastParameters = [
            "destination": destination,
            "duration": duration,
            "season": season,
            "activities": activities
        ]
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError ?? MockError.testError
        }
        
        return mockTravelSuggestion ?? createMockTravelSuggestion(destination: destination, duration: duration)
    }
    
    override func optimizePackingWithCache(items: [LuggageItem], luggage: Luggage) async throws -> PackingPlan {
        callCount += 1
        lastCalledMethod = "optimizePackingWithCache"
        lastParameters = [
            "itemCount": items.count,
            "luggageId": luggage.id.uuidString
        ]
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError ?? MockError.testError
        }
        
        return mockPackingPlan ?? createMockPackingPlan(items: items, luggage: luggage)
    }
    
    override func suggestAlternativesWithCache(
        for itemName: String,
        constraints: PackingConstraints
    ) async throws -> [ItemInfo] {
        callCount += 1
        lastCalledMethod = "suggestAlternativesWithCache"
        lastParameters = [
            "itemName": itemName,
            "maxWeight": constraints.maxWeight,
            "maxVolume": constraints.maxVolume
        ]
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError ?? MockError.testError
        }
        
        return mockAlternatives.isEmpty ? createMockAlternatives(for: itemName) : mockAlternatives
    }
    
    override func queryAirlinePolicyWithCache(airline: String) async throws -> AirlinePolicy {
        callCount += 1
        lastCalledMethod = "queryAirlinePolicyWithCache"
        lastParameters = ["airline": airline]
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError ?? MockError.testError
        }
        
        return mockAirlinePolicy ?? createMockAirlinePolicy(airline: airline)
    }
    
    // MARK: - Mock Data Creators
    
    private func createMockItemInfo(name: String) -> ItemInfo {
        return ItemInfo(
            name: name,
            category: .electronics,
            weight: 500.0,
            volume: 1000.0,
            dimensions: Dimensions(length: 10, width: 5, height: 2),
            confidence: 0.9,
            source: "Mock测试"
        )
    }
    
    private func createMockTravelSuggestion(destination: String, duration: Int) -> TravelSuggestion {
        let suggestedItems = [
            SuggestedItem(
                name: "T恤",
                category: .clothing,
                importance: .essential,
                reason: "基础衣物",
                quantity: duration / 2,
                estimatedWeight: 200.0,
                estimatedVolume: 500.0
            ),
            SuggestedItem(
                name: "充电器",
                category: .electronics,
                importance: .important,
                reason: "电子设备充电",
                quantity: 1,
                estimatedWeight: 300.0,
                estimatedVolume: 200.0
            )
        ]
        
        return TravelSuggestion(
            destination: destination,
            duration: duration,
            season: "春季",
            activities: ["观光", "购物"],
            suggestedItems: suggestedItems,
            categories: [.clothing, .electronics],
            tips: ["记得带护照", "检查天气预报"],
            warnings: ["注意当地法规"]
        )
    }
    
    private func createMockPackingPlan(items: [LuggageItem], luggage: Luggage) -> PackingPlan {
        let packingItems = items.enumerated().map { index, item in
            PackingItem(
                itemId: item.id,
                position: index % 2 == 0 ? .bottom : .top,
                priority: 5,
                reason: "Mock装箱建议"
            )
        }
        
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalVolume = items.reduce(0) { $0 + $1.volume }
        
        return PackingPlan(
            luggageId: luggage.id,
            items: packingItems,
            totalWeight: totalWeight,
            totalVolume: totalVolume,
            efficiency: 0.8,
            warnings: [],
            suggestions: ["Mock装箱建议"]
        )
    }
    
    private func createMockAlternatives(for itemName: String) -> [ItemInfo] {
        return [
            ItemInfo(
                name: "\(itemName) 轻量版",
                category: .other,
                weight: 300.0,
                volume: 600.0,
                confidence: 0.8,
                source: "Mock替代建议"
            ),
            ItemInfo(
                name: "\(itemName) 便携版",
                category: .other,
                weight: 250.0,
                volume: 500.0,
                confidence: 0.7,
                source: "Mock替代建议"
            )
        ]
    }
    
    private func createMockAirlinePolicy(airline: String) -> AirlinePolicy {
        return AirlinePolicy(
            airline: airline,
            lastUpdated: "2024-01-01",
            checkedBaggage: AirlinePolicy.CheckedBaggagePolicy(
                weightLimit: 23.0,
                sizeLimit: AirlinePolicy.SizeLimit(length: 158, width: 158, height: 158),
                pieces: 1,
                fees: []
            ),
            carryOn: AirlinePolicy.CarryOnPolicy(
                weightLimit: 7.0,
                sizeLimit: AirlinePolicy.SizeLimit(length: 55, width: 40, height: 20),
                pieces: 1
            ),
            restrictions: [],
            specialItems: [],
            tips: ["Mock航司政策提示"],
            contactInfo: AirlinePolicy.ContactInfo(
                phone: "400-000-0000",
                website: "https://mock-airline.com",
                email: "service@mock-airline.com"
            )
        )
    }
}

// MARK: - Mock Error
enum MockError: Error, LocalizedError {
    case testError
    case networkError
    case configurationError
    case rateLimitError
    
    var errorDescription: String? {
        switch self {
        case .testError:
            return "Mock测试错误"
        case .networkError:
            return "Mock网络错误"
        case .configurationError:
            return "Mock配置错误"
        case .rateLimitError:
            return "Mock限流错误"
        }
    }
}

// MARK: - Mock Network Monitor
class MockNetworkMonitor: NetworkMonitor {
    var mockIsConnected = true
    var mockConnectionType: ConnectionType = .wifi
    var mockIsExpensive = false
    var mockIsConstrained = false
    var mockConnectionQuality: ConnectionQuality = .good
    
    override var isConnected: Bool {
        return mockIsConnected
    }
    
    override var connectionType: ConnectionType {
        return mockConnectionType
    }
    
    override var isExpensive: Bool {
        return mockIsExpensive
    }
    
    override var isConstrained: Bool {
        return mockIsConstrained
    }
    
    override func testConnection() async -> ConnectionTestResult {
        if mockIsConnected {
            return ConnectionTestResult(
                isSuccessful: true,
                responseTime: 100.0,
                error: nil
            )
        } else {
            return ConnectionTestResult(
                isSuccessful: false,
                responseTime: 0,
                error: "Mock网络连接失败"
            )
        }
    }
    
    override func assessConnectionQuality() async -> ConnectionQuality {
        return mockConnectionQuality
    }
}

// MARK: - Mock Cache Manager
class MockAICacheManager: AICacheManager {
    var mockCacheHits: [String: Any] = [:]
    var mockCacheStats = CacheStatistics(
        totalSize: 1024,
        totalEntries: 10,
        categoryCounts: ["test": 5],
        maxCacheSize: 50 * 1024 * 1024
    )
    
    override func getCachedItemIdentification(for request: ItemIdentificationRequest) -> ItemInfo? {
        let key = "\(request.name)_\(request.model ?? "")"
        return mockCacheHits[key] as? ItemInfo
    }
    
    override func cacheItemIdentification(request: ItemIdentificationRequest, response: ItemInfo) {
        let key = "\(request.name)_\(request.model ?? "")"
        mockCacheHits[key] = response
    }
    
    override func getCacheStatistics() -> CacheStatistics {
        return mockCacheStats
    }
    
    override func clearAllCache() async {
        mockCacheHits.removeAll()
    }
}