import Foundation
import Combine
import os.log

/// LLM API服务
/// 提供与各种LLM API的完整交互功能，支持OpenAI和Anthropic格式
final class LLMAPIService: ObservableObject {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = LLMAPIService()
    
    /// 取消订阅集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 私有初始化
    private init() {
        // 监听配置变更
        LLMConfigurationManager.shared.configurationChanged
            .sink { [weak self] in
                self?.syncConfiguration()
            }
            .store(in: &cancellables)
        
        // 立即同步配置
        syncConfiguration()
    }
    
    // MARK: - 日志配置
    
    /// 日志记录器
    internal let logger = Logger(subsystem: "com.luggagehelper.api", category: "LLMAPI")
    
    /// 是否启用详细日志
    internal let enableDetailedLogging = true
    
    // MARK: - 可观察属性
    
    /// 当前API配置
    @Published var currentConfig: LLMServiceConfig?
    
    /// 是否正在加载
    @Published var isLoading = false
    
    /// 错误消息
    @Published var errorMessage: String? = nil
    
    // MARK: - 网络配置
    
    /// URLSession配置
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60  // 增加到60秒
        config.timeoutIntervalForResource = 120 // 增加到120秒
        return URLSession(configuration: config)
    }()
    
    /// JSON编码器
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    /// JSON解码器
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    // MARK: - 提供商类型
    
    /// LLM提供商类型
    enum LLMProviderType: String, CaseIterable, Codable {
        case openai = "openai"      // 支持 OpenAI 格式 (OpenAI, 硅基流动, 智谱AI等)
        case anthropic = "anthropic" // 支持 Anthropic 格式
        
        var displayName: String {
            switch self {
            case .openai: return "OpenAI 格式"
            case .anthropic: return "Anthropic 格式"
            }
        }
        
        var defaultEndpoint: String {
            switch self {
            case .openai: return "/v1/chat/completions"
            case .anthropic: return "/v1/messages"
            }
        }
        
        var description: String {
            switch self {
            case .openai: return "兼容 OpenAI、硅基流动、智谱AI 等服务商"
            case .anthropic: return "兼容 Anthropic Claude API"
            }
        }
    }
    
    // MARK: - 配置结构
    
    /// LLM服务配置
    struct LLMServiceConfig: Codable {
        let providerType: LLMProviderType
        let baseURL: String
        let apiKey: String
        let model: String
        let maxTokens: Int?
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let frequencyPenalty: Double?
        let stop: [String]?
        
        init(providerType: LLMProviderType = .openai,
             baseURL: String,
             apiKey: String,
             model: String,
             maxTokens: Int? = 2048,
             temperature: Double? = 0.7,
             topP: Double? = 0.9,
             topK: Int? = 50,
             frequencyPenalty: Double? = 0.0,
             stop: [String]? = nil) {
            self.providerType = providerType
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.topP = topP
            self.topK = topK
            self.frequencyPenalty = frequencyPenalty
            self.stop = stop
        }
        
        /// 检查配置是否有效
        func isValid() -> Bool {
            return !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
        }
        
        /// 获取完整的API端点URL
        var fullEndpointURL: String {
            let cleanBaseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return cleanBaseURL + providerType.defaultEndpoint
        }
    }
    
    // MARK: - 错误类型
    
    /// API错误类型
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case serverError(statusCode: Int, message: String?)
        case decodingError(Error)
        case encodingError(Error)
        case networkError(Error)
        case configurationError(String)
        case rateLimitExceeded
        case authenticationFailed
        case insufficientData
        case unsupportedProvider(LLMProviderType)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的API地址"
            case .invalidResponse:
                return "服务器响应无效"
            case .serverError(let statusCode, let message):
                return "服务器错误 (状态码: \(statusCode)) - \(message ?? "未知错误")"
            case .decodingError(let error):
                return "数据解析失败: \(error.localizedDescription)"
            case .encodingError(let error):
                return "数据编码失败: \(error.localizedDescription)"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .configurationError(let message):
                return "配置错误: \(message)"
            case .rateLimitExceeded:
                return "请求频率超限，请稍后再试"
            case .authenticationFailed:
                return "认证失败，请检查API密钥"
            case .insufficientData:
                return "提供的数据不足"
            case .unsupportedProvider(let provider):
                return "不支持的提供商类型: \(provider.displayName)"
            }
        }
    }

    // MARK: - 请求模型
    
    /// 聊天消息模型
    struct ChatMessage: Codable {
        let role: String
        let content: String
        
        init(role: String, content: String) {
            self.role = role
            self.content = content
        }
        
        static func system(_ content: String) -> ChatMessage {
            return ChatMessage(role: "system", content: content)
        }
        
        static func user(_ content: String) -> ChatMessage {
            return ChatMessage(role: "user", content: content)
        }
        
        static func assistant(_ content: String) -> ChatMessage {
            return ChatMessage(role: "assistant", content: content)
        }
    }
    
    /// 聊天完成请求模型
    struct ChatCompletionRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let maxTokens: Int?
        let temperature: Double?
        let topP: Double?
        let stream: Bool
        let responseFormat: ResponseFormat?
        let topK: Int?
        let frequencyPenalty: Double?
        let stop: [String]?
        
        struct ResponseFormat: Codable {
            let type: String
        }
        
        init(model: String, messages: [ChatMessage], maxTokens: Int? = nil, 
             temperature: Double? = nil, topP: Double? = nil, stream: Bool = false,
             responseFormat: ResponseFormat? = nil, topK: Int? = nil, 
             frequencyPenalty: Double? = nil, stop: [String]? = nil) {
            self.model = model
            self.messages = messages
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.topP = topP
            self.stream = stream
            self.responseFormat = responseFormat
            self.topK = topK
            self.frequencyPenalty = frequencyPenalty
            self.stop = stop
        }
    }
    
    /// 聊天完成响应模型
    struct ChatCompletionResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage?
        
        struct Choice: Codable {
            let index: Int
            let message: ChatMessage
            let finishReason: String?
        }
        
        struct Usage: Codable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
        }
    }
    
    /// 流式响应数据模型
    struct StreamingResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [StreamChoice]
        
        struct StreamChoice: Codable {
            let index: Int
            let delta: Delta
            let finishReason: String?
            
            struct Delta: Codable {
                let role: String?
                let content: String?
            }
        }
    }
    
    // MARK: - 配置检查方法
    
    /// 检查服务是否已正确配置
    func isConfigured() -> Bool {
        guard let validConfig = currentConfig else { return false }
        return validConfig.isValid()
    }
    
    // MARK: - 主要API方法
    
    /// 发送聊天完成请求（同步）
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - config: API配置（可选，使用默认配置）
    /// - Returns: 响应结果
    func sendChatCompletion(
        messages: [ChatMessage],
        config: LLMServiceConfig? = nil
    ) async throws -> ChatCompletionResponse {
        let config = config ?? currentConfig ?? LLMConfigurationManager.shared.currentConfig
        
        guard config.isValid() else {
            throw APIError.configurationError("LLM API配置无效")
        }
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP,
            stream: false,
            responseFormat: nil,
            topK: config.topK,
            frequencyPenalty: config.frequencyPenalty,
            stop: config.stop
        )
        
        return try await performRequest(request, config: config)
    }
    
    /// 发送流式聊天完成请求
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - config: API配置（可选，使用默认配置）
    /// - Returns: 流式响应发布者
    func sendStreamingChatCompletion(
        messages: [ChatMessage],
        config: LLMServiceConfig? = nil
    ) -> AnyPublisher<String, Error> {
        let config = config ?? currentConfig ?? LLMConfigurationManager.shared.currentConfig
        
        guard config.isValid() else {
            return Fail(error: APIError.configurationError("LLM API配置无效"))
                .eraseToAnyPublisher()
        }
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP,
            stream: true,
            responseFormat: nil,
            topK: config.topK,
            frequencyPenalty: config.frequencyPenalty,
            stop: config.stop
        )
        
        return performStreamingRequest(request, config: config)
    }
    
    /// 测试API连接
    /// - Parameter config: API配置（可选）
    /// - Returns: 测试结果
    func testConnection(config: LLMServiceConfig? = nil) async throws -> String {
        let config = config ?? currentConfig ?? LLMConfigurationManager.shared.currentConfig
        
        guard config.isValid() else {
            throw APIError.configurationError("LLM API配置无效")
        }
        
        let testMessages = [
            ChatMessage.system("你是一个测试助手。"),
            ChatMessage.user("请回复'连接测试成功'")
        ]
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: testMessages,
            maxTokens: 50,
            temperature: 0.1,
            topP: 0.9,
            stream: false,
            responseFormat: nil,
            topK: 50,
            frequencyPenalty: 0.0,
            stop: nil
        )
        
        do {
            let response = try await performRequest(request, config: config)
            
            if let content = response.choices.first?.message.content {
                logger.info("LLM API连接测试成功")
                return content
            } else {
                throw APIError.invalidResponse
            }
        } catch {
            logger.error("LLM API连接测试失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - 私有方法
    
    /// 执行API请求
    internal func performRequest(
        _ request: ChatCompletionRequest,
        config: LLMServiceConfig
    ) async throws -> ChatCompletionResponse {
        
        // 根据提供商类型选择适配器
        switch config.providerType {
        case .openai:
            return try await performOpenAIRequest(request, config: config)
        case .anthropic:
            return try await performAnthropicRequest(request, config: config)
        }
    }
    
    /// 执行OpenAI格式请求
    private func performOpenAIRequest(
        _ request: ChatCompletionRequest,
        config: LLMServiceConfig
    ) async throws -> ChatCompletionResponse {
        
        guard let url = URL(string: config.fullEndpointURL) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw APIError.encodingError(error)
        }
        
        if enableDetailedLogging {
            logger.info("发送OpenAI格式API请求到: \(url.absoluteString)")
            logger.debug("请求体: \(String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? "无法解析")")
        }
        
        return try await executeRequest(urlRequest)
    }
    
    /// 执行Anthropic格式请求
    private func performAnthropicRequest(
        _ request: ChatCompletionRequest,
        config: LLMServiceConfig
    ) async throws -> ChatCompletionResponse {
        
        guard let url = URL(string: config.fullEndpointURL) else {
            throw APIError.invalidURL
        }
        
        // 转换为Anthropic格式
        let anthropicRequest = convertToAnthropicFormat(request)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(anthropicRequest)
        } catch {
            throw APIError.encodingError(error)
        }
        
        if enableDetailedLogging {
            logger.info("发送Anthropic格式API请求到: \(url.absoluteString)")
            logger.debug("请求体: \(String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? "无法解析")")
        }
        
        // 执行请求并转换响应
        let anthropicResponse = try await executeAnthropicRequest(urlRequest)
        return convertFromAnthropicFormat(anthropicResponse)
    }
    
    /// 执行通用HTTP请求
    private func executeRequest(_ urlRequest: URLRequest) async throws -> ChatCompletionResponse {
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if enableDetailedLogging {
                logger.info("收到响应，状态码: \(httpResponse.statusCode)")
                logger.debug("响应体: \(String(data: data, encoding: .utf8) ?? "无法解析")")
            }
            
            // 检查HTTP状态码
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // 解析响应
            do {
                let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
                return chatResponse
            } catch {
                logger.error("响应解析失败: \(error)")
                throw APIError.decodingError(error)
            }
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    /// 执行流式请求
    private func performStreamingRequest(
        _ request: ChatCompletionRequest,
        config: LLMServiceConfig,
        onReceive: @escaping (String) -> Void = { _ in }
    ) -> AnyPublisher<String, Error> {
        
        // 目前只支持OpenAI格式的流式请求
        guard config.providerType == .openai else {
            return Fail(error: APIError.unsupportedProvider(config.providerType))
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: config.fullEndpointURL) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            return Fail(error: APIError.encodingError(error))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    let errorMessage = String(data: data, encoding: .utf8)
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
                }
                
                return data
            }
            .flatMap { data -> AnyPublisher<String, Error> in
                let dataString = String(data: data, encoding: .utf8) ?? ""
                let lines = dataString.components(separatedBy: .newlines)
                
                return Publishers.Sequence(sequence: lines)
                    .compactMap { line -> String? in
                        // 处理SSE格式
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                return nil
                            }
                            
                            guard let jsonData = jsonString.data(using: .utf8) else {
                                return nil
                            }
                            
                            do {
                                let streamResponse = try JSONDecoder().decode(StreamingResponse.self, from: jsonData)
                                return streamResponse.choices.first?.delta.content
                            } catch {
                                return nil
                            }
                        }
                        return nil
                    }
                    .compactMap { $0 }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Anthropic格式转换扩展

