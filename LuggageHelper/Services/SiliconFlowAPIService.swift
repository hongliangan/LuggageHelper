import Foundation
import Combine
import os.log

/// 硅基流动API服务
/// 提供与硅基流动API的完整交互功能，支持OpenAI格式
final class SiliconFlowAPIService: ObservableObject {
    
    // MARK: - 单例模式
    
    /// 共享实例
    static let shared = SiliconFlowAPIService()
    
    /// 私有初始化
    private init() {}
    
    // MARK: - 日志配置
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.luggagehelper.api", category: "SiliconFlowAPI")
    
    /// 是否启用详细日志
    private let enableDetailedLogging = true
    
    // MARK: - 可观察属性
    
    /// 当前API配置
    @Published var currentConfig: APIServiceConfig?
    
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
            ChatMessage(role: "system", content: content)
        }
        
        static func user(_ content: String) -> ChatMessage {
            ChatMessage(role: "user", content: content)
        }
        
        static func assistant(_ content: String) -> ChatMessage {
            ChatMessage(role: "assistant", content: content)
        }
    }
    
    /// 聊天完成请求
    struct ChatCompletionRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let maxTokens: Int?
        let temperature: Double?
        let topP: Double?
        let stream: Bool?
        let responseFormat: ResponseFormat?
        // 添加新参数
        let topK: Int?
        let frequencyPenalty: Double?
        let stop: [String]?
    
        enum CodingKeys: String, CodingKey {
            case model, messages, stream, stop
            case maxTokens = "max_tokens"
            case temperature, topP = "top_p"
            case responseFormat = "response_format"
            case topK = "top_k"
            case frequencyPenalty = "frequency_penalty"
        }
    }
    
    /// 响应格式
    struct ResponseFormat: Codable {
        let type: String
    }
    
    /// 聊天完成响应
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
            
            enum CodingKeys: String, CodingKey {
                case index, message
                case finishReason = "finish_reason"
            }
        }
        
        struct Usage: Codable {
            let promptTokens: Int?
            let completionTokens: Int?
            let totalTokens: Int?
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
             init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
                completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
                totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
            }
        }
    }
      
     
    
    /// 流式响应块
    struct StreamResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [StreamChoice]
        
        struct StreamChoice: Codable {
            let index: Int
            let delta: Delta
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case index, delta
                case finishReason = "finish_reason"
            }
        }
        
        struct Delta: Codable {
            let role: String?
            let content: String?
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
        config: APIServiceConfig? = nil
    ) async throws -> ChatCompletionResponse {
        let config = config ?? APIConfigurationManager.shared.currentConfig
        
        guard config.isValid() else {
            throw APIError.configurationError("API配置无效")
        }
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP,
            stream: false,
            responseFormat: nil,
            topK: nil,
            frequencyPenalty: nil,
            stop: nil
        )
        
        return try await performRequest(request, config: config)
    }
    
    /// 发送聊天完成请求（流式）
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - config: API配置（可选，使用默认配置）
    /// - Returns: 流式响应发布者
    func sendStreamingChatCompletion(
        messages: [ChatMessage],
        config: APIServiceConfig? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let config = config ?? APIConfigurationManager.shared.currentConfig
                                      
                    guard config.isValid() else {
                        throw APIError.configurationError("API配置无效")
                    }
                    
                    let request = ChatCompletionRequest(
                        model: config.model,
                        messages: messages,
                        maxTokens: config.maxTokens,
                        temperature: config.temperature,
                        topP: config.topP,
                        stream: true,
                        responseFormat: nil,
                        topK: nil,
                        frequencyPenalty: nil,
                        stop: nil
                    )
                    
                    try await performStreamingRequest(request, config: config) { chunk in
                        if let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// 测试API连接
    /// - Parameter config: API配置（可选）
    /// - Returns: 测试结果
    func testConnection(config: APIServiceConfig? = nil) async throws -> String {
        let config = config ?? APIConfigurationManager.shared.currentConfig
        
        guard config.isValid() else {
            throw APIError.configurationError("API配置无效")
        }
        
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 使用一个最小化的请求体进行测试
        let testRequest = ChatCompletionRequest(
            model: config.model,
            messages: [ChatMessage.user("test")],
            maxTokens: 1,
            temperature: 0,
            topP: 0,
            stream: false,
            responseFormat: nil,
            topK: nil,
            frequencyPenalty: nil,
            stop: nil
        )
        
        do {
            urlRequest.httpBody = try encoder.encode(testRequest)
        } catch {
            throw APIError.encodingError(error)
        }
        
        do {
            let (_, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                return "连接成功，服务器返回状态码: \(httpResponse.statusCode)"
            case 401:
                throw APIError.authenticationFailed
            case 429:
                throw APIError.rateLimitExceeded
            default:
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: nil)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - 私有方法
    
    /// 执行API请求
    private func performRequest(
        _ request: ChatCompletionRequest,
        config: APIServiceConfig
    ) async throws -> ChatCompletionResponse {
        let requestId = UUID().uuidString.prefix(8)
        
        // 记录请求开始
        logger.info("[\(requestId)] 开始API请求")
        logger.info("[\(requestId)] 请求URL: \(config.baseURL)/chat/completions")
        logger.info("[\(requestId)] 模型: \(request.model)")
        logger.info("[\(requestId)] 消息数量: \(request.messages.count)")
        
        if enableDetailedLogging {
            logger.debug("[\(requestId)] 请求参数详情:")
            logger.debug("[\(requestId)] - maxTokens: \(request.maxTokens ?? 0)")
            logger.debug("[\(requestId)] - temperature: \(request.temperature ?? 0.0)")
            logger.debug("[\(requestId)] - topP: \(request.topP ?? 0.0)")
            
            // 记录消息内容（敏感信息脱敏）
            for (index, message) in request.messages.enumerated() {
                let contentPreview = message.content.count > 100 ? 
                    String(message.content.prefix(100)) + "..." : message.content
                logger.debug("[\(requestId)] 消息[\(index)] - 角色: \(message.role), 内容: \(contentPreview)")
            }
        }
        
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            logger.error("[\(requestId)] 无效的URL: \(config.baseURL)/chat/completions")
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let requestData = try encoder.encode(request)
            urlRequest.httpBody = requestData
            
            if enableDetailedLogging {
                logger.debug("[\(requestId)] 请求体大小: \(requestData.count) bytes")
                if let requestString = String(data: requestData, encoding: .utf8) {
                    let preview = requestString.count > 500 ? 
                        String(requestString.prefix(500)) + "..." : requestString
                    logger.debug("[\(requestId)] 请求体内容: \(preview)")
                }
            }
        } catch {
            logger.error("[\(requestId)] 请求编码失败: \(error.localizedDescription)")
            throw APIError.encodingError(error)
        }
        
        let startTime = Date()
        
        do {
            logger.info("[\(requestId)] 发送HTTP请求...")
            let (data, response) = try await session.data(for: urlRequest)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.info("[\(requestId)] 请求完成，耗时: \(String(format: "%.2f", duration))秒")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("[\(requestId)] 无效的HTTP响应")
                throw APIError.invalidResponse
            }
            
            logger.info("[\(requestId)] HTTP状态码: \(httpResponse.statusCode)")
            logger.info("[\(requestId)] 响应数据大小: \(data.count) bytes")
            
            if enableDetailedLogging {
                // 记录响应头
                for (key, value) in httpResponse.allHeaderFields {
                    logger.debug("[\(requestId)] 响应头 \(String(describing: key)): \(String(describing: value))")
                }
                
                // 记录响应内容
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = responseString.count > 1000 ? 
                        String(responseString.prefix(1000)) + "..." : responseString
                    logger.debug("[\(requestId)] 响应内容: \(preview)")
                }
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                logger.info("[\(requestId)] 请求成功")
                break
            case 401:
                logger.error("[\(requestId)] 认证失败 (401)")
                throw APIError.authenticationFailed
            case 429:
                logger.error("[\(requestId)] 请求频率限制 (429)")
                throw APIError.rateLimitExceeded
            case 400..<500:
                let errorMessage = String(data: data, encoding: .utf8) ?? "客户端错误"
                logger.error("[\(requestId)] 客户端错误 (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            case 500..<600:
                let errorMessage = String(data: data, encoding: .utf8) ?? "服务器错误"
                logger.error("[\(requestId)] 服务器错误 (\(httpResponse.statusCode)): \(errorMessage)")
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            default:
                logger.error("[\(requestId)] 未知状态码: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            // 增加对空数据的检查
            guard !data.isEmpty else {
                logger.error("[\(requestId)] 响应数据为空")
                throw APIError.invalidResponse
            }

            do {
                let decodedResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
                logger.info("[\(requestId)] 响应解码成功")
                
                if enableDetailedLogging {
                    logger.debug("[\(requestId)] 响应选择数量: \(decodedResponse.choices.count)")
                    if let firstChoice = decodedResponse.choices.first {
                        let contentPreview = firstChoice.message.content.count > 200 ? 
                            String(firstChoice.message.content.prefix(200)) + "..." : firstChoice.message.content
                        logger.debug("[\(requestId)] 响应内容预览: \(contentPreview)")
                    }
                }
                
                return decodedResponse
            } catch {
                logger.error("[\(requestId)] 响应解码失败: \(error.localizedDescription)")
                if enableDetailedLogging {
                    logger.debug("[\(requestId)] 解码错误详情: \(error)")
                }
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            logger.error("[\(requestId)] API错误: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("[\(requestId)] 网络错误: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    /// 执行流式请求
    private func performStreamingRequest(
        _ request: ChatCompletionRequest,
        config: APIServiceConfig,
        onChunk: @escaping (StreamResponse) -> Void
    ) async throws {
        let requestId = UUID().uuidString.prefix(8)
        
        // 记录流式请求开始
        logger.info("[\(requestId)] 开始流式API请求")
        logger.info("[\(requestId)] 请求URL: \(config.baseURL)/chat/completions")
        logger.info("[\(requestId)] 模型: \(request.model)")
        
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            logger.error("[\(requestId)] 无效的URL: \(config.baseURL)/chat/completions")
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let requestData = try encoder.encode(request)
            urlRequest.httpBody = requestData
            
            if enableDetailedLogging {
                logger.debug("[\(requestId)] 流式请求体大小: \(requestData.count) bytes")
            }
        } catch {
            logger.error("[\(requestId)] 流式请求编码失败: \(error.localizedDescription)")
            throw APIError.encodingError(error)
        }
        
        let startTime = Date()
        
        do {
            logger.info("[\(requestId)] 发送流式HTTP请求...")
            let (asyncBytes, response) = try await session.bytes(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("[\(requestId)] 流式请求无效的HTTP响应")
                throw APIError.invalidResponse
            }
            
            logger.info("[\(requestId)] 流式响应状态码: \(httpResponse.statusCode)")
            
            guard 200..<300 ~= httpResponse.statusCode else {
                logger.error("[\(requestId)] 流式请求失败，状态码: \(httpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            var chunkCount = 0
            var totalContentLength = 0
            
            logger.info("[\(requestId)] 开始处理流式响应...")
            
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    let data = line.dropFirst(6)
                    
                    if data == "[DONE]" {
                        let duration = Date().timeIntervalSince(startTime)
                        logger.info("[\(requestId)] 流式响应完成，总耗时: \(String(format: "%.2f", duration))秒")
                        logger.info("[\(requestId)] 总共处理 \(chunkCount) 个数据块，内容总长度: \(totalContentLength) 字符")
                        break
                    }
                    
                    do {
                        let chunk = try decoder.decode(StreamResponse.self, from: Data(data.utf8))
                        chunkCount += 1
                        
                        if let content = chunk.choices.first?.delta.content {
                            totalContentLength += content.count
                            
                            if enableDetailedLogging && chunkCount <= 5 {
                                logger.debug("[\(requestId)] 数据块[\(chunkCount)]: \(content)")
                            }
                        }
                        
                        onChunk(chunk)
                    } catch {
                        logger.warning("[\(requestId)] 跳过无法解码的数据块: \(String(data))")
                        continue
                    }
                }
            }
        } catch {
            logger.error("[\(requestId)] 流式请求错误: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - AI 增强功能扩展

extension SiliconFlowAPIService {
    
    // MARK: - 物品识别功能
    
    /// 识别物品信息
    /// - Parameters:
    ///   - name: 物品名称
    ///   - model: 物品型号（可选）
    ///   - brand: 品牌（可选）
    ///   - additionalInfo: 额外信息（可选）
    /// - Returns: 物品信息
    func identifyItem(name: String, model: String? = nil, brand: String? = nil, additionalInfo: String? = nil) async throws -> ItemInfo {
        let config = APIConfigurationManager.shared.currentConfig
           
        guard config.isValid() else {
            throw APIError.configurationError("API配置无效")
        }
        
        let modelInfo = model.map { " 型号：\($0)" } ?? ""
        let brandInfo = brand.map { " 品牌：\($0)" } ?? ""
        let extraInfo = additionalInfo.map { " 补充信息：\($0)" } ?? ""
        
        let prompt = """
        请识别物品"\(name)\(modelInfo)\(brandInfo)\(extraInfo)"的详细信息，并以JSON格式返回：
        
        {
            "name": "标准化物品名称",
            "category": "物品类别",
            "weight": 重量（克，数值类型），
            "volume": 体积（立方厘米，数值类型），
            "dimensions": {
                "length": 长度（厘米，数值类型），
                "width": 宽度（厘米，数值类型），
                "height": 高度（厘米，数值类型）
            },
            "confidence": 置信度（0.0-1.0，数值类型），
            "alternatives": [
                {
                    "name": "替代品名称",
                    "weight": 重量（克），
                    "volume": 体积（立方厘米），
                    "reason": "推荐理由"
                }
            ]
        }
        
        物品类别必须是以下之一：
        - clothing: 衣物（衬衫、裤子、裙子、内衣等）
        - electronics: 电子产品（手机、电脑、充电器、耳机等）
        - toiletries: 洗漱用品（牙刷、洗发水、护肤品等）
        - documents: 证件文件（护照、身份证、合同等）
        - medicine: 药品保健（药品、维生素、医疗器械等）
        - accessories: 配饰用品（包包、首饰、手表、眼镜等）
        - shoes: 鞋类（运动鞋、皮鞋、拖鞋等）
        - books: 书籍文具（书籍、笔记本、文具等）
        - food: 食品饮料（零食、饮料、保健品等）
        - sports: 运动用品（运动器材、运动服装等）
        - beauty: 美容化妆（化妆品、护肤品、美容工具等）
        - other: 其他（无法归类的物品）
        
        请根据物品的实际用途和特性选择最合适的类别。
        对于重量和体积，请基于常见规格给出合理估算。
        置信度应该反映识别的准确程度，常见物品应该有较高置信度。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品识别专家，具有丰富的产品知识和准确的重量体积估算能力。请始终返回有效的JSON格式数据，确保数值字段为数字类型。"),
            ChatMessage.user(prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            maxTokens: min(config.maxTokens ?? 2048, 2048),
            temperature: 0.7,
            topP: 0.9,
            stream: false,
            responseFormat: nil,
            topK: 50,
            frequencyPenalty: 0.0,
            stop: nil
        )
        
        let response = try await performRequest(request, config: config)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfo(from: content, originalName: name)
    }
    
    /// 批量识别物品信息
    /// - Parameter items: 物品名称列表
    /// - Returns: 物品信息列表
    func batchIdentifyItems(_ items: [String]) async throws -> [ItemInfo] {
        guard !items.isEmpty else {
            throw APIError.insufficientData
        }
        
        let itemsList = items.enumerated().map { index, name in
            "\(index + 1). \(name)"
        }.joined(separator: "\n")
        
        let prompt = """
        请批量识别以下物品的详细信息，并以JSON数组格式返回：
        
        \(itemsList)
        
        返回格式：
        [
            {
                "name": "标准化物品名称",
                "category": "物品类别",
                "weight": 重量（克），
                "volume": 体积（立方厘米），
                "dimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "confidence": 置信度（0.0-1.0），
                "alternatives": []
            }
        ]
        
        请为每个物品提供准确的分类和合理的重量体积估算。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品识别专家，能够批量处理物品识别任务。请返回有效的JSON数组格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfoArray(from: content)
    }
    
    /// 智能物品建议
    /// - Parameters:
    ///   - category: 物品类别
    ///   - purpose: 用途描述
    ///   - constraints: 约束条件（如重量、体积限制）
    /// - Returns: 建议的物品列表
    func suggestItemsForCategory(
        category: ItemCategory,
        purpose: String,
        constraints: PackingConstraints? = nil
    ) async throws -> [ItemInfo] {
        let constraintsInfo = constraints.map { c in
            "约束条件：最大重量\(c.maxWeight)g，最大体积\(c.maxVolume)cm³"
        } ?? ""
        
        let prompt = """
        请为"\(purpose)"推荐\(category.displayName)类别的物品，\(constraintsInfo)
        
        返回JSON数组格式：
        [
            {
                "name": "物品名称",
                "category": "\(category.rawValue)",
                "weight": 重量（克），
                "volume": 体积（立方厘米），
                "dimensions": {
                    "length": 长度（厘米），
                    "width": 宽度（厘米），
                    "height": 高度（厘米）
                },
                "confidence": 置信度（0.0-1.0），
                "alternatives": []
            }
        ]
        
        请推荐3-5个最适合的物品，考虑实用性和便携性。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品推荐专家，能够根据用途和约束条件推荐合适的物品。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfoArray(from: content)
    }
    
    /// 从照片识别物品
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - hint: 识别提示（可选）
    /// - Returns: 物品信息
    func identifyItemFromPhoto(_ imageData: Data, hint: String? = nil) async throws -> ItemInfo {
        // 检查图片大小
        guard imageData.count > 0 else {
            throw APIError.invalidResponse
        }
        
        // 目前大多数 API 不支持图像输入，这里提供一个框架实现
        // 当支持视觉模型时，可以使用以下逻辑：
        
        /*
        // 将图片转换为 base64
        let base64Image = imageData.base64EncodedString()
        
        let hintText = hint.map { "提示：\($0)" } ?? ""
        
        let prompt = """
        请识别图片中的物品并返回详细信息。\(hintText)
        
        返回JSON格式：
        {
            "name": "物品名称",
            "category": "物品类别",
            "weight": 重量（克），
            "volume": 体积（立方厘米），
            "dimensions": {
                "length": 长度（厘米），
                "width": 宽度（厘米），
                "height": 高度（厘米）
            },
            "confidence": 置信度（0.0-1.0），
            "alternatives": []
        }
        """
        
        // 构建包含图片的消息
        let messages = [
            ChatMessage.system("你是一个专业的图像识别专家，能够准确识别图片中的物品。"),
            // 这里需要支持图片消息格式
            ChatMessage(role: "user", content: prompt, image: base64Image)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfo(from: content, originalName: "图片识别物品")
        */
        
        // 临时实现：基于图片大小和提示进行模拟识别
        return try await simulatePhotoRecognition(imageData: imageData, hint: hint)
    }
    
    /// 模拟照片识别（临时实现）
    private func simulatePhotoRecognition(imageData: Data, hint: String?) async throws -> ItemInfo {
        // 基于图片大小和提示进行简单推测
        let imageSizeKB = Double(imageData.count) / 1024.0
        
        var estimatedCategory: ItemCategory = .other
        var estimatedName = "未知物品"
        var confidence = 0.3
        
        // 如果有提示，尝试识别
        if let hint = hint?.lowercased() {
            if hint.contains("衣") || hint.contains("shirt") || hint.contains("clothes") {
                estimatedCategory = .clothing
                estimatedName = "衣物"
                confidence = 0.6
            } else if hint.contains("电") || hint.contains("phone") || hint.contains("电脑") {
                estimatedCategory = .electronics
                estimatedName = "电子产品"
                confidence = 0.6
            } else if hint.contains("鞋") || hint.contains("shoe") {
                estimatedCategory = .shoes
                estimatedName = "鞋类"
                confidence = 0.6
            } else if hint.contains("包") || hint.contains("bag") {
                estimatedCategory = .accessories
                estimatedName = "包包"
                confidence = 0.6
            }
        }
        
        // 基于图片大小估算物品大小
        let estimatedWeight = min(max(imageSizeKB * 10, 50), 2000) // 50g - 2kg
        let estimatedVolume = min(max(imageSizeKB * 50, 100), 10000) // 100cm³ - 10L
        
        return ItemInfo(
            name: estimatedName,
            category: estimatedCategory,
            weight: estimatedWeight,
            volume: estimatedVolume,
            dimensions: Dimensions(
                length: pow(estimatedVolume, 1.0/3.0),
                width: pow(estimatedVolume, 1.0/3.0),
                height: pow(estimatedVolume, 1.0/3.0)
            ),
            confidence: confidence,
            source: "照片模拟识别"
        )
    }
    
    /// 检查是否支持照片识别
    func supportsPhotoRecognition() -> Bool {
        // 检查当前配置的模型是否支持视觉功能
        // 这里可以根据模型名称判断
        let config = APIConfigurationManager.shared.currentConfig
        guard config.isValid() else {
            return false
        }
        let visionModels = ["gpt-4-vision", "claude-3", "gemini-pro-vision"]
        return visionModels.contains { config.model.contains($0) }
    }
    
    // MARK: - 旅行建议功能
    
    /// 生成旅行物品清单
    /// - Parameters:
    ///   - destination: 目的地
    ///   - duration: 旅行天数
    ///   - season: 季节
    ///   - activities: 活动列表
    ///   - userPreferences: 用户偏好（可选）
    /// - Returns: 旅行建议
    func generateTravelChecklist(
        destination: String,
        duration: Int,
        season: String,
        activities: [String],
        userPreferences: UserPreferences? = nil
    ) async throws -> TravelSuggestion {
        let preferencesInfo = userPreferences.map { prefs in
            """
            用户偏好：
            - 装箱风格：\(prefs.packingStyle.displayName)
            - 预算水平：\(prefs.budgetLevel.displayName)
            - 偏好品牌：\(prefs.preferredBrands.joined(separator: "、"))
            - 避免物品：\(prefs.avoidedItems.joined(separator: "、"))
            """
        } ?? ""
        
        let prompt = """
        请为前往\(destination)的\(duration)天\(season)旅行生成详细的物品清单建议。
        计划活动：\(activities.joined(separator: "、"))
        \(preferencesInfo)
        
        请以JSON格式返回：
        {
            "destination": "\(destination)",
            "duration": \(duration),
            "season": "\(season)",
            "activities": \(activities),
            "suggestedItems": [
                {
                    "name": "物品名称",
                    "category": "类别",
                    "importance": "essential/important/recommended/optional",
                    "reason": "推荐理由",
                    "quantity": 数量,
                    "estimatedWeight": 预估重量（克）,
                    "estimatedVolume": 预估体积（立方厘米）
                }
            ],
            "categories": ["主要类别列表"],
            "tips": ["旅行小贴士"],
            "warnings": ["注意事项"]
        }
        
        请考虑当地气候、文化特点和活动需求。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的旅行规划助手，擅长根据目的地、季节和行程提供实用的行李打包建议。请始终返回有效的JSON格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseTravelSuggestion(from: content)
    }
    
    // MARK: - 装箱优化功能
    
    /// 优化装箱方案
    /// - Parameters:
    ///   - items: 物品列表
    ///   - luggage: 行李箱信息
    /// - Returns: 装箱计划
    func optimizePacking(items: [LuggageItem], luggage: Luggage) async throws -> PackingPlan {
        let itemsInfo = items.map { item in
            "- \(item.name): 重量\(item.weight)g, 体积\(item.volume)cm³"
        }.joined(separator: "\n")
        
        let prompt = """
        请为以下物品设计最优的装箱方案：
        
        行李箱信息：
        - 名称：\(luggage.name)
        - 容量：\(luggage.capacity)cm³
        - 空箱重量：\(luggage.emptyWeight)g
        
        物品清单：
        \(itemsInfo)
        
        请以JSON格式返回装箱计划：
        {
            "items": [
                {
                    "itemId": "物品ID",
                    "position": "bottom/middle/top/side/corner",
                    "priority": 优先级（1-10），
                    "reason": "装箱建议原因"
                }
            ],
            "totalWeight": 总重量,
            "totalVolume": 总体积,
            "efficiency": 空间利用率（0.0-1.0）,
            "warnings": [
                {
                    "type": "overweight/oversized/fragile/liquid/battery/prohibited",
                    "message": "警告信息",
                    "severity": "low/medium/high/critical"
                }
            ],
            "suggestions": ["装箱建议"]
        }
        
        请考虑物品的重量分布、易碎性、使用频率等因素。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的装箱优化专家，能够根据物品特性和行李箱规格提供最优的装箱方案。请始终返回有效的JSON格式数据。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parsePackingPlan(from: content, luggageId: luggage.id)
    }
    
    // MARK: - 智能分类功能
    
    /// 自动分类物品
    /// - Parameter item: 物品
    /// - Returns: 物品类别
    func categorizeItem(_ item: LuggageItem) async throws -> ItemCategory {
        let prompt = """
        请为物品"\(item.name)"确定最合适的类别。
        
        可选类别：
        - clothing: 衣物
        - electronics: 电子产品
        - toiletries: 洗漱用品
        - documents: 证件文件
        - medicine: 药品保健
        - accessories: 配饰用品
        - shoes: 鞋类
        - books: 书籍文具
        - food: 食品饮料
        - sports: 运动用品
        - beauty: 美容化妆
        - other: 其他
        
        请只返回类别英文名称，不要其他内容。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品分类专家，能够准确识别各种物品的类别。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              let category = ItemCategory(rawValue: content) else {
            return .other
        }
        
        return category
    }
    
    /// 批量分类物品
    /// - Parameter items: 物品名称列表
    /// - Returns: 物品类别列表
    func batchCategorizeItems(_ items: [String]) async throws -> [ItemCategory] {
        guard !items.isEmpty else {
            throw APIError.insufficientData
        }
        
        let itemsList = items.enumerated().map { index, name in
            "\(index + 1). \(name)"
        }.joined(separator: "\n")
        
        let prompt = """
        请为以下物品确定最合适的类别：
        
        \(itemsList)
        
        可选类别：
        - clothing: 衣物
        - electronics: 电子产品
        - toiletries: 洗漱用品
        - documents: 证件文件
        - medicine: 药品保健
        - accessories: 配饰用品
        - shoes: 鞋类
        - books: 书籍文具
        - food: 食品饮料
        - sports: 运动用品
        - beauty: 美容化妆
        - other: 其他
        
        请以JSON数组格式返回，每个元素只包含类别英文名称，例如：
        ["clothing", "electronics", "other"]
        
        数组长度必须与物品数量一致，顺序与输入物品顺序相同。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品分类专家，能够准确识别各种物品的类别。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseCategoryArray(from: content, itemCount: items.count)
    }
    
    /// 解析类别数组
    private func parseCategoryArray(from content: String, itemCount: Int) throws -> [ItemCategory] {
        // 提取JSON部分
        guard let jsonData = extractJSON(from: content) else {
            throw APIError.invalidResponse
        }
        
        do {
            let categoryStrings = try JSONDecoder().decode([String].self, from: jsonData)
            
            // 验证数组长度
            guard categoryStrings.count == itemCount else {
                throw APIError.invalidResponse
            }
            
            // 转换为ItemCategory
            return categoryStrings.map { categoryString in
                ItemCategory(rawValue: categoryString) ?? .other
            }
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// 生成物品标签
    /// - Parameter item: 物品
    /// - Returns: 标签列表
    func generateItemTags(for item: LuggageItem) async throws -> [String] {
        let prompt = """
        请为物品"\(item.name)"生成3-5个相关标签，这些标签应该描述物品的特性、用途或场景。
        
        例如，对于"iPhone 13"，可能的标签有：
        - 电子设备
        - 通讯工具
        - 苹果产品
        - 智能手机
        - 便携设备
        
        请以JSON数组格式返回标签，例如：
        ["标签1", "标签2", "标签3"]
        
        标签应该简洁、准确，每个标签不超过5个字。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的物品标签生成专家，能够为各种物品生成准确、有用的标签。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseTagsArray(from: content)
    }
    
    /// 解析标签数组
    private func parseTagsArray(from content: String) throws -> [String] {
        // 提取JSON部分
        guard let jsonData = extractJSON(from: content) else {
            throw APIError.invalidResponse
        }
        
        do {
            let tags = try JSONDecoder().decode([String].self, from: jsonData)
            return tags
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// 提取JSON字符串
    private func extractJSON(from content: String) -> Data? {
        // 查找第一个 [ 或 { 字符
        guard let startIndex = content.firstIndex(where: { $0 == "[" || $0 == "{" }) else {
            return nil
        }
        
        // 查找匹配的结束字符
        let startChar = content[startIndex]
        let endChar = startChar == "[" ? "]" : "}"
        
        var depth = 1
        var currentIndex = content.index(after: startIndex)
        
        while currentIndex < content.endIndex && depth > 0 {
            let char = content[currentIndex]
            
            if char == startChar {
                depth += 1
            } else if String(char) == endChar {
                depth -= 1
            }
            
            currentIndex = content.index(after: currentIndex)
        }
        
        // 如果找到了匹配的结束字符
        if depth == 0 {
            let jsonString = String(content[startIndex..<currentIndex])
            return jsonString.data(using: .utf8)
        }
        
        return nil
    }
    
    // MARK: - 个性化建议功能
    
    /// 获取个性化建议
    /// - Parameters:
    ///   - userProfile: 用户档案
    ///   - travelPlan: 旅行计划
    /// - Returns: 建议列表
    func getPersonalizedSuggestions(
        userProfile: UserProfile,
        travelPlan: TravelPlan
    ) async throws -> [SuggestedItem] {
        let historyInfo = userProfile.travelHistory.prefix(3).map { record in
            "- \(record.destination) (\(record.purpose.displayName)): 满意度\(record.satisfaction)/5"
        }.joined(separator: "\n")
        
        let prompt = """
        基于用户档案和旅行计划，提供个性化的物品建议：
        
        用户偏好：
        - 装箱风格：\(userProfile.preferences.packingStyle.displayName)
        - 预算水平：\(userProfile.preferences.budgetLevel.displayName)
        - 旅行频率：\(userProfile.preferences.travelFrequency.displayName)
        
        最近旅行记录：
        \(historyInfo)
        
        本次旅行计划：
        - 目的地：\(travelPlan.destination)
        - 天数：\(travelPlan.duration)
        - 季节：\(travelPlan.season)
        - 活动：\(travelPlan.activities.joined(separator: "、"))
        
        请以JSON数组格式返回个性化建议：
        [
            {
                "name": "物品名称",
                "category": "类别",
                "importance": "essential/important/recommended/optional",
                "reason": "个性化推荐理由",
                "quantity": 数量,
                "estimatedWeight": 预估重量,
                "estimatedVolume": 预估体积
            }
        ]
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的个性化旅行顾问，能够根据用户的历史偏好和旅行记录提供精准的个性化建议。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseSuggestedItems(from: content)
    }
    
    // MARK: - 遗漏检查功能
    
    /// 检查遗漏物品
    /// - Parameters:
    ///   - checklist: 当前清单
    ///   - travelPlan: 旅行计划
    /// - Returns: 遗漏物品警告
    func checkMissingItems(
        checklist: [LuggageItem],
        travelPlan: TravelPlan
    ) async throws -> [MissingItemAlert] {
        let currentItems = checklist.map { $0.name }.joined(separator: "、")
        
        let prompt = """
        检查以下旅行清单是否有重要物品遗漏：
        
        旅行信息：
        - 目的地：\(travelPlan.destination)
        - 天数：\(travelPlan.duration)
        - 季节：\(travelPlan.season)
        - 活动：\(travelPlan.activities.joined(separator: "、"))
        
        当前清单：\(currentItems)
        
        请以JSON数组格式返回可能遗漏的重要物品：
        [
            {
                "itemName": "物品名称",
                "category": "类别",
                "importance": "essential/important/recommended/optional",
                "reason": "为什么重要",
                "suggestion": "具体建议"
            }
        ]
        
        只返回真正重要且可能被遗漏的物品。
        """
        
        let messages = [
            ChatMessage.system("你是一个细心的旅行检查专家，能够发现旅行清单中可能遗漏的重要物品。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseMissingItemAlerts(from: content)
    }
    
    // MARK: - 重量预测功能
    
    /// 预测行李重量
    /// - Parameter items: 物品列表
    /// - Returns: 重量预测结果
    func predictWeight(items: [LuggageItem]) async throws -> WeightPrediction {
        let itemsInfo = items.map { item in
            "- \(item.name): \(item.weight)g"
        }.joined(separator: "\n")
        
        let prompt = """
        分析以下物品清单的重量分布和预测：
        
        \(itemsInfo)
        
        请以JSON格式返回分析结果：
        {
            "totalWeight": 总重量,
            "breakdown": [
                {
                    "category": "类别",
                    "weight": 重量,
                    "percentage": 百分比
                }
            ],
            "warnings": ["重量警告"],
            "suggestions": ["减重建议"],
            "confidence": 预测置信度
        }
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的重量分析专家，能够准确分析物品重量分布并提供优化建议。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseWeightPrediction(from: content)
    }
    
    // MARK: - 替代品建议功能
    
    /// 建议替代品
    /// - Parameters:
    ///   - item: 原物品
    ///   - constraints: 约束条件
    /// - Returns: 替代品列表
    func suggestAlternatives(
        for item: LuggageItem,
        constraints: PackingConstraints
    ) async throws -> [ItemInfo] {
        let prompt = """
        为物品"\(item.name)"（重量：\(item.weight)g，体积：\(item.volume)cm³）推荐更轻便的替代品。
        
        约束条件：
        - 最大重量：\(constraints.maxWeight)g
        - 最大体积：\(constraints.maxVolume)cm³
        - 限制条件：\(constraints.restrictions.joined(separator: "、"))
        
        请以JSON数组格式返回替代品建议：
        [
            {
                "name": "替代品名称",
                "category": "类别",
                "weight": 重量,
                "volume": 体积,
                "confidence": 置信度,
                "alternatives": [],
                "source": "AI建议"
            }
        ]
        
        请确保替代品能够满足原物品的基本功能需求。
        """
        
        let messages = [
            ChatMessage.system("你是一个专业的产品替代专家，能够根据重量和体积约束推荐合适的替代品。"),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages)
        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        return try parseItemInfoArray(from: content)
    }
    
    // MARK: - 私有解析方法（使用新的响应模型）
    
    private func parseItemInfo(from content: String, originalName: String) throws -> ItemInfo {
        return try AIResponseParser.parseItemInfo(from: content, originalName: originalName)
    }
    
    private func parsePackingPlan(from content: String, luggageId: UUID) throws -> PackingPlan {
        return try AIResponseParser.parsePackingPlan(from: content, luggageId: luggageId)
    }
    
    private func parseWeightPrediction(from content: String) throws -> WeightPrediction {
        return try AIResponseParser.parseWeightPrediction(from: content)
    }
    
    private func parseMissingItemAlerts(from content: String) throws -> [MissingItemAlert] {
        return try AIResponseParser.parseMissingItemAlerts(from: content)
    }
    
    private func parseSuggestedItems(from content: String) throws -> [SuggestedItem] {
        return try AIResponseParser.parseSuggestedItems(from: content)
    }
    
    private func parseItemInfoArray(from content: String) throws -> [ItemInfo] {
        return try AIResponseParser.parseItemInfoArray(from: content)
    }
    
    // MARK: - 兼容性方法（保持现有功能）
    
    /// 快速生成行李清单建议（保持向后兼容）
    func generateLuggageSuggestion(
        destination: String,
        duration: Int,
        season: String,
        activities: [String]
    ) async throws -> String {
        let suggestion = try await generateTravelChecklist(
            destination: destination,
            duration: duration,
            season: season,
            activities: activities
        )
        
        // 将结构化数据转换为文本格式
        var result = "# \(destination) \(duration)天\(season)旅行建议\n\n"
        
        let groupedItems = Dictionary(grouping: suggestion.suggestedItems) { $0.category }
        
        for category in ItemCategory.allCases {
            if let items = groupedItems[category], !items.isEmpty {
                result += "## \(category.displayName) \(category.icon)\n"
                for item in items.sorted(by: { $0.importance.priority > $1.importance.priority }) {
                    result += "- \(item.name)"
                    if item.quantity > 1 {
                        result += " ×\(item.quantity)"
                    }
                    result += " (\(item.importance.displayName))\n"
                }
                result += "\n"
            }
        }
        
        if !suggestion.tips.isEmpty {
            result += "## 💡 旅行小贴士\n"
            for tip in suggestion.tips {
                result += "- \(tip)\n"
            }
            result += "\n"
        }
        
        if !suggestion.warnings.isEmpty {
            result += "## ⚠️ 注意事项\n"
            for warning in suggestion.warnings {
                result += "- \(warning)\n"
            }
        }
        
        return result
    }
    
    /// 生成行李建议（保持向后兼容）
    func generateLuggageSuggestion(
        prompt: String,
        config: APIServiceConfig? = nil
    ) async throws -> String {
        let systemPrompt = """
        你是一个专业的旅行顾问，请根据用户提供的旅行信息，
        为他们推荐合适的行李物品。请提供详细、实用的建议。
        """
        
        let messages = [
            ChatMessage.system(systemPrompt),
            ChatMessage.user(prompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages, config: config)
        return response.choices.first?.message.content ?? "无法生成建议"
    }
}

