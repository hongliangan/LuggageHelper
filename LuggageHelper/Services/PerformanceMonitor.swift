import Foundation
import os.log

// MARK: - 性能监控服务
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.luggagehelper.performance", category: "Monitor")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 性能统计数据
    
    @Published var requestStats: [String: RequestStats] = [:]
    @Published var cacheStats: CachePerformanceStats = CachePerformanceStats()
    @Published var systemStats: SystemPerformanceStats = SystemPerformanceStats()
    
    private var requestTimers: [UUID: Date] = [:]
    
    private init() {
        loadPerformanceData()
        startSystemMonitoring()
    }
    
    // MARK: - 请求性能监控
    
    /// 开始监控请求
    func startRequest(id: UUID, type: AIRequestType) {
        requestTimers[id] = Date()
        
        var stats = requestStats[type.rawValue] ?? RequestStats(requestType: type.rawValue)
        stats.totalRequests += 1
        requestStats[type.rawValue] = stats
    }
    
    /// 结束监控请求（成功）
    func endRequest(id: UUID, type: AIRequestType, fromCache: Bool = false) {
        guard let startTime = requestTimers[id] else { return }
        
        let responseTime = Date().timeIntervalSince(startTime) * 1000 // 转换为毫秒
        requestTimers.removeValue(forKey: id)
        
        var stats = requestStats[type.rawValue] ?? RequestStats(requestType: type.rawValue)
        stats.successfulRequests += 1
        stats.totalResponseTime += responseTime
        stats.averageResponseTime = stats.totalResponseTime / Double(stats.successfulRequests)
        
        if fromCache {
            stats.cacheHits += 1
        }
        
        stats.cacheHitRate = Double(stats.cacheHits) / Double(stats.totalRequests)
        stats.successRate = Double(stats.successfulRequests) / Double(stats.totalRequests)
        
        requestStats[type.rawValue] = stats
        
        logger.info("请求完成: \(type.rawValue), 响应时间: \(String(format: "%.2f", responseTime))ms, 来自缓存: \(fromCache)")
    }
    
    /// 记录请求失败
    func recordRequestFailure(id: UUID, type: AIRequestType, error: Error) {
        requestTimers.removeValue(forKey: id)
        
        var stats = requestStats[type.rawValue] ?? RequestStats(requestType: type.rawValue)
        stats.failedRequests += 1
        stats.successRate = Double(stats.successfulRequests) / Double(stats.totalRequests)
        
        requestStats[type.rawValue] = stats
        
        logger.error("请求失败: \(type.rawValue), 错误: \(error.localizedDescription)")
    }
    
    // MARK: - 缓存性能监控
    
    /// 记录缓存命中
    func recordCacheHit(type: AIRequestType, size: Int) {
        cacheStats.totalHits += 1
        cacheStats.totalSize += size
        cacheStats.hitsByType[type.rawValue, default: 0] += 1
        
        updateCacheHitRate()
    }
    
    /// 记录缓存未命中
    func recordCacheMiss(type: AIRequestType) {
        cacheStats.totalMisses += 1
        cacheStats.missesByType[type.rawValue, default: 0] += 1
        
        updateCacheHitRate()
    }
    
    /// 记录缓存写入
    func recordCacheWrite(type: AIRequestType, size: Int) {
        cacheStats.totalWrites += 1
        cacheStats.totalSize += size
        cacheStats.writesByType[type.rawValue, default: 0] += 1
    }
    
    /// 记录缓存清理
    func recordCacheCleanup(removedEntries: Int, freedSize: Int) {
        cacheStats.cleanupCount += 1
        cacheStats.totalSize -= freedSize
        cacheStats.lastCleanup = Date()
        
        logger.info("缓存清理完成: 移除 \(removedEntries) 条目, 释放 \(freedSize) 字节")
    }
    
    private func updateCacheHitRate() {
        let totalRequests = cacheStats.totalHits + cacheStats.totalMisses
        cacheStats.hitRate = totalRequests > 0 ? Double(cacheStats.totalHits) / Double(totalRequests) : 0.0
    }
    
    // MARK: - 系统性能监控
    
    private func startSystemMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateSystemStats()
            }
        }
    }
    
    private func updateSystemStats() {
        systemStats.memoryUsage = getMemoryUsage()
        systemStats.cpuUsage = getCPUUsage()
        systemStats.diskUsage = getDiskUsage()
        systemStats.lastUpdated = Date()
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
        
        return 0.0
    }
    
    private func getCPUUsage() -> Double {
        // 简化的CPU使用率获取
        return 0.0 // 实际实现需要更复杂的系统调用
    }
    
    private func getDiskUsage() -> Double {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            
            if let available = resourceValues.volumeAvailableCapacity,
               let total = resourceValues.volumeTotalCapacity {
                return Double(total - available) / Double(total) * 100.0
            }
        } catch {
            logger.error("获取磁盘使用率失败: \(error.localizedDescription)")
        }
        
        return 0.0
    }
    
    // MARK: - 数据持久化
    
    private func loadPerformanceData() {
        if let data = userDefaults.data(forKey: "performance_request_stats"),
           let stats = try? JSONDecoder().decode([String: RequestStats].self, from: data) {
            requestStats = stats
        }
        
        if let data = userDefaults.data(forKey: "performance_cache_stats"),
           let stats = try? JSONDecoder().decode(CachePerformanceStats.self, from: data) {
            cacheStats = stats
        }
    }
    
    func savePerformanceData() {
        do {
            let requestData = try JSONEncoder().encode(requestStats)
            userDefaults.set(requestData, forKey: "performance_request_stats")
            
            let cacheData = try JSONEncoder().encode(cacheStats)
            userDefaults.set(cacheData, forKey: "performance_cache_stats")
        } catch {
            logger.error("保存性能数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 性能报告
    
    func generatePerformanceReport() -> PerformanceReport {
        let totalRequests = requestStats.values.reduce(0) { $0 + $1.totalRequests }
        let totalSuccessful = requestStats.values.reduce(0) { $0 + $1.successfulRequests }
        let totalFailed = requestStats.values.reduce(0) { $0 + $1.failedRequests }
        let averageResponseTime = requestStats.values.reduce(0.0) { $0 + $1.averageResponseTime } / Double(requestStats.count)
        
        return PerformanceReport(
            totalRequests: totalRequests,
            successfulRequests: totalSuccessful,
            failedRequests: totalFailed,
            overallSuccessRate: totalRequests > 0 ? Double(totalSuccessful) / Double(totalRequests) : 0.0,
            averageResponseTime: averageResponseTime,
            cacheHitRate: cacheStats.hitRate,
            cacheSize: cacheStats.totalSize,
            memoryUsage: systemStats.memoryUsage,
            requestsByType: requestStats,
            generatedAt: Date()
        )
    }
    
    /// 重置性能统计
    func resetStats() {
        requestStats.removeAll()
        cacheStats = CachePerformanceStats()
        systemStats = SystemPerformanceStats()
        
        userDefaults.removeObject(forKey: "performance_request_stats")
        userDefaults.removeObject(forKey: "performance_cache_stats")
        
        logger.info("性能统计已重置")
    }
    
    /// 获取性能警告
    func getPerformanceWarnings() -> [PerformanceWarning] {
        var warnings: [PerformanceWarning] = []
        
        // 检查响应时间
        for (type, stats) in requestStats {
            if stats.averageResponseTime > 5000 { // 5秒
                warnings.append(PerformanceWarning(
                    type: .slowResponse,
                    message: "\(type) 平均响应时间过长: \(String(format: "%.2f", stats.averageResponseTime))ms",
                    severity: .high
                ))
            }
        }
        
        // 检查成功率
        for (type, stats) in requestStats {
            if stats.successRate < 0.9 { // 90%
                warnings.append(PerformanceWarning(
                    type: .lowSuccessRate,
                    message: "\(type) 成功率过低: \(String(format: "%.1f", stats.successRate * 100))%",
                    severity: .medium
                ))
            }
        }
        
        // 检查缓存命中率
        if cacheStats.hitRate < 0.3 { // 30%
            warnings.append(PerformanceWarning(
                type: .lowCacheHitRate,
                message: "缓存命中率过低: \(String(format: "%.1f", cacheStats.hitRate * 100))%",
                severity: .medium
            ))
        }
        
        // 检查内存使用
        if systemStats.memoryUsage > 200 { // 200MB
            warnings.append(PerformanceWarning(
                type: .highMemoryUsage,
                message: "内存使用过高: \(String(format: "%.1f", systemStats.memoryUsage))MB",
                severity: .high
            ))
        }
        
        return warnings
    }
}

// MARK: - 性能数据结构

struct RequestStats: Codable {
    let requestType: String
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var cacheHits: Int = 0
    var totalResponseTime: Double = 0.0
    var averageResponseTime: Double = 0.0
    var successRate: Double = 1.0
    var cacheHitRate: Double = 0.0
    var lastRequest: Date = Date()
}

struct CachePerformanceStats: Codable {
    var totalHits: Int = 0
    var totalMisses: Int = 0
    var totalWrites: Int = 0
    var totalSize: Int = 0
    var hitRate: Double = 0.0
    var cleanupCount: Int = 0
    var lastCleanup: Date?
    var hitsByType: [String: Int] = [:]
    var missesByType: [String: Int] = [:]
    var writesByType: [String: Int] = [:]
}

struct SystemPerformanceStats: Codable {
    var memoryUsage: Double = 0.0 // MB
    var cpuUsage: Double = 0.0 // %
    var diskUsage: Double = 0.0 // %
    var lastUpdated: Date = Date()
}

struct PerformanceReport: Codable {
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let overallSuccessRate: Double
    let averageResponseTime: Double
    let cacheHitRate: Double
    let cacheSize: Int
    let memoryUsage: Double
    let requestsByType: [String: RequestStats]
    let generatedAt: Date
}

struct PerformanceWarning: Identifiable {
    let id = UUID()
    let type: WarningType
    let message: String
    let severity: Severity
    
    enum WarningType {
        case slowResponse
        case lowSuccessRate
        case lowCacheHitRate
        case highMemoryUsage
        case highErrorRate
    }
    
    enum Severity {
        case low, medium, high, critical
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
}