import Foundation
import Combine

/// API配置管理器单例类
/// 负责管理API配置的读取、保存、验证和同步
final class APIConfigurationManager: ObservableObject {
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = APIConfigurationManager()
    
    /// 私有初始化
    private init() {
        loadConfiguration()
        setupEnvironmentVariables()
    }
    
    // MARK: - 发布属性
    
    /// 当前API配置
    @Published var currentConfig: APIServiceConfig = .default
    
    /// 配置是否有效
    @Published private(set) var isConfigValid: Bool = false
    
    /// 是否存在已保存的配置
    var hasSavedConfiguration: Bool {
        return UserDefaults.standard.string(forKey: UserDefaultsKeys.apiKey) != nil
    }
    
    /// 配置变更通知
    var configurationChanged = PassthroughSubject<Void, Never>()
    
    /// API服务实例
    private let apiService = SiliconFlowAPIService.shared
    
    // MARK: - 配置管理
    
    /// 加载配置
    func loadConfiguration() {
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: UserDefaultsKeys.apiBaseURL) ?? APIServiceConfig.default.baseURL
        let apiKey = defaults.string(forKey: UserDefaultsKeys.apiKey) ?? ""
        let model = defaults.string(forKey: UserDefaultsKeys.apiModel) ?? APIServiceConfig.default.model
        
        // 添加调试输出
        print("🔧 加载API配置:")
        print("   - Base URL: \(baseURL)")
        print("   - API Key: \(apiKey.isEmpty ? "空" : "\(apiKey.prefix(10))...")")
        print("   - Model: \(model)")
        print("   - API Key有效: \(isValidAPIKey(apiKey))")
        
        let maxTokens = defaults.integer(forKey: UserDefaultsKeys.apiMaxTokens) == 0 ? APIServiceConfig.default.maxTokens : defaults.integer(forKey: UserDefaultsKeys.apiMaxTokens)
        let temperature = defaults.double(forKey: UserDefaultsKeys.apiTemperature)
        let topP = defaults.double(forKey: UserDefaultsKeys.apiTopP)

