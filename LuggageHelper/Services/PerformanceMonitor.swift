import Foundation
import UIKit
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
    
    // MARK: - 资源使用跟踪
    
    /// 记录资源使用情况
    func recordResourceUsage(type: ResourceType, amount: Double, unit: String) {
        let usage = ResourceUsage(
            type: type,
            amount: amount,
            unit: unit,
            timestamp: Date()
        )
        
        systemStats.resourceUsages.append(usage)
        
        // 保持最近1000条记录
        if systemStats.resourceUsages.count > 1000 {
            systemStats.resourceUsages.removeFirst(systemStats.resourceUsages.count - 1000)
        }
        
        logger.info("记录资源使用: \(type.rawValue) = \(amount) \(unit)")
    }
    
    /// 记录网络使用情况
    func recordNetworkUsage(bytesReceived: Int64, bytesSent: Int64) {
        systemStats.totalBytesReceived += bytesReceived
        systemStats.totalBytesSent += bytesSent
        
        let networkUsage = NetworkUsage(
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            timestamp: Date()
        )
        
        systemStats.networkUsages.append(networkUsage)
        
        // 保持最近100条网络使用记录
        if systemStats.networkUsages.count > 100 {
            systemStats.networkUsages.removeFirst(systemStats.networkUsages.count - 100)
        }
    }
    
    /// 记录电池使用情况
    func recordBatteryUsage() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        if batteryLevel >= 0 { // -1 表示无法获取电池信息
            let batteryUsage = BatteryUsage(
                level: batteryLevel,
                state: batteryState,
                timestamp: Date()
            )
            
            systemStats.batteryUsages.append(batteryUsage)
            
            // 保持最近50条电池使用记录
            if systemStats.batteryUsages.count > 50 {
                systemStats.batteryUsages.removeFirst(systemStats.batteryUsages.count - 50)
            }
        }
    }
    
    /// 记录存储使用情况
    func recordStorageUsage() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let resourceValues = try documentsPath.resourceValues(forKeys: [
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ])
            
            if let available = resourceValues.volumeAvailableCapacity,
               let total = resourceValues.volumeTotalCapacity {
                
                let used = total - available
                let usagePercentage = Double(used) / Double(total) * 100
                
                let storageUsage = StorageUsage(
                    totalSpace: Int64(total),
                    usedSpace: Int64(used),
                    availableSpace: Int64(available),
                    usagePercentage: usagePercentage,
                    timestamp: Date()
                )
                
                systemStats.storageUsages.append(storageUsage)
                
                // 保持最近20条存储使用记录
                if systemStats.storageUsages.count > 20 {
                    systemStats.storageUsages.removeFirst(systemStats.storageUsages.count - 20)
                }
            }
        } catch {
            logger.error("获取存储使用情况失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取资源使用统计
    func getResourceStatistics() -> ResourceStatistics {
        let memoryUsages = systemStats.resourceUsages.filter { $0.type == .memory }
        let cpuUsages = systemStats.resourceUsages.filter { $0.type == .cpu }
        
        let avgMemory = memoryUsages.isEmpty ? 0 : memoryUsages.map { $0.amount }.reduce(0, +) / Double(memoryUsages.count)
        let avgCPU = cpuUsages.isEmpty ? 0 : cpuUsages.map { $0.amount }.reduce(0, +) / Double(cpuUsages.count)
        
        let recentNetworkUsage = systemStats.networkUsages.suffix(10)
        let totalRecentReceived = recentNetworkUsage.map { $0.bytesReceived }.reduce(0, +)
        let totalRecentSent = recentNetworkUsage.map { $0.bytesSent }.reduce(0, +)
        
        return ResourceStatistics(
            averageMemoryUsage: avgMemory,
            averageCPUUsage: avgCPU,
            totalBytesReceived: systemStats.totalBytesReceived,
            totalBytesSent: systemStats.totalBytesSent,
            recentBytesReceived: totalRecentReceived,
            recentBytesSent: totalRecentSent,
            currentBatteryLevel: systemStats.batteryUsages.last?.level ?? -1,
            storageUsagePercentage: systemStats.storageUsages.last?.usagePercentage ?? 0
        )
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
        
        // 检查电池使用
        if let batteryLevel = systemStats.batteryUsages.last?.level, batteryLevel < 0.2 {
            warnings.append(PerformanceWarning(
                type: .lowBattery,
                message: "电池电量过低: \(String(format: "%.0f", batteryLevel * 100))%",
                severity: .high
            ))
        }
        
        // 检查存储空间
        if let storageUsage = systemStats.storageUsages.last, storageUsage.usagePercentage > 90 {
            warnings.append(PerformanceWarning(
                type: .lowStorage,
                message: "存储空间不足: 已使用 \(String(format: "%.1f", storageUsage.usagePercentage))%",
                severity: .high
            ))
        }
        
        // 检查网络使用
        let recentNetworkUsage = systemStats.networkUsages.suffix(5)
        let avgBytesPerSecond = recentNetworkUsage.isEmpty ? 0 : 
            recentNetworkUsage.map { $0.bytesReceived + $0.bytesSent }.reduce(0, +) / Int64(recentNetworkUsage.count)
        
        if avgBytesPerSecond > 10 * 1024 * 1024 { // 10MB/s
            warnings.append(PerformanceWarning(
                type: .highNetworkUsage,
                message: "网络使用量过高: \(ByteCountFormatter.string(fromByteCount: avgBytesPerSecond, countStyle: .file))/s",
                severity: .medium
            ))
        }
        
        return warnings
    }
    
    /// 生成详细的性能报告
    func generateDetailedPerformanceReport() -> DetailedPerformanceReport {
        let basicReport = generatePerformanceReport()
        let resourceStats = getResourceStatistics()
        let warnings = getPerformanceWarnings()
        let optimizationSuggestions = generateOptimizationSuggestions()
        
        return DetailedPerformanceReport(
            basicReport: basicReport,
            resourceStatistics: resourceStats,
            warnings: warnings,
            optimizationSuggestions: optimizationSuggestions,
            systemInfo: getSystemInfo(),
            generatedAt: Date()
        )
    }
    
    /// 生成性能优化建议
    private func generateOptimizationSuggestions() -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        // 检查响应时间优化建议
        let slowRequests = requestStats.filter { $0.value.averageResponseTime > 3000 }
        if !slowRequests.isEmpty {
            suggestions.append(OptimizationSuggestion(
                category: .performance,
                title: "优化慢速请求",
                description: "以下请求类型响应时间较长：\(slowRequests.keys.joined(separator: ", "))",
                priority: .high,
                actions: [
                    "考虑增加缓存策略",
                    "优化网络请求参数",
                    "实施请求预加载"
                ]
            ))
        }
        
        // 检查缓存优化建议
        if cacheStats.hitRate < 0.5 {
            suggestions.append(OptimizationSuggestion(
                category: .cache,
                title: "提高缓存命中率",
                description: "当前缓存命中率为 \(String(format: "%.1f", cacheStats.hitRate * 100))%，建议优化缓存策略",
                priority: .medium,
                actions: [
                    "增加缓存容量",
                    "优化缓存键生成策略",
                    "实施智能预缓存"
                ]
            ))
        }
        
        // 检查内存优化建议
        if systemStats.memoryUsage > 150 {
            suggestions.append(OptimizationSuggestion(
                category: .memory,
                title: "优化内存使用",
                description: "当前内存使用为 \(String(format: "%.1f", systemStats.memoryUsage))MB，建议优化内存管理",
                priority: .high,
                actions: [
                    "清理不必要的图像缓存",
                    "优化图像压缩策略",
                    "实施内存池管理"
                ]
            ))
        }
        
        // 检查网络优化建议
        let recentNetworkUsage = systemStats.networkUsages.suffix(10)
        let avgNetworkUsage = recentNetworkUsage.isEmpty ? 0 : 
            recentNetworkUsage.map { $0.bytesReceived + $0.bytesSent }.reduce(0, +) / Int64(recentNetworkUsage.count)
        
        if avgNetworkUsage > 5 * 1024 * 1024 { // 5MB
            suggestions.append(OptimizationSuggestion(
                category: .network,
                title: "优化网络使用",
                description: "平均网络使用量较高：\(ByteCountFormatter.string(fromByteCount: avgNetworkUsage, countStyle: .file))",
                priority: .medium,
                actions: [
                    "启用请求压缩",
                    "优化图像传输质量",
                    "实施增量数据同步"
                ]
            ))
        }
        
        // 检查电池优化建议
        if let batteryLevel = systemStats.batteryUsages.last?.level, batteryLevel < 0.3 {
            suggestions.append(OptimizationSuggestion(
                category: .battery,
                title: "优化电池使用",
                description: "当前电池电量较低：\(String(format: "%.0f", batteryLevel * 100))%",
                priority: .high,
                actions: [
                    "减少后台处理",
                    "降低图像处理质量",
                    "启用省电模式"
                ]
            ))
        }
        
        return suggestions
    }
    
    /// 实时性能监控
    func startRealTimeMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.performRealTimeCheck()
            }
        }
    }
    
    private func performRealTimeCheck() {
        // 更新系统统计
        updateSystemStats()
        
        // 记录资源使用
        recordResourceUsage(type: .memory, amount: systemStats.memoryUsage, unit: "MB")
        recordResourceUsage(type: .cpu, amount: systemStats.cpuUsage, unit: "%")
        
        // 记录电池使用
        recordBatteryUsage()
        
        // 记录存储使用
        recordStorageUsage()
        
        // 检查性能警告
        let warnings = getPerformanceWarnings()
        if !warnings.isEmpty {
            for warning in warnings.filter({ $0.severity == .high || $0.severity == .critical }) {
                logger.warning("性能警告: \(warning.message)")
            }
        }
    }
    
    /// 获取实时性能指标
    func getRealTimeMetrics() -> RealTimeMetrics {
        let currentTime = Date()
        
        // 计算最近1分钟的请求统计
        let recentRequests = requestStats.values.filter { 
            currentTime.timeIntervalSince($0.lastRequest) < 60 
        }
        
        let recentRequestCount = recentRequests.reduce(0) { $0 + $1.totalRequests }
        let recentSuccessRate = recentRequests.isEmpty ? 1.0 : 
            recentRequests.map { $0.successRate }.reduce(0, +) / Double(recentRequests.count)
        
        // 计算最近的网络使用
        let recentNetworkUsage = systemStats.networkUsages.suffix(12) // 最近1分钟（5秒间隔）
        let recentBytesReceived = recentNetworkUsage.map { $0.bytesReceived }.reduce(0, +)
        let recentBytesSent = recentNetworkUsage.map { $0.bytesSent }.reduce(0, +)
        
        return RealTimeMetrics(
            memoryUsage: systemStats.memoryUsage,
            cpuUsage: systemStats.cpuUsage,
            networkReceived: recentBytesReceived,
            networkSent: recentBytesSent,
            requestsPerMinute: recentRequestCount,
            successRate: recentSuccessRate,
            cacheHitRate: cacheStats.hitRate,
            batteryLevel: systemStats.batteryUsages.last?.level ?? -1,
            timestamp: currentTime
        )
    }
    
    /// 性能趋势分析
    func getPerformanceTrends(timeRange: TimeInterval = 3600) -> PerformanceTrends {
        let cutoffTime = Date().addingTimeInterval(-timeRange)
        
        // 分析内存使用趋势
        let memoryUsages = systemStats.resourceUsages
            .filter { $0.type == .memory && $0.timestamp > cutoffTime }
            .map { $0.amount }
        
        let memoryTrend = calculateTrend(values: memoryUsages)
        
        // 分析网络使用趋势
        let networkUsages = systemStats.networkUsages
            .filter { $0.timestamp > cutoffTime }
            .map { Double($0.bytesReceived + $0.bytesSent) }
        
        let networkTrend = calculateTrend(values: networkUsages)
        
        // 分析响应时间趋势
        let responseTimes = requestStats.values.map { $0.averageResponseTime }
        let responseTimeTrend = calculateTrend(values: responseTimes)
        
        return PerformanceTrends(
            memoryTrend: memoryTrend,
            networkTrend: networkTrend,
            responseTimeTrend: responseTimeTrend,
            timeRange: timeRange,
            generatedAt: Date()
        )
    }
    
    private func calculateTrend(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let changePercentage = (secondAvg - firstAvg) / firstAvg * 100
        
        if changePercentage > 10 {
            return .increasing
        } else if changePercentage < -10 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func getSystemInfo() -> SystemInfo {
        let device = UIDevice.current
        
        return SystemInfo(
            deviceModel: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        )
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
    
    // 新增的资源使用跟踪
    var resourceUsages: [ResourceUsage] = []
    var networkUsages: [NetworkUsage] = []
    var batteryUsages: [BatteryUsage] = []
    var storageUsages: [StorageUsage] = []
    var totalBytesReceived: Int64 = 0
    var totalBytesSent: Int64 = 0
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

// MARK: - 新增的数据结构

enum ResourceType: String, Codable {
    case memory = "memory"
    case cpu = "cpu"
    case network = "network"
    case battery = "battery"
    case storage = "storage"
}

struct ResourceUsage: Codable {
    let type: ResourceType
    let amount: Double
    let unit: String
    let timestamp: Date
}

struct NetworkUsage: Codable {
    let bytesReceived: Int64
    let bytesSent: Int64
    let timestamp: Date
}

struct BatteryUsage: Codable {
    let level: Float // 0.0 - 1.0
    let state: UIDevice.BatteryState
    let timestamp: Date
}

extension UIDevice.BatteryState: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = UIDevice.BatteryState(rawValue: rawValue) ?? .unknown
    }
}