extension LLMAPIService {
    
    /// Anthropic请求格式
    private struct AnthropicRequest: Codable {
        let model: String
        let max_tokens: Int
        let messages: [AnthropicMessage]
        let system: String?
        let temperature: Double?
        let top_p: Double?
        let top_k: Int?
        let stop_sequences: [String]?
    }
    
    /// Anthropic消息格式
    private struct AnthropicMessage: Codable {
        let role: String
        let content: String
    }
    
    /// Anthropic响应格式
    private struct AnthropicResponse: Codable {
        let id: String
        let type: String
        let role: String
        let content: [AnthropicContent]
        let model: String
        let stop_reason: String?
        let stop_sequence: String?
        let usage: AnthropicUsage
        
        struct AnthropicContent: Codable {
            let type: String
            let text: String
        }
        
        struct AnthropicUsage: Codable {
            let input_tokens: Int
            let output_tokens: Int
        }
    }
    
    /// 转换为Anthropic格式
    private func convertToAnthropicFormat(_ request: ChatCompletionRequest) -> AnthropicRequest {
        var systemMessage: String?
        var messages: [AnthropicMessage] = []
        
        for message in request.messages {
            if message.role == "system" {
                systemMessage = message.content
            } else {
                messages.append(AnthropicMessage(role: message.role, content: message.content))
            }
        }
        
        return AnthropicRequest(
            model: request.model,
            max_tokens: request.maxTokens ?? 2048,
            messages: messages,
            system: systemMessage,
            temperature: request.temperature,
            top_p: request.topP,
            top_k: request.topK,
            stop_sequences: request.stop
        )
    }
    