        currentConfig = APIServiceConfig(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        )
        isConfigValid = currentConfig.isValid()
    }
    
    /// 保存配置
    func saveConfiguration(_ config: APIServiceConfig) {
        let defaults = UserDefaults.standard
        defaults.set(config.baseURL, forKey: UserDefaultsKeys.apiBaseURL)
        defaults.set(config.apiKey, forKey: UserDefaultsKeys.apiKey)
        defaults.set(config.model, forKey: UserDefaultsKeys.apiModel)
        defaults.set(config.maxTokens, forKey: UserDefaultsKeys.apiMaxTokens)
        defaults.set(config.temperature, forKey: UserDefaultsKeys.apiTemperature)
        defaults.set(config.topP, forKey: UserDefaultsKeys.apiTopP)
        
        currentConfig = config
        isConfigValid = config.isValid()
        configurationChanged.send()
    }
    
    /// 清除配置
    func clearConfiguration() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.apiBaseURL)
        defaults.removeObject(forKey: UserDefaultsKeys.apiKey)
        defaults.removeObject(forKey: UserDefaultsKeys.apiModel)
        defaults.removeObject(forKey: UserDefaultsKeys.apiMaxTokens)
        defaults.removeObject(forKey: UserDefaultsKeys.apiTemperature)
        defaults.removeObject(forKey: UserDefaultsKeys.apiTopP)
        
        currentConfig = .default
        isConfigValid = false
        configurationChanged.send()
    }
    
    /// 更新单个配置项
    func updateConfiguration(
        baseURL: String? = nil,
        apiKey: String? = nil,
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil
    ) {
        let newConfig = APIServiceConfig(
            baseURL: baseURL ?? currentConfig.baseURL,
            apiKey: apiKey ?? currentConfig.apiKey,
            model: model ?? currentConfig.model,
            maxTokens: maxTokens ?? currentConfig.maxTokens,
            temperature: temperature ?? currentConfig.temperature,
            topP: topP ?? currentConfig.topP
        )
        saveConfiguration(newConfig)
    }
    
    // MARK: - 配置验证
    
    /// 验证配置的有效性
    func validateConfiguration() -> ValidationResult {
        var errors: [ValidationError] = []
        
        if currentConfig.baseURL.isEmpty {
            errors.append(.emptyBaseURL)
        } else if !isValidURL(currentConfig.baseURL) {
            errors.append(.invalidBaseURL)
        }
        
        if currentConfig.apiKey.isEmpty {
            errors.append(.emptyAPIKey)
        } else if !isValidAPIKey(currentConfig.apiKey) {
            errors.append(.invalidAPIKey)
        }
        
        if currentConfig.model.isEmpty {
            errors.append(.emptyModel)
        } else if !SupportedModels.availableModels.contains(currentConfig.model) {
            errors.append(.invalidModel)
        }
        
        if currentConfig.maxTokens <= 0 {
            errors.append(.invalidMaxTokens)
        }
        
        if currentConfig.temperature < 0 || currentConfig.temperature > 2 {
            errors.append(.invalidTemperature)
        }
        
        if currentConfig.topP < 0 || currentConfig.topP > 1 {
            errors.append(.invalidTopP)
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// 测试API连接
    /// 测试连接
    func testConnection() async -> ConnectionTestResult {
        do {
            let result = try await apiService.testConnection(config: currentConfig)
            return .success(result)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    // MARK: - 环境变量支持
    
    /// 从环境变量加载配置
    private func setupEnvironmentVariables() {
        guard ProcessInfo.processInfo.environment["USE_ENV_CONFIG"] != nil else {
            return
        }
        
        let env = ProcessInfo.processInfo.environment
        
        let config = APIServiceConfig(
            baseURL: env["API_BASE_URL"] ?? currentConfig.baseURL,
            apiKey: env["API_KEY"] ?? currentConfig.apiKey,
            model: env["API_MODEL"] ?? currentConfig.model,
            maxTokens: Int(env["API_MAX_TOKENS"] ?? "") ?? currentConfig.maxTokens,
            temperature: Double(env["API_TEMPERATURE"] ?? "") ?? currentConfig.temperature,
            topP: Double(env["API_TOP_P"] ?? "") ?? currentConfig.topP
        )
        
        saveConfiguration(config)
    }
    
    // MARK: - 私有方法
    
    /// 验证URL格式
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// 验证API密钥格式
    private func isValidAPIKey(_ key: String) -> Bool {
        // 只检查长度，移除不必要的前缀校验
        return key.count >= 10 && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 验证结果模型

/// 验证结果
struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
}

/// 验证错误类型
enum ValidationError: LocalizedError {
    case emptyBaseURL
    case invalidBaseURL
    case emptyAPIKey
    case invalidAPIKey
    case emptyModel
    case invalidModel
    case invalidMaxTokens
    case invalidTemperature
    case invalidTopP
    
    var errorDescription: String? {
        switch self {
        case .emptyBaseURL:
            return "基础URL不能为空"
        case .invalidBaseURL:
            return "基础URL格式无效"
        case .emptyAPIKey:
            return "API密钥不能为空"
        case .invalidAPIKey:
            return "API密钥格式无效（长度至少10个字符）"
        case .emptyModel:
            return "模型名称不能为空"
        case .invalidModel:
            return "模型名称无效"
        case .invalidMaxTokens:
            return "最大token数必须大于0"
        case .invalidTemperature:
            return "温度参数必须在0.0-2.0之间"
        case .invalidTopP:
            return "top_p参数必须在0.0-1.0之间"
        }
    }
}

/// 连接测试结果
enum ConnectionTestResult {
    case success(String)
    case failure(String)
    
    var message: String {
        switch self {
        case .success(let msg):
            return msg
        case .failure(let msg):
            return msg
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}