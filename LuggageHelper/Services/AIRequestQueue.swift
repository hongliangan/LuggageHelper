import Foundation

// MARK: - AI Request Queue Manager
actor AIRequestQueue {
    static let shared = AIRequestQueue()
    
    private var pendingRequests: [AIRequest] = []
    private var activeRequests: Set<UUID> = []
    private let maxConcurrentRequests = 3
    private let requestTimeout: TimeInterval = 30.0
    
    private init() {}
    
    // MARK: - Request Management
    
    func enqueue<T>(_ request: AIRequest, handler: @escaping () async throws -> T) async throws -> T {
        // Check if similar request is already in progress
        if let existingRequest = findSimilarRequest(request) {
            return try await waitForExistingRequest(existingRequest, expectedType: T.self)
        }
        
        // Add to pending queue
        pendingRequests.append(request)
        
        // Wait for available slot
        try await waitForAvailableSlot()
        
        // Move to active requests
        activeRequests.insert(request.id)
        removeFromPending(request.id)
        
        do {
            // Execute request with timeout
            let result = try await withTimeout(requestTimeout) {
                try await handler()
            }
            
            // Mark as completed
            activeRequests.remove(request.id)
            
            return result
        } catch {
            // Remove from active on error
            activeRequests.remove(request.id)
            throw error
        }
    }
    
    private func findSimilarRequest(_ request: AIRequest) -> AIRequest? {
        return pendingRequests.first { $0.isSimilar(to: request) } ??
               activeRequests.compactMap { id in pendingRequests.first { $0.id == id } }.first { $0.isSimilar(to: request) }
    }
    
    private func waitForExistingRequest<T>(_ request: AIRequest, expectedType: T.Type) async throws -> T {
        // Wait for the existing request to complete
        while activeRequests.contains(request.id) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // This is a simplified implementation - in a real scenario,
        // you'd want to share the actual result between similar requests
        throw AIError.requestDuplicatedError
    }
    
    private func waitForAvailableSlot() async throws {
        while activeRequests.count >= maxConcurrentRequests {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func removeFromPending(_ id: UUID) {
        pendingRequests.removeAll { $0.id == id }
    }
    
    // MARK: - Queue Status
    
    func getQueueStatus() -> QueueStatus {
        return QueueStatus(
            pendingCount: pendingRequests.count,
            activeCount: activeRequests.count,
            maxConcurrent: maxConcurrentRequests
        )
    }
    
    func cancelRequest(_ id: UUID) {
        pendingRequests.removeAll { $0.id == id }
        activeRequests.remove(id)
    }
    
    func cancelAllRequests() {
        pendingRequests.removeAll()
        activeRequests.removeAll()
    }
}

// MARK: - AI Request Protocol

protocol AIRequestProtocol {
    var id: UUID { get }
    var type: AIRequestType { get }
    var priority: RequestPriority { get }
    var timestamp: Date { get }
    
    func isSimilar(to other: AIRequestProtocol) -> Bool
}

struct AIRequest: AIRequestProtocol {
    let id: UUID
    let type: AIRequestType
    let priority: RequestPriority
    let timestamp: Date
    let parameters: [String: Any]
    
    init(type: AIRequestType, priority: RequestPriority = .normal, parameters: [String: Any] = [:]) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.timestamp = Date()
        self.parameters = parameters
    }
    
    func isSimilar(to other: AIRequestProtocol) -> Bool {
        guard let otherRequest = other as? AIRequest else { return false }
        
        // Check if same type
        guard type == otherRequest.type else { return false }
        
        // Check similarity based on request type
        switch type {
        case .itemIdentification:
            return parameters["name"] as? String == otherRequest.parameters["name"] as? String &&
                   parameters["model"] as? String == otherRequest.parameters["model"] as? String
            
        case .photoRecognition:
            return parameters["imageHash"] as? String == otherRequest.parameters["imageHash"] as? String
            
        case .travelSuggestions:
            return parameters["destination"] as? String == otherRequest.parameters["destination"] as? String &&
                   parameters["duration"] as? Int == otherRequest.parameters["duration"] as? Int &&
                   parameters["season"] as? String == otherRequest.parameters["season"] as? String
            
        case .packingOptimization:
            return parameters["luggageId"] as? UUID == otherRequest.parameters["luggageId"] as? UUID
            
        case .alternatives:
            return parameters["itemName"] as? String == otherRequest.parameters["itemName"] as? String
            
        case .airlinePolicy:
            return parameters["airline"] as? String == otherRequest.parameters["airline"] as? String
            
        case .weightPrediction:
            return parameters["itemIds"] as? [UUID] == otherRequest.parameters["itemIds"] as? [UUID]
            
        case .missingItemsCheck:
            return parameters["travelPlanId"] as? UUID == otherRequest.parameters["travelPlanId"] as? UUID
        }
    }
}

enum AIRequestType: String, CaseIterable {
    case itemIdentification
    case photoRecognition
    case travelSuggestions
    case packingOptimization
    case alternatives
    case airlinePolicy
    case weightPrediction
    case missingItemsCheck
}

enum RequestPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
}

struct QueueStatus {
    let pendingCount: Int
    let activeCount: Int
    let maxConcurrent: Int
    
    var isAtCapacity: Bool {
        return activeCount >= maxConcurrent
    }
    
    var availableSlots: Int {
        return max(0, maxConcurrent - activeCount)
    }
}

// MARK: - Timeout Helper

func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw AIError.requestTimeoutError
        }
        
        guard let result = try await group.next() else {
            throw AIError.requestTimeoutError
        }
        
        group.cancelAll()
        return result
    }
}

// MARK: - AI Error Definition

enum AIError: Error {
    case networkError(Error)
    case invalidResponse
    case requestTimeout
    case requestDuplicated
    case decodingError(Error)
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效响应"
        case .requestTimeout:
            return "请求超时"
        case .requestDuplicated:
            return "相似请求正在进行中"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Error Extensions

extension AIError {
    static let requestTimeoutError = AIError.requestTimeout
    static let requestDuplicatedError = AIError.requestDuplicated
}