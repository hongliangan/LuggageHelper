import Foundation
import SwiftUI
import Network

// MARK: - 统一错误处理服务
@MainActor
class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    @Published var errorHistory: [ErrorRecord] = []
    
    private let maxErrorHistory = 50
    
    private init() {}
    
    // MARK: - 错误处理方法
    
    /// 处理并显示错误
    func handleError(_ error: Error, context: String = "", showToUser: Bool = true) {
        let appError = convertToAppError(error, context: context)
        
        // 记录错误历史
        recordError(appError, context: context)
        
        // 显示给用户
        if showToUser {
            showError(appError)
        }
        
        // 记录日志
        logError(appError, context: context)
    }
    
    /// 显示错误给用户
    func showError(_ error: AppError) {
        currentError = error
        isShowingError = true
    }
    
    /// 清除当前错误
    func clearError() {
        currentError = nil
        isShowingError = false
    }
    
    /// 重试操作
    func retryOperation(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                clearError()
            } catch {
                handleError(error, context: "重试操作")
            }
        }
    }
    
    // MARK: - 错误转换
    
    private func convertToAppError(_ error: Error, context: String) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let apiError = error as? LLMAPIService.APIError {
            return convertAPIError(apiError)
        }
        
        if let urlError = error as? URLError {
            return convertURLError(urlError)
        }
        
        // 默认错误
        return AppError(
            type: .unknown,
            title: "未知错误",
            message: error.localizedDescription,
            context: context,
            originalError: error,
            canRetry: false,
            suggestedActions: ["请重启应用或联系技术支持"]
        )
    }
    
    private func convertAPIError(_ error: LLMAPIService.APIError) -> AppError {
        switch error {
        case .networkError(let underlyingError):
            return AppError(
                type: .network,
                title: "网络连接错误",
                message: "无法连接到AI服务，请检查网络连接",
                originalError: underlyingError,
                canRetry: true,
                suggestedActions: [
                    "检查网络连接",
                    "稍后重试",
                    "切换到其他网络"
                ]
            )
            
        case .configurationError(let message):
            return AppError(
                type: .configuration,
                title: "配置错误",
                message: message,
                originalError: error,
                canRetry: false,
                suggestedActions: [
                    "检查API配置",
                    "重新设置API密钥",
                    "联系技术支持"
                ]
            )
            
        case .rateLimitExceeded:
            return AppError(
                type: .rateLimited,
                title: "请求频率过高",
                message: "AI服务请求过于频繁，请稍后再试",
                originalError: error,
                canRetry: true,
                retryDelay: 60,
                suggestedActions: [
                    "等待1分钟后重试",
                    "减少请求频率"
                ]
            )
            
        case .authenticationFailed:
            return AppError(
                type: .authentication,
                title: "认证失败",
                message: "API密钥无效或已过期",
                originalError: error,
                canRetry: false,
                suggestedActions: [
                    "检查API密钥是否正确",
                    "重新设置API配置",
                    "联系服务提供商"
                ]
            )
            
        case .serverError(let statusCode, let message):
            return AppError(
                type: .server,
                title: "服务器错误",
                message: message ?? "服务器暂时不可用（错误代码：\(statusCode)）",
                originalError: error,
                canRetry: statusCode >= 500,
                suggestedActions: [
                    statusCode >= 500 ? "稍后重试" : "检查请求参数",
                    "联系技术支持"
                ]
            )
            
        case .invalidResponse:
            return AppError(
                type: .parsing,
                title: "数据解析错误",
                message: "AI服务返回的数据格式异常",
                originalError: error,
                canRetry: true,
                suggestedActions: [
                    "重试操作",
                    "如果问题持续，请联系技术支持"
                ]
            )
            
        default:
            return AppError(
                type: .ai,
                title: "AI服务错误",
                message: error.localizedDescription,
                originalError: error,
                canRetry: true,
                suggestedActions: ["重试操作", "检查网络连接"]
            )
        }
    }
    
    private func convertURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet:
            return AppError(
                type: .network,
                title: "网络连接失败",
                message: "设备未连接到互联网",
                originalError: error,
                canRetry: true,
                suggestedActions: [
                    "检查WiFi或移动网络连接",
                    "重新连接网络后重试"
                ]
            )
            
        case .timedOut:
            return AppError(
                type: .network,
                title: "请求超时",
                message: "网络请求超时，请检查网络连接",
                originalError: error,
                canRetry: true,
                suggestedActions: [
                    "检查网络连接速度",
                    "稍后重试",
                    "切换到更稳定的网络"
                ]
            )
            
        case .cannotFindHost:
            return AppError(
                type: .network,
                title: "无法连接服务器",
                message: "无法找到服务器地址",
                originalError: error,
                canRetry: true,
                suggestedActions: [
                    "检查网络连接",
                    "检查服务器地址配置",
                    "稍后重试"
                ]
            )
            
        default:
            return AppError(
                type: .network,
                title: "网络错误",
                message: error.localizedDescription,
                originalError: error,
                canRetry: true,
                suggestedActions: ["检查网络连接", "稍后重试"]
            )
        }
    }
    
    // MARK: - 错误记录
    
    private func recordError(_ error: AppError, context: String) {
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date(),
            deviceInfo: getDeviceInfo()
        )
        
        errorHistory.insert(record, at: 0)
        
        // 限制历史记录数量
        if errorHistory.count > maxErrorHistory {
            errorHistory = Array(errorHistory.prefix(maxErrorHistory))
        }
    }
    
    private func logError(_ error: AppError, context: String) {
        print("🚨 [ErrorHandling] \(error.type.rawValue.uppercased()): \(error.title)")
        print("   Context: \(context)")
        print("   Message: \(error.message)")
        if let originalError = error.originalError {
            print("   Original: \(originalError)")
        }
        print("   Timestamp: \(Date())")
    }
    
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            model: UIDevice.current.model,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
    }
    
    // MARK: - 错误统计
    
    func getErrorStatistics() -> ErrorStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-24 * 60 * 60)
        let lastWeek = now.addingTimeInterval(-7 * 24 * 60 * 60)
        
        let recent24h = errorHistory.filter { $0.timestamp >= last24Hours }
        let recentWeek = errorHistory.filter { $0.timestamp >= lastWeek }
        
        var typeDistribution: [ErrorType: Int] = [:]
        for record in recentWeek {
            typeDistribution[record.error.type, default: 0] += 1
        }
        
        return ErrorStatistics(
            totalErrors: errorHistory.count,
            errorsLast24h: recent24h.count,
            errorsLastWeek: recentWeek.count,
            typeDistribution: typeDistribution,
            mostCommonError: typeDistribution.max(by: { $0.value < $1.value })?.key
        )
    }
    
    // MARK: - 错误导出
    
    func exportErrorHistory() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(errorHistory)
            return String(data: data, encoding: .utf8) ?? "导出失败"
        } catch {
            return "导出错误：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 清理方法
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    func clearOldErrors(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        errorHistory.removeAll { $0.timestamp < cutoffDate }
    }
}

