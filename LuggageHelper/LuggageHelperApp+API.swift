import SwiftUI

extension LuggageHelperApp {
    
    /// 初始化API服务
    func setupAPIService() {
        // 检查是否有保存的配置
        if !APIConfigurationManager.shared.hasSavedConfiguration {
            // 使用默认配置
            APIConfigurationManager.shared.saveConfiguration(.default)
        }
    }
}