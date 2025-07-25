import Foundation
import Combine

/// LLM配置管理器单例类
/// 负责管理LLM API配置的读取、保存、验证和同步
final class LLMConfigurationManager: ObservableObject {
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = LLMConfigurationManager()
    
    /// 私有初始化
    private init() {
        // 首先迁移旧配置
        migrateOldConfiguration()
        
        // 然后加载配置
        loadConfiguration()
        
        // 只有在没有任何配置时才设置环境变量
        if !hasSavedConfiguration {
            setupEnvironmentVariables()
        }
    }
    
    /// 从 APIConfigurationManager 同步配置
    private func syncFromAPIConfiguration() {
        let apiConfig = APIConfigurationManager.shared.currentConfig
        
        // 如果 LLM 配置为空但 API 配置有效，则同步配置
        let defaults = UserDefaults.standard
        let llmApiKey = defaults.string(forKey: UserDefaultsKeys.llmApiKey) ?? ""
        
        if llmApiKey.isEmpty && !apiConfig.apiKey.isEmpty {
            print("🔄 从 APIConfigurationManager 同步配置到 LLMConfigurationManager")
            
            // 同步配置到 LLM 键名
            defaults.set(apiConfig.baseURL, forKey: UserDefaultsKeys.llmApiBaseURL)
            defaults.set(apiConfig.apiKey, forKey: UserDefaultsKeys.llmApiKey)
            defaults.set(apiConfig.model, forKey: UserDefaultsKeys.llmApiModel)
            defaults.set(apiConfig.maxTokens, forKey: UserDefaultsKeys.llmApiMaxTokens)
            defaults.set(apiConfig.temperature, forKey: UserDefaultsKeys.llmApiTemperature)
            defaults.set(apiConfig.topP, forKey: UserDefaultsKeys.llmApiTopP)
            
            // 强制同步
            defaults.synchronize()
            
            print("✅ 配置同步完成")
        }
    }
    
    // MARK: - 发布属性
    
    /// 当前LLM配置
    @Published var currentConfig: LLMAPIService.LLMServiceConfig = .default
    
    /// 配置是否有效
    @Published private(set) var isConfigValid: Bool = false
    
    /// 是否存在已保存的配置
    var hasSavedConfiguration: Bool {
        let defaults = UserDefaults.standard
        // 使用 nil-coalescing 操作符，避免强制解包
        let llmApiKey = defaults.string(forKey: UserDefaultsKeys.llmApiKey) ?? ""
        let apiKey = defaults.string(forKey: UserDefaultsKeys.apiKey) ?? ""
        
        let hasLLMKey = !llmApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAPIKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return hasLLMKey || hasAPIKey
    }
    
    /// 配置变更通知
    var configurationChanged = PassthroughSubject<Void, Never>()
    
    /// LLM API服务实例
    private var llmService: LLMAPIService {
        return LLMAPIService.shared
    }
    
    // MARK: - 配置管理
    
    /// 加载配置
    func loadConfiguration() {
        let defaults = UserDefaults.standard
        
        // 添加原始值调试
        print("📖 从UserDefaults加载配置:")
        
        let providerTypeString = defaults.string(forKey: UserDefaultsKeys.llmProviderType) ?? LLMAPIService.LLMProviderType.openai.rawValue
        let providerType = LLMAPIService.LLMProviderType(rawValue: providerTypeString) ?? .openai
        let baseURL = defaults.string(forKey: UserDefaultsKeys.llmApiBaseURL) ?? LLMAPIService.LLMServiceConfig.defaultBaseURL(for: providerType)
        
        // 优先使用 LLM 专用键，如果为空则尝试 API 通用键
        var apiKey = defaults.string(forKey: UserDefaultsKeys.llmApiKey) ?? ""
        if apiKey.isEmpty {
            apiKey = defaults.string(forKey: UserDefaultsKeys.apiKey) ?? ""
            if !apiKey.isEmpty {
                print("🔄 从 API 配置同步 API Key 到 LLM 配置")
                // 同步到 LLM 键
                defaults.set(apiKey, forKey: UserDefaultsKeys.llmApiKey)
            }
        }
        
        let model = defaults.string(forKey: UserDefaultsKeys.llmApiModel) ?? LLMAPIService.LLMServiceConfig.defaultModel(for: providerType)
        
        // 修复 max_tokens 加载逻辑
        let maxTokensValue = defaults.object(forKey: UserDefaultsKeys.llmApiMaxTokens) as? Int
        let maxTokens = maxTokensValue ?? 4000  // 只有当键不存在时才使用默认值
        
        // 修复其他参数的加载逻辑
        let temperatureValue = defaults.object(forKey: UserDefaultsKeys.llmApiTemperature) as? Double
        let temperature = temperatureValue ?? 0.7
        
        let topPValue = defaults.object(forKey: UserDefaultsKeys.llmApiTopP) as? Double
        let topP = topPValue ?? 0.9
        
        let topKValue = defaults.object(forKey: UserDefaultsKeys.llmApiTopK) as? Int
        let topK = topKValue ?? 50
        
        let frequencyPenalty = defaults.double(forKey: UserDefaultsKeys.llmApiFrequencyPenalty)
    
        currentConfig = LLMAPIService.LLMServiceConfig(
            providerType: providerType,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            frequencyPenalty: frequencyPenalty
        )
        
        isConfigValid = validateConfiguration().isValid
        
        // 打印加载结果
        print("🔧 加载LLM API配置:")
        print("   - Provider Type: \(providerType.displayName)")
        print("   - Base URL: `\(baseURL)`")
        print("   - API Key: \(apiKey.isEmpty ? "空" : "已设置")")
        print("   - Model: \(model)")
        print("   - API Key有效: \(isValidAPIKey(apiKey))")
    }
    