// MARK: - 数据模型

/// 应用错误类型
struct AppError: Error, Identifiable {
    let id = UUID()
    let type: ErrorType
    let title: String
    let message: String
    let context: String
    let timestamp: Date
    let canRetry: Bool
    let retryDelay: TimeInterval?
    let suggestedActions: [String]
    
    // 不参与编码的属性
    let originalError: Error?
    
    enum CodingKeys: String, CodingKey {
        case type, title, message, context, timestamp, canRetry, retryDelay, suggestedActions
    }
    
    init(type: ErrorType, title: String, message: String, context: String = "", 
         originalError: Error? = nil, canRetry: Bool = false, retryDelay: TimeInterval? = nil,
         suggestedActions: [String] = []) {
        self.type = type
        self.title = title
        self.message = message
        self.context = context
        self.timestamp = Date()
        self.originalError = originalError
        self.canRetry = canRetry
        self.retryDelay = retryDelay
        self.suggestedActions = suggestedActions
    }
}

// MARK: - AppError Codable 实现
extension AppError: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ErrorType.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.message = try container.decode(String.self, forKey: .message)
        self.context = try container.decode(String.self, forKey: .context)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.canRetry = try container.decode(Bool.self, forKey: .canRetry)
        self.retryDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .retryDelay)
        self.suggestedActions = try container.decode([String].self, forKey: .suggestedActions)
        self.originalError = nil // 不从编码中恢复
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(context, forKey: .context)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(canRetry, forKey: .canRetry)
        try container.encodeIfPresent(retryDelay, forKey: .retryDelay)
        try container.encode(suggestedActions, forKey: .suggestedActions)
        // originalError 不参与编码
    }
}

enum ErrorType: String, Codable, CaseIterable {
        case network = "network"
        case ai = "ai"
        case configuration = "configuration"
        case authentication = "authentication"
        case rateLimited = "rateLimited"
        case server = "server"
        case parsing = "parsing"
        case storage = "storage"
        case permission = "permission"
        case validation = "validation"
        case unknown = "unknown"
        
        var displayName: String {
            switch self {
            case .network: return "网络错误"
            case .ai: return "AI服务错误"
            case .configuration: return "配置错误"
            case .authentication: return "认证错误"
            case .rateLimited: return "请求限制"
            case .server: return "服务器错误"
            case .parsing: return "数据解析错误"
            case .storage: return "存储错误"
            case .permission: return "权限错误"
            case .validation: return "数据验证错误"
            case .unknown: return "未知错误"
            }
        }
        
        var icon: String {
            switch self {
            case .network: return "wifi.exclamationmark"
            case .ai: return "brain.head.profile"
            case .configuration: return "gearshape.fill"
            case .authentication: return "key.fill"
            case .rateLimited: return "clock.fill"
            case .server: return "server.rack"
            case .parsing: return "doc.text.fill"
            case .storage: return "internaldrive.fill"
            case .permission: return "lock.fill"
            case .validation: return "checkmark.seal.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .network: return .orange
            case .ai: return .blue
            case .configuration: return .purple
            case .authentication: return .red
            case .rateLimited: return .yellow
            case .server: return .red
            case .parsing: return .orange
            case .storage: return .brown
            case .permission: return .red
            case .validation: return .orange
            case .unknown: return .gray
            }
        }
    }

/// 错误记录
struct ErrorRecord: Identifiable, Codable {
    let id = UUID()
    let error: AppError
    let context: String
    let timestamp: Date
    let deviceInfo: DeviceInfo
    
    enum CodingKeys: String, CodingKey {
        case error, context, timestamp, deviceInfo
    }
}

/// 设备信息
struct DeviceInfo: Codable {
    let systemName: String
    let systemVersion: String
    let model: String
    let appVersion: String
}

/// 错误统计
struct ErrorStatistics {
    let totalErrors: Int
    let errorsLast24h: Int
    let errorsLastWeek: Int
    let typeDistribution: [ErrorType: Int]
    let mostCommonError: ErrorType?
}