struct StorageUsage: Codable {
    let totalSpace: Int64
    let usedSpace: Int64
    let availableSpace: Int64
    let usagePercentage: Double
    let timestamp: Date
}

struct ResourceStatistics {
    let averageMemoryUsage: Double
    let averageCPUUsage: Double
    let totalBytesReceived: Int64
    let totalBytesSent: Int64
    let recentBytesReceived: Int64
    let recentBytesSent: Int64
    let currentBatteryLevel: Float
    let storageUsagePercentage: Double
}

struct SystemInfo {
    let deviceModel: String
    let systemName: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
}

struct DetailedPerformanceReport {
    let basicReport: PerformanceReport
    let resourceStatistics: ResourceStatistics
    let warnings: [PerformanceWarning]
    let optimizationSuggestions: [OptimizationSuggestion]
    let systemInfo: SystemInfo
    let generatedAt: Date
}

struct OptimizationSuggestion: Identifiable {
    let id = UUID()
    let category: OptimizationCategory
    let title: String
    let description: String
    let priority: Priority
    let actions: [String]
    
    enum OptimizationCategory {
        case performance, cache, memory, network, battery, storage
        
        var displayName: String {
            switch self {
            case .performance: return "性能"
            case .cache: return "缓存"
            case .memory: return "内存"
            case .network: return "网络"
            case .battery: return "电池"
            case .storage: return "存储"
            }
        }
        