    /// 保存配置
    /// 保存配置
    func saveConfiguration(_ config: LLMAPIService.LLMServiceConfig) {
        let defaults = UserDefaults.standard
        
        // 添加调试信息
        print("💾 正在保存配置:")
        print("   - Provider Type: \(config.providerType.rawValue)")
        print("   - Base URL: \(config.baseURL)")
        print("   - API Key: \(config.apiKey.isEmpty ? "空" : "已设置(\(config.apiKey.prefix(10))...)")") 
        print("   - Model: \(config.model)")
        
        // 保存到 LLM 专用键
        defaults.set(config.providerType.rawValue, forKey: UserDefaultsKeys.llmProviderType)
        defaults.set(config.baseURL, forKey: UserDefaultsKeys.llmApiBaseURL)
        defaults.set(config.apiKey, forKey: UserDefaultsKeys.llmApiKey)
        defaults.set(config.model, forKey: UserDefaultsKeys.llmApiModel)
        defaults.set(config.maxTokens, forKey: UserDefaultsKeys.llmApiMaxTokens)
        defaults.set(config.temperature, forKey: UserDefaultsKeys.llmApiTemperature)
        defaults.set(config.topP, forKey: UserDefaultsKeys.llmApiTopP)
        defaults.set(config.topK ?? 50, forKey: UserDefaultsKeys.llmApiTopK)
        defaults.set(config.frequencyPenalty ?? 0.0, forKey: UserDefaultsKeys.llmApiFrequencyPenalty)
        
        // 同时保存到 API 配置管理器的键（保持兼容性）
        defaults.set(config.baseURL, forKey: UserDefaultsKeys.apiBaseURL)
        defaults.set(config.apiKey, forKey: UserDefaultsKeys.apiKey)
        defaults.set(config.model, forKey: UserDefaultsKeys.apiModel)
        defaults.set(config.maxTokens, forKey: UserDefaultsKeys.apiMaxTokens)
        defaults.set(config.temperature, forKey: UserDefaultsKeys.apiTemperature)
        defaults.set(config.topP, forKey: UserDefaultsKeys.apiTopP)
        
        // 强制同步
        defaults.synchronize()
        
        // 验证保存结果
        let savedApiKey = defaults.string(forKey: UserDefaultsKeys.llmApiKey) ?? ""
        print("✅ 配置保存验证: API Key \(savedApiKey.isEmpty ? "仍为空" : "已保存")")
        
        // 更新当前配置
        currentConfig = config
        isConfigValid = validateConfiguration().isValid
        
        // 刷新配置状态
        refreshConfigurationStatus()
        
        // 发送配置变更通知
        configurationChanged.send()
    }
    
