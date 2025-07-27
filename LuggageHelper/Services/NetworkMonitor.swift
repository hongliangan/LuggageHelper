import Foundation
import Network
import SwiftUI

// MARK: - 网络状态监控服务
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    @Published var isConstrained = false
    @Published var connectionHistory: [ConnectionEvent] = []
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var lastConnectionCheck = Date()
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
    }
    
    // MARK: - 监控控制
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - 状态更新
    
    private func updateNetworkStatus(_ path: NWPath) {
        let wasConnected = isConnected
        let previousType = connectionType
        
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        connectionType = determineConnectionType(path)
        
        // 记录连接状态变化
        if wasConnected != isConnected || previousType != connectionType {
            recordConnectionEvent(
                wasConnected: wasConnected,
                isConnected: isConnected,
                previousType: previousType,
                currentType: connectionType
            )
        }
        
        // 通知其他服务网络状态变化
        if !isConnected {
            NotificationCenter.default.post(name: .networkDisconnected, object: nil)
        } else if !wasConnected && isConnected {
            NotificationCenter.default.post(name: .networkReconnected, object: nil)
        }
    }
    
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }
    
    // MARK: - 连接测试
    
    /// 测试网络连接
    func testConnection() async -> NetworkConnectionTestResult {
        guard isConnected else {
            return NetworkConnectionTestResult(
                isSuccessful: false,
                responseTime: 0,
                error: "设备未连接到网络"
            )
        }
        
        let startTime = Date()
        
        do {
            let url = URL(string: "https://www.apple.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            let responseTime = Date().timeIntervalSince(startTime) * 1000 // 毫秒
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return NetworkConnectionTestResult(
                    isSuccessful: true,
                    responseTime: responseTime,
                    error: nil
                )
            } else {
                return NetworkConnectionTestResult(
                    isSuccessful: false,
                    responseTime: responseTime,
                    error: "服务器响应异常"
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            return NetworkConnectionTestResult(
                isSuccessful: false,
                responseTime: responseTime,
                error: error.localizedDescription
            )
        }
    }
    
    /// 测试特定URL的连接
    func testConnection(to urlString: String) async -> NetworkConnectionTestResult {
        guard isConnected else {
            return NetworkConnectionTestResult(
                isSuccessful: false,
                responseTime: 0,
                error: "设备未连接到网络"
            )
        }
        
        guard let url = URL(string: urlString) else {
            return NetworkConnectionTestResult(
                isSuccessful: false,
                responseTime: 0,
                error: "无效的URL地址"
            )
        }
        
        let startTime = Date()
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            
            if let httpResponse = response as? HTTPURLResponse,
               200...299 ~= httpResponse.statusCode {
                return NetworkConnectionTestResult(
                    isSuccessful: true,
                    responseTime: responseTime,
                    error: nil
                )
            } else {
                return NetworkConnectionTestResult(
                    isSuccessful: false,
                    responseTime: responseTime,
                    error: "服务器响应异常"
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            return NetworkConnectionTestResult(
                isSuccessful: false,
                responseTime: responseTime,
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - 连接质量评估
    
    /// 评估连接质量
    func assessConnectionQuality() async -> ConnectionQuality {
        let testResult = await testConnection()
        
        guard testResult.isSuccessful else {
            return .poor
        }
        
        let responseTime = testResult.responseTime
        
        if responseTime < 100 {
            return .excellent
        } else if responseTime < 300 {
            return .good
        } else if responseTime < 1000 {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// 获取网络建议
    func getNetworkRecommendations() -> [NetworkRecommendation] {
        var recommendations: [NetworkRecommendation] = []
        
        if !isConnected {
            recommendations.append(NetworkRecommendation(
                type: .connection,
                title: "网络连接问题",
                description: "设备未连接到网络",
                actions: [
                    "检查WiFi或移动数据连接",
                    "重启网络设置",
                    "联系网络服务提供商"
                ]
            ))
        } else {
            if isExpensive {
                recommendations.append(NetworkRecommendation(
                    type: .dataUsage,
                    title: "数据使用提醒",
                    description: "当前使用的是计费网络连接",
                    actions: [
                        "考虑连接到WiFi网络",
                        "限制AI功能的使用频率",
                        "在设置中启用数据节省模式"
                    ]
                ))
            }
            
            if isConstrained {
                recommendations.append(NetworkRecommendation(
                    type: .performance,
                    title: "网络性能受限",
                    description: "当前网络连接受到限制，可能影响AI功能性能",
                    actions: [
                        "切换到更稳定的网络",
                        "减少同时进行的网络请求",
                        "等待网络状况改善"
                    ]
                ))
            }
            
            if connectionType == .cellular {
                recommendations.append(NetworkRecommendation(
                    type: .optimization,
                    title: "移动网络优化",
                    description: "使用移动网络时建议优化数据使用",
                    actions: [
                        "启用缓存功能减少重复请求",
                        "在WiFi环境下进行大量AI操作",
                        "监控数据使用量"
                    ]
                ))
            }
        }
        
        return recommendations
    }
    
    // MARK: - 离线模式支持
    
    /// 检查功能是否可以离线使用
    func canUseOffline(_ feature: OfflineFeature) -> Bool {
        switch feature {
        case .itemManagement:
            return true // 物品管理可以离线使用
        case .luggageManagement:
            return true // 行李箱管理可以离线使用
        case .checklistManagement:
            return true // 清单管理可以离线使用
        case .aiFeatures:
            return false // AI功能需要网络连接
        case .itemSearch:
            return false // 物品搜索需要网络连接
        case .dataSync:
            return false // 数据同步需要网络连接
        }
    }
    
    /// 获取离线可用功能列表
    func getOfflineAvailableFeatures() -> [OfflineFeature] {
        return OfflineFeature.allCases.filter { canUseOffline($0) }
    }
    
    /// 获取需要网络的功能列表
    func getOnlineRequiredFeatures() -> [OfflineFeature] {
        return OfflineFeature.allCases.filter { !canUseOffline($0) }
    }
    
    // MARK: - 连接历史记录
    
    private func recordConnectionEvent(wasConnected: Bool, isConnected: Bool, 
                                     previousType: ConnectionType, currentType: ConnectionType) {
        let event = ConnectionEvent(
            timestamp: Date(),
            wasConnected: wasConnected,
            isConnected: isConnected,
            previousType: previousType,
            currentType: currentType,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
        
        connectionHistory.insert(event, at: 0)
        
        // 限制历史记录数量
        if connectionHistory.count > 100 {
            connectionHistory = Array(connectionHistory.prefix(100))
        }
    }
    
    /// 获取连接统计
    func getConnectionStatistics() -> ConnectionStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-24 * 60 * 60)
        
        let recentEvents = connectionHistory.filter { $0.timestamp >= last24Hours }
        let disconnectionEvents = recentEvents.filter { !$0.isConnected && $0.wasConnected }
        let reconnectionEvents = recentEvents.filter { $0.isConnected && !$0.wasConnected }
        
        var typeDistribution: [ConnectionType: TimeInterval] = [:]
        // 这里可以添加更复杂的统计逻辑
        
        return ConnectionStatistics(
            totalEvents: connectionHistory.count,
            disconnections24h: disconnectionEvents.count,
            reconnections24h: reconnectionEvents.count,
            currentUptime: calculateCurrentUptime(),
            typeDistribution: typeDistribution
        )
    }
    
    private func calculateCurrentUptime() -> TimeInterval {
        guard let lastDisconnection = connectionHistory.first(where: { !$0.isConnected }) else {
            return 0 // 如果没有断开记录，返回0或者应用启动时间
        }
        
        return Date().timeIntervalSince(lastDisconnection.timestamp)
    }
}

// MARK: - 数据模型

enum ConnectionType: String, CaseIterable {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case other = "other"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "移动网络"
        case .ethernet: return "以太网"
        case .other: return "其他"
        case .unknown: return "未知"
        }
    }
    
    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .other: return "network"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum ConnectionQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

enum OfflineFeature: String, CaseIterable {
    case itemManagement = "itemManagement"
    case luggageManagement = "luggageManagement"
    case checklistManagement = "checklistManagement"
    case aiFeatures = "aiFeatures"
    case itemSearch = "itemSearch"
    case dataSync = "dataSync"
    
    var displayName: String {
        switch self {
        case .itemManagement: return "物品管理"
        case .luggageManagement: return "行李箱管理"
        case .checklistManagement: return "清单管理"
        case .aiFeatures: return "AI功能"
        case .itemSearch: return "物品搜索"
        case .dataSync: return "数据同步"
        }
    }
}

struct NetworkConnectionTestResult {
    let isSuccessful: Bool
    let responseTime: TimeInterval // 毫秒
    let error: String?
}

struct NetworkRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let actions: [String]
    
    enum RecommendationType {
        case connection
        case dataUsage
        case performance
        case optimization
    }
}

struct ConnectionEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let wasConnected: Bool
    let isConnected: Bool
    let previousType: ConnectionType
    let currentType: ConnectionType
    let isExpensive: Bool
    let isConstrained: Bool
}

struct ConnectionStatistics {
    let totalEvents: Int
    let disconnections24h: Int
    let reconnections24h: Int
    let currentUptime: TimeInterval
    let typeDistribution: [ConnectionType: TimeInterval]
}

// MARK: - 通知扩展

extension Notification.Name {
    static let networkDisconnected = Notification.Name("networkDisconnected")
    static let networkReconnected = Notification.Name("networkReconnected")
}