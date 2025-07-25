import Foundation

/// 硅基流动API配置模型
/// 用于存储和管理API连接的所有配置参数
struct APIServiceConfig: Codable, Equatable {
    /// API基础URL，默认为硅基流动官方API地址
    var baseURL: String
    var apiKey: String
    var model: String
    var maxTokens: Int
    var temperature: Double
    var topP: Double
    
    /// 初始化方法
    init(baseURL: String = "https://api.siliconflow.cn/v1",
         apiKey: String = "",
         model: String = "deepseek-ai/DeepSeek-V3",
         maxTokens: Int = 2048, // 从512改为2048
         temperature: Double = 0.7,
         topP: Double = 0.9) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }
    
    /// 默认配置
    static let `default` = APIServiceConfig()
    
    /// 检查配置是否有效
    func isValid() -> Bool {
        return !baseURL.isEmpty && 
               !apiKey.isEmpty && 
               !model.isEmpty &&
               isValidAPIKey(apiKey)
    }
    
    /// 验证API密钥格式
    private func isValidAPIKey(_ key: String) -> Bool {
        // 移除过于严格的前缀要求，只检查基本长度
        return key.count >= 10 && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 验证配置（返回详细验证结果）
    func validate() -> ValidationResult {
        return APIConfigurationManager.shared.validateConfiguration()
    }
}

/// 支持的模型列表常量
struct SupportedModels {
    /// 硅基流动支持的主要模型列表
    static let availableModels = [
        "deepseek-ai/DeepSeek-V2.5",
        "deepseek-ai/DeepSeek-V2-Chat",
        "deepseek-ai/DeepSeek-Coder-V2-Instruct",
        "Qwen/Qwen2.5-72B-Instruct",
        "Qwen/Qwen2.5-7B-Instruct",
        "THUDM/glm-4-9b-chat",
        "01-ai/Yi-1.5-34B-Chat-16K",
        "meta-llama/Llama-3.2-3B-Instruct"
    ]
    
    /// 获取模型显示名称
    static func displayName(for model: String) -> String {
        let nameMap = [
            "deepseek-ai/DeepSeek-V2.5": "DeepSeek V2.5",
            "deepseek-ai/DeepSeek-V2-Chat": "DeepSeek V2 Chat",
            "deepseek-ai/DeepSeek-Coder-V2-Instruct": "DeepSeek Coder V2",
            "Qwen/Qwen2.5-72B-Instruct": "Qwen 2.5 72B",
            "Qwen/Qwen2.5-7B-Instruct": "Qwen 2.5 7B",
            "THUDM/glm-4-9b-chat": "GLM-4 9B",
            "01-ai/Yi-1.5-34B-Chat-16K": "Yi 1.5 34B",
            "meta-llama/Llama-3.2-3B-Instruct": "Llama 3.2 3B"
        ]
        return nameMap[model] ?? model
    }
}

/// 用户偏好设置封装
struct APIUserPreferences {
    /// 保存API配置到UserDefaults
    static func saveAPIConfig(_ config: APIServiceConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: "api_service_config")
        }
    }
    
    /// 从UserDefaults读取API配置
    static func loadAPIConfig() -> APIServiceConfig {
        if let data = UserDefaults.standard.data(forKey: "api_service_config"),
           let config = try? JSONDecoder().decode(APIServiceConfig.self, from: data) {
            return config
        }
        return APIServiceConfig.default
    }
    
    /// 清除保存的API配置
    static func clearAPIConfig() {
        UserDefaults.standard.removeObject(forKey: "api_service_config")
    }
    
    /// 检查是否存在已保存的配置
    static func hasSavedAPIConfig() -> Bool {
        return UserDefaults.standard.object(forKey: "api_service_config") != nil
    }

    /// 检查是否已保存有效配置
    static func hasValidAPIConfig() -> Bool {
        return loadAPIConfig().isValid()
    }
}