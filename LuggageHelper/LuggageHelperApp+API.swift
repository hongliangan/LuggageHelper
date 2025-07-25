import SwiftUI

extension LuggageHelperApp {
    
    /// 初始化API服务
    func setupAPIService() {
        // 检查是否有保存的配置
        if !APIConfigurationManager.shared.hasSavedConfiguration {
            // 使用默认配置
            APIConfigurationManager.shared.saveConfiguration(.default)
        }
        
        // 修改LLM配置初始化逻辑 - 避免覆盖用户配置
        let defaults = UserDefaults.standard
        let hasAnyLLMConfig = defaults.string(forKey: UserDefaultsKeys.llmApiKey) != nil ||
                             defaults.string(forKey: UserDefaultsKeys.llmApiBaseURL) != nil ||
                             defaults.string(forKey: UserDefaultsKeys.llmApiModel) != nil
        
        if !hasAnyLLMConfig {
            print("🔧 首次启动，初始化默认LLM配置")
            // 只有在完全没有LLM配置时才保存默认配置
            LLMConfigurationManager.shared.saveConfiguration(.default)
        } else {
            print("🔧 检测到已有LLM配置，跳过默认配置初始化")
            // 如果有配置，直接加载现有配置
            LLMConfigurationManager.shared.loadConfiguration()
        }
        
        // 确保LLMAPIService配置同步
        LLMAPIService.shared.syncConfiguration()
    }
}