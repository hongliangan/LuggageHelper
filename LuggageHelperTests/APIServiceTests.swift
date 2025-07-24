import XCTest
@testable import LuggageHelper

/// 硅基流动API集成测试类
class APIServiceTests: XCTestCase {
    
    var apiService: SiliconFlowAPIService!
    var configManager: APIConfigurationManager!
    
    override func setUp() {
        super.setUp()
        configManager = APIConfigurationManager.shared
        apiService = SiliconFlowAPIService.shared
        
        // 使用测试配置
        let testConfig = APIServiceConfig(
            baseURL: "https://api.siliconflow.cn/v1",
            apiKey: "test-key",
            model: "deepseek-ai/DeepSeek-V3",
            maxTokens: 1000,
            temperature: 0.7,
            topP: 0.9
        )
        configManager.saveConfiguration(testConfig)
    }
    
    override func tearDown() {
        configManager.clearConfiguration()
        super.tearDown()
    }
    
    /// 测试API配置验证
    func testAPIConfigurationValidation() {
        // 测试有效配置
        let validConfig = APIServiceConfig.default
        let validationResult = validConfig.validate()
        XCTAssertTrue(validationResult.isValid)
        XCTAssertEqual(validationResult.errors.count, 0)
        
        // 测试无效配置
        let invalidConfig = APIServiceConfig(
            baseURL: "",
            apiKey: "",
            model: "invalid-model",
            maxTokens: 0,
            temperature: 3.0,
            topP: 2.0
        )
        let invalidResult = invalidConfig.validate()
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertGreaterThan(invalidResult.errors.count, 0)
    }
    
    /// 测试配置保存和加载
    func testConfigurationPersistence() {
        let testConfig = APIServiceConfig(
            baseURL: "https://test.api.com",
            apiKey: "test-key-123",
            model: "test-model",
            maxTokens: 2000,
            temperature: 0.8,
            topP: 0.95
        )
        
        // 保存配置
        configManager.saveConfiguration(testConfig)
        
        // 重新加载配置
        let loadedConfig = configManager.currentConfig
        XCTAssertEqual(loadedConfig.baseURL, "https://test.api.com")
        XCTAssertEqual(loadedConfig.apiKey, "test-key-123")
        XCTAssertEqual(loadedConfig.model, "test-model")
        XCTAssertEqual(loadedConfig.maxTokens, 2000)
        XCTAssertEqual(loadedConfig.temperature, 0.8)
        XCTAssertEqual(loadedConfig.topP, 0.95)
    }
    
    /// 测试API服务初始化
    func testAPIServiceInitialization() {
        XCTAssertNotNil(apiService)
        XCTAssertNotNil(configManager)
        XCTAssertTrue(apiService.isConfigured())
    }
    
    /// 测试行李建议生成提示词
    func testLuggageSuggestionPrompt() {
        let prompt = apiService.generateLuggagePrompt(
            destination: "北京",
            duration: 5,
            season: "春季",
            activities: ["观光", "购物", "美食"]
        )
        
        XCTAssertTrue(prompt.contains("北京"))
        XCTAssertTrue(prompt.contains("5天"))
        XCTAssertTrue(prompt.contains("春季"))
        XCTAssertTrue(prompt.contains("观光"))
        XCTAssertTrue(prompt.contains("购物"))
        XCTAssertTrue(prompt.contains("美食"))
    }
    
    /// 测试错误处理
    func testErrorHandling() {
        // 测试无效API密钥
        let invalidConfig = APIServiceConfig(
            baseURL: "https://api.siliconflow.cn/v1",
            apiKey: "invalid-key",
            model: "test-model"
        )
        configManager.saveConfiguration(invalidConfig)
        
        let expectation = XCTestExpectation(description: "Error handling")
        
        Task {
            do {
                _ = try await apiService.generateLuggageSuggestion(
                    destination: "测试",
                    duration: 1,
                    season: "春季",
                    activities: ["测试"]
                )
                XCTFail("Should have thrown an error")
            } catch {
                XCTAssertTrue(error is APIError)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}