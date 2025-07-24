import SwiftUI

/// API服务集成示例代码
struct APIServiceIntegrationExample {
    
    /// 示例1：基础配置和使用
    static func basicUsageExample() {
        // 1. 配置API服务
        let config = APIServiceConfig(
            baseURL: "https://api.siliconflow.cn/v1",
            apiKey: "your-actual-api-key-here",
            model: "deepseek-ai/DeepSeek-V3"
        )
        
        APIConfigurationManager.shared.saveConfiguration(config)
        
        // 2. 生成行李建议
        Task {
            do {
                let suggestion = try await SiliconFlowAPIService.shared.generateLuggageSuggestion(
                    destination: "东京",
                    duration: 7,
                    season: "春季",
                    activities: ["观光", "购物", "美食", "温泉"]
                )
                print("行李建议：\(suggestion)")
            } catch {
                print("错误：\(error.localizedDescription)")
            }
        }
    }
    
    /// 示例2：在SwiftUI中使用
    static func swiftUIExample() -> some View {
        return VStack {
            NavigationLink("API配置") {
                APIConfigurationView()
            }
            
            NavigationLink("行李建议") {
                LuggageSuggestionView()
            }
        }
    }
    
    /// 示例3：自定义配置
    static func customConfigurationExample() {
        // 创建自定义配置
        let customConfig = APIServiceConfig(
            baseURL: "https://custom-api.com/v1",
            apiKey: "custom-key",
            model: "custom-model",
            maxTokens: 2000,
            temperature: 0.8,
            topP: 0.9
        )
        
        // 验证配置
        let validation = customConfig.validate()
        if validation.isValid {
            APIConfigurationManager.shared.saveConfiguration(customConfig)
        } else {
            print("配置错误：\(validation.errors)")
        }
    }
    
    /// 示例4：错误处理
    static func errorHandlingExample() {
        Task {
            do {
                let service = SiliconFlowAPIService.shared
                
                // 检查配置
                guard service.isConfigured() else {
                    print("API未配置")
                    return
                }
                
                // 生成建议
                let suggestion = try await service.generateLuggageSuggestion(
                    destination: "巴黎",
                    duration: 10,
                    season: "夏季",
                    activities: ["观光", "摄影", "美食"]
                )
                
                print("成功生成建议：\(suggestion)")
                
            } catch APIError.invalidConfiguration(let message) {
                print("配置错误：\(message)")
            } catch APIError.networkError(let error) {
                print("网络错误：\(error.localizedDescription)")
            } catch APIError.apiError(let message) {
                print("API错误：\(message)")
            } catch {
                print("未知错误：\(error.localizedDescription)")
            }
        }
    }
}

/// SwiftUI集成示例视图
struct APIIntegrationDemoView: View {
    @StateObject private var configManager = APIConfigurationManager.shared
    @State private var showConfiguration = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("快速开始") {
                    NavigationLink("1. 配置API") {
                        APIConfigurationView()
                    }
                    
                    NavigationLink("2. 生成行李建议") {
                        LuggageSuggestionView()
                    }
                }
                
                Section("使用示例") {
                    Button("运行示例代码") {
                        APIServiceIntegrationExample.basicUsageExample()
                    }
                    
                    Button("测试配置") {
                        Task {
                            let result = try? await configManager.testConnection()
                            print("测试结果：\(result ?? "未测试")")
                        }
                    }
                }
            }
            .navigationTitle("API集成示例")
        }
    }
}