    /// 清除配置
    func clearConfiguration() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.llmProviderType)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiBaseURL)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiKey)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiModel)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiMaxTokens)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiTemperature)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiTopP)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiTopK)
        defaults.removeObject(forKey: UserDefaultsKeys.llmApiFrequencyPenalty)
        
        currentConfig = .default
        isConfigValid = false
        configurationChanged.send()
    }
    
    /// 更新单个配置项
    func updateConfiguration(
        providerType: LLMAPIService.LLMProviderType? = nil,
        baseURL: String? = nil,
        apiKey: String? = nil,
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil
    ) {
        let newConfig = LLMAPIService.LLMServiceConfig(
            providerType: providerType ?? currentConfig.providerType,
            baseURL: baseURL ?? currentConfig.baseURL,
            apiKey: apiKey ?? currentConfig.apiKey,
            model: model ?? currentConfig.model,
            maxTokens: maxTokens ?? currentConfig.maxTokens,
            temperature: temperature ?? currentConfig.temperature,
            topP: topP ?? currentConfig.topP,
            topK: topK ?? currentConfig.topK,
            frequencyPenalty: frequencyPenalty ?? currentConfig.frequencyPenalty
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
        }
        
        if let maxTokens = currentConfig.maxTokens, maxTokens <= 0 {
            errors.append(.invalidMaxTokens)
        }
        
        if let temperature = currentConfig.temperature, temperature < 0 || temperature > 2 {
            errors.append(.invalidTemperature)
        }
        
        if let topP = currentConfig.topP, topP < 0 || topP > 1 {
            errors.append(.invalidTopP)
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// 测试LLM API连接
    func testConnection() async -> ConnectionTestResult {
        do {
            let result = try await llmService.testConnection(config: currentConfig)
            return .success(result)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    // MARK: - 环境变量支持
    
    /// 从环境变量加载配置
    private func setupEnvironmentVariables() {
        guard ProcessInfo.processInfo.environment["USE_ENV_CONFIG"] != nil else {
            print("🔧 跳过环境变量配置")
            return
        }
        
        print("🔧 使用环境变量配置")
        let env = ProcessInfo.processInfo.environment
        
        let providerTypeString = env["LLM_PROVIDER_TYPE"] ?? currentConfig.providerType.rawValue
        let providerType = LLMAPIService.LLMProviderType(rawValue: providerTypeString) ?? currentConfig.providerType
        
        let config = LLMAPIService.LLMServiceConfig(
            providerType: providerType,
            baseURL: env["LLM_API_BASE_URL"] ?? currentConfig.baseURL,
            apiKey: env["LLM_API_KEY"] ?? currentConfig.apiKey,
            model: env["LLM_API_MODEL"] ?? currentConfig.model,
            maxTokens: Int(env["LLM_API_MAX_TOKENS"] ?? "") ?? currentConfig.maxTokens,
            temperature: Double(env["LLM_API_TEMPERATURE"] ?? "") ?? currentConfig.temperature,
            topP: Double(env["LLM_API_TOP_P"] ?? "") ?? currentConfig.topP,
            topK: Int(env["LLM_API_TOP_K"] ?? "") ?? currentConfig.topK,
            frequencyPenalty: Double(env["LLM_API_FREQUENCY_PENALTY"] ?? "") ?? currentConfig.frequencyPenalty
        )
        
        saveConfiguration(config)
    }
    
    // MARK: - 私有方法
    
    /// 迁移旧配置数据
    private func migrateOldConfiguration() {
        let defaults = UserDefaults.standard
        
        // 检查是否需要从 API 配置迁移到 LLM 配置
        let llmApiKey = defaults.string(forKey: UserDefaultsKeys.llmApiKey) ?? ""
        let apiKey = defaults.string(forKey: UserDefaultsKeys.apiKey) ?? ""
        
        if llmApiKey.isEmpty && !apiKey.isEmpty {
            print("🔄 迁移 API 配置到 LLM 配置")
            
            // 迁移配置
            defaults.set(apiKey, forKey: UserDefaultsKeys.llmApiKey)
            defaults.set(defaults.string(forKey: UserDefaultsKeys.apiBaseURL) ?? "", forKey: UserDefaultsKeys.llmApiBaseURL)
            defaults.set(defaults.string(forKey: UserDefaultsKeys.apiModel) ?? "", forKey: UserDefaultsKeys.llmApiModel)
            defaults.set(defaults.integer(forKey: UserDefaultsKeys.apiMaxTokens), forKey: UserDefaultsKeys.llmApiMaxTokens)
            defaults.set(defaults.double(forKey: UserDefaultsKeys.apiTemperature), forKey: UserDefaultsKeys.llmApiTemperature)
            defaults.set(defaults.double(forKey: UserDefaultsKeys.apiTopP), forKey: UserDefaultsKeys.llmApiTopP)
            
            defaults.synchronize()
            print("✅ 配置迁移完成")
        }
    }
    
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
    
    // 删除重复的 MARK: - 私有方法 部分
    // 删除重复的 isValidURL 方法（第377-380行）
    // 删除重复的 isValidAPIKey 方法（第383-386行）
    
    /// 调试UserDefaults中的实际值
    func debugUserDefaults() {
        let defaults = UserDefaults.standard
        print("🔍 UserDefaults 调试信息:")
        print("   - llmApiKey: \(defaults.string(forKey: UserDefaultsKeys.llmApiKey) ?? "nil")")
        print("   - llmApiBaseURL: \(defaults.string(forKey: UserDefaultsKeys.llmApiBaseURL) ?? "nil")")
        print("   - llmApiModel: \(defaults.string(forKey: UserDefaultsKeys.llmApiModel) ?? "nil")")
        print("   - 所有LLM相关键值:")
        for (key, value) in defaults.dictionaryRepresentation() {
            if key.contains("llm") {
                print("     \(key): \(value)")
            }
        }
    }
    
    /// 强制刷新配置状态
    func refreshConfigurationStatus() {
        isConfigValid = currentConfig.isValid()
        print("🔄 强制刷新配置状态: \(isConfigValid)")
        print("🔄 当前配置详情:")
        print("   - baseURL: \(currentConfig.baseURL)")
        print("   - apiKey: \(currentConfig.apiKey.isEmpty ? "空" : "已设置")")
        print("   - model: \(currentConfig.model)")
    }
    
    /// 重新加载并验证配置
    func reloadAndValidateConfiguration() {
        loadConfiguration()
        refreshConfigurationStatus()
        configurationChanged.send()
    }
}

// MARK: - LLMServiceConfig 扩展

extension LLMAPIService.LLMServiceConfig {
    /// 默认配置
    static let `default` = LLMAPIService.LLMServiceConfig(
        providerType: .openai,
        baseURL: "https://api.siliconflow.cn/v1",
        apiKey: "",
        model: "deepseek-ai/DeepSeek-V3"
    )
    
    /// 获取提供商的默认基础URL
    static func defaultBaseURL(for providerType: LLMAPIService.LLMProviderType) -> String {
        switch providerType {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com"
        }
    }
    
    /// 获取提供商的默认模型
    static func defaultModel(for providerType: LLMAPIService.LLMProviderType) -> String {
        switch providerType {
        case .openai:
            return "gpt-3.5-turbo"
        case .anthropic:
            return "claude-3-sonnet-20240229"
        }
    }
}

// 删除这个扩展，因为键名已移到 UserDefaultsKeys.swift
// MARK: - UserDefaults Keys 扩展
// extension UserDefaultsKeys {
//     static let llmProviderType = "llm_provider_type"
//     static let llmApiBaseURL = "llm_api_base_url"
//     static let llmApiKey = "llm_api_key"
//     static let llmApiModel = "llm_api_model"
//     static let llmApiMaxTokens = "llm_api_max_tokens"
//     static let llmApiTemperature = "llm_api_temperature"
//     static let llmApiTopP = "llm_api_top_p"
//     static let llmApiTopK = "llm_api_top_k"
//     static let llmApiFrequencyPenalty = "llm_api_frequency_penalty"
// }

// MARK: - 用户偏好设置封装

/// LLM用户偏好设置封装
struct LLMUserPreferences {
    /// 保存LLM API配置到UserDefaults
    static func saveLLMConfig(_ config: LLMAPIService.LLMServiceConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: "llm_service_config")
        }
    }
    
    /// 从UserDefaults读取LLM API配置
    static func loadLLMConfig() -> LLMAPIService.LLMServiceConfig {
        if let data = UserDefaults.standard.data(forKey: "llm_service_config"),
           let config = try? JSONDecoder().decode(LLMAPIService.LLMServiceConfig.self, from: data) {
            return config
        }
        return LLMAPIService.LLMServiceConfig.default
    }
    
    /// 清除保存的LLM API配置
    static func clearLLMConfig() {
        UserDefaults.standard.removeObject(forKey: "llm_service_config")
    }
    
    /// 检查是否存在已保存的配置
    static func hasSavedLLMConfig() -> Bool {
        return UserDefaults.standard.object(forKey: "llm_service_config") != nil
    }

    /// 检查是否已保存有效配置
    static func hasValidLLMConfig() -> Bool {
        return loadLLMConfig().isValid()
    }
}