        var icon: String {
            switch self {
            case .performance: return "speedometer"
            case .cache: return "externaldrive"
            case .memory: return "memorychip"
            case .network: return "network"
            case .battery: return "battery.100"
            case .storage: return "internaldrive"
            }
        }
    }
    
    enum Priority {
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

struct RealTimeMetrics {
    let memoryUsage: Double // MB
    let cpuUsage: Double // %
    let networkReceived: Int64 // bytes
    let networkSent: Int64 // bytes
    let requestsPerMinute: Int
    let successRate: Double
    let cacheHitRate: Double
    let batteryLevel: Float // 0.0 - 1.0
    let timestamp: Date
    
    var formattedMemoryUsage: String {
        return String(format: "%.1f MB", memoryUsage)
    }
    
    var formattedCPUUsage: String {
        return String(format: "%.1f%%", cpuUsage)
    }
    
    var formattedNetworkUsage: String {
        let total = networkReceived + networkSent
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedCacheHitRate: String {
        return String(format: "%.1f%%", cacheHitRate * 100)
    }
    
    var formattedBatteryLevel: String {
        return batteryLevel >= 0 ? String(format: "%.0f%%", batteryLevel * 100) : "未知"
    }
}

struct PerformanceTrends {
    let memoryTrend: TrendDirection
    let networkTrend: TrendDirection
    let responseTimeTrend: TrendDirection
    let timeRange: TimeInterval
    let generatedAt: Date
}

enum TrendDirection {
    case increasing, decreasing, stable
    
    var displayName: String {
        switch self {
        case .increasing: return "上升"
        case .decreasing: return "下降"
        case .stable: return "稳定"
        }
    }
    
    var color: String {
        switch self {
        case .increasing: return "red"
        case .decreasing: return "green"
        case .stable: return "blue"
        }
    }
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
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
        case lowBattery
        case lowStorage
        case highNetworkUsage
        case highCPUUsage
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