    /// 执行Anthropic请求
    private func executeAnthropicRequest(_ urlRequest: URLRequest) async throws -> AnthropicResponse {
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if enableDetailedLogging {
                logger.info("收到Anthropic响应，状态码: \(httpResponse.statusCode)")
                logger.debug("响应体: \(String(data: data, encoding: .utf8) ?? "无法解析")")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            do {
                let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
                return anthropicResponse
            } catch {
                logger.error("Anthropic响应解析失败: \(error)")
                throw APIError.decodingError(error)
            }
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    /// 从Anthropic格式转换
    private func convertFromAnthropicFormat(_ response: AnthropicResponse) -> ChatCompletionResponse {
        let content = response.content.first?.text ?? ""
        
        let choice = ChatCompletionResponse.Choice(
            index: 0,
            message: ChatMessage(role: "assistant", content: content),
            finishReason: response.stop_reason
        )
        
        let usage = ChatCompletionResponse.Usage(
            promptTokens: response.usage.input_tokens,
            completionTokens: response.usage.output_tokens,
            totalTokens: response.usage.input_tokens + response.usage.output_tokens
        )
        
        return ChatCompletionResponse(
            id: response.id,
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: response.model,
            choices: [choice],
            usage: usage
        )
    }


    // MARK: - Configuration Sync

    /// 同步配置
    func syncConfiguration() {
        self.currentConfig = LLMConfigurationManager.shared.currentConfig
        print("🔄 LLMAPIService配置已同步:")
        print("   - 配置有效性: \(currentConfig?.isValid() ?? false)")
        print("   - baseURL: \(currentConfig?.baseURL ?? "未设置")")
        print("   - model: \(currentConfig?.model ?? "未设置")")
    }

    /// 确保配置同步
    /// - Returns: 当前有效的配置
    func ensureConfigurationSync() -> LLMServiceConfig {
        let managerConfig = LLMConfigurationManager.shared.currentConfig
        if currentConfig == nil || !currentConfig!.isValid() {
            currentConfig = managerConfig
            print("⚠️ 检测到配置不同步，已重新同步")
        }
        return currentConfig ?? managerConfig
    }
}