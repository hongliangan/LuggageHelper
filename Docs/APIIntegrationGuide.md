# 硅基流动API集成使用指南

## 快速开始

### 1. 获取API密钥
- 访问 [硅基流动官网](https://siliconflow.cn)
- 注册账号并创建API密钥
- 密钥格式：以 `sf-` 开头

### 2. 配置API服务

#### 方法一：通过配置界面
1. 打开应用设置
2. 进入 "硅基流动API配置"
3. 填写基础URL和API密钥
4. 选择模型和参数
5. 点击 "测试连接" 验证配置

#### 方法二：代码配置
```swift
let config = APIServiceConfig(
    baseURL: "https://api.siliconflow.cn/v1",
    apiKey: "your-api-key-here",
    model: "deepseek-ai/DeepSeek-V3"
)
APIConfigurationManager.shared.saveConfiguration(config)
```

### 3. 生成行李建议

```swift
Task {
    do {
        let suggestion = try await SiliconFlowAPIService.shared.generateLuggageSuggestion(
            destination: "东京",
            duration: 7,
            season: "春季",
            activities: ["观光", "购物", "美食"]
        )
        print(suggestion)
    } catch {
        print("错误：\(error)")
    }
}
```

## 支持的模型

| 模型名称 | 描述 | 价格 |
|---------|------|------|
| deepseek-ai/DeepSeek-R1 | 最新推理模型，数学代码能力强 | ¥0.004/1K tokens |
| deepseek-ai/DeepSeek-V3 | 通用大模型，性价比高 | ¥0.001/1K tokens |
| Qwen/Qwen2.5-72B-Instruct | 中文能力强 | ¥0.002/1K tokens |

## 错误处理

### 常见错误及解决方案

1. **配置错误**
   - 症状：提示 "API配置无效"
   - 解决：检查API密钥和基础URL

2. **网络错误**
   - 症状：连接超时或网络不可用
   - 解决：检查网络连接

3. **API限制**
   - 症状：返回 "Rate limit exceeded"
   - 解决：降低请求频率或升级套餐

4. **模型错误**
   - 症状：提示 "Model not found"
   - 解决：检查模型名称是否正确

## 高级配置

### 自定义参数
- **maxTokens**: 控制响应长度（100-4000）
- **temperature**: 控制创造性（0.0-2.0）
- **topP**: 控制多样性（0.0-1.0）

### 环境变量配置
```swift
// 在Info.plist中添加
// SILICONFLOW_API_KEY: your-api-key
// SILICONFLOW_BASE_URL: https://api.siliconflow.cn/v1
```

## 测试

运行测试用例：
```bash
xcodebuild test -scheme LuggageHelper -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 故障排除

### 调试模式
```swift
// 启用调试日志
SiliconFlowAPIService.shared.enableDebugMode = true
```

### 联系支持
- 硅基流动技术支持：support@siliconflow.cn
- 项目问题：提交GitHub Issue