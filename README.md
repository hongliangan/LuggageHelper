# LuggageHelper - 智能行李管理助手

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

一个功能强大的 iOS 行李管理应用，集成了先进的 AI 功能，帮助用户智能管理行李、优化装箱和规划旅行。

## ✨ 主要功能

### 📱 核心功能
- **行李管理**: 创建和管理多个行李箱，支持重量和容量跟踪
- **物品管理**: 详细的物品信息记录，支持分类和标签
- **出行清单**: 智能生成和管理旅行物品清单
- **数据统计**: 全面的使用统计和分析报告

### 🤖 AI 增强功能
- **智能物品识别**: 通过名称和型号自动获取物品重量、体积信息
- **照片识别**: 拍照自动识别物品并填充详细信息
- **智能分类**: 自动为物品分配合适的类别和标签
- **旅行建议**: 基于目的地、季节、活动类型生成个性化物品清单
- **装箱优化**: AI 驱动的装箱方案，最大化空间利用率
- **重量预测**: 实时预测行李重量，避免超重
- **物品替代**: 智能推荐更轻便的替代品
- **遗漏提醒**: 基于旅行计划主动提醒可能遗漏的物品
- **航司政策**: 自动查询和解读航空公司行李政策

### 🔧 系统功能
- **智能缓存**: 高效的 AI 响应缓存，提升使用体验
- **性能监控**: 实时监控应用性能和资源使用
- **错误处理**: 完善的错误处理和用户友好提示
- **网络监控**: 智能网络状态检测和离线模式支持
- **撤销重做**: 完整的操作历史和撤销重做功能

## 🚀 快速开始

### 环境要求
- iOS 17.0 或更高版本
- Xcode 15.0 或更高版本
- Swift 5.9 或更高版本

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/your-username/LuggageHelper.git
   cd LuggageHelper
   ```

2. **打开项目**
   ```bash
   open LuggageHelper.xcodeproj
   ```

3. **配置 AI 服务**
   - 在应用中进入 "AI功能" → "设置"
   - 配置硅基流动 API 密钥和基础 URL
   - 测试连接确保配置正确

4. **构建和运行**
   - 选择目标设备或模拟器
   - 按 `Cmd + R` 运行应用

## 📖 使用指南

### AI 功能配置

1. **获取 API 密钥**
   - 访问 [硅基流动官网](https://siliconflow.cn)
   - 注册账号并获取 API 密钥

2. **配置应用**
   - 打开应用，进入 "AI功能" 标签页
   - 点击右上角 "设置" 按钮
   - 输入 API 密钥和基础 URL
   - 点击 "测试连接" 验证配置

### 主要功能使用

#### 智能物品识别
1. 在物品管理页面点击 "+" 添加物品
2. 输入物品名称和型号（可选）
3. 点击 "AI 识别" 按钮
4. 系统自动填充重量、体积等信息
5. 确认信息后保存

#### 照片识别
1. 添加物品时点击相机图标
2. 拍摄物品照片
3. AI 自动识别物品信息
4. 确认或修改识别结果
5. 保存物品信息

#### 智能旅行规划
1. 进入 "AI功能" → "智能旅行规划"
2. 输入目的地、旅行时长、季节
3. 选择活动类型
4. 生成个性化物品建议
5. 选择需要的物品添加到清单

#### 装箱优化
1. 选择要装箱的物品和目标行李箱
2. 进入 "AI功能" → "装箱优化"
3. 查看 AI 生成的装箱方案
4. 按照建议进行装箱

## 🏗️ 项目架构

### 核心架构
```
LuggageHelper/
├── Models/              # 数据模型
├── Views/               # 用户界面
├── ViewModels/          # 视图模型
├── Services/            # 业务服务
├── Utils/               # 工具类
└── Documentation/       # 文档
```

### AI 服务架构
- **LLMAPIService**: 核心 AI 服务，处理所有 AI 请求
- **AICacheManager**: 智能缓存管理，提升响应速度
- **AIRequestQueue**: 请求队列管理，控制并发和优先级
- **PerformanceMonitor**: 性能监控，优化用户体验

### 用户体验系统
- **ErrorHandlingService**: 统一错误处理
- **NetworkMonitor**: 网络状态监控
- **LoadingStateManager**: 加载状态管理
- **UndoRedoManager**: 撤销重做功能

## 🧪 测试

项目包含完整的测试套件：

```bash
# 运行单元测试
xcodebuild test -project LuggageHelper.xcodeproj -scheme LuggageHelper -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行 UI 测试
xcodebuild test -project LuggageHelper.xcodeproj -scheme LuggageHelper -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:LuggageHelperUITests

# 运行性能测试
xcodebuild test -project LuggageHelper.xcodeproj -scheme LuggageHelper -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PerformanceTests
```

### 测试覆盖
- **单元测试**: >90% 代码覆盖率
- **集成测试**: 完整的功能流程测试
- **UI 测试**: 主要用户界面交互测试
- **性能测试**: AI 服务和缓存性能测试

## 📊 性能优化

### 缓存策略
- **物品识别**: 24小时缓存，基于名称和型号
- **照片识别**: 7天缓存，基于图片哈希
- **旅行建议**: 24小时缓存，基于参数组合
- **装箱优化**: 12小时缓存，平衡实时性
- **航司政策**: 7天缓存，政策变化较慢

### 性能指标
- **响应时间**: 缓存命中 <100ms，首次请求 <5s
- **内存使用**: <200MB
- **缓存命中率**: >30%
- **API 调用优化**: 减少重复调用 60-80%

## 🔒 隐私和安全

- **本地数据**: 所有用户数据存储在本地设备
- **API 安全**: 使用 HTTPS 加密通信
- **密钥保护**: API 密钥使用 Keychain 安全存储
- **数据加密**: 敏感数据本地加密存储
- **隐私保护**: 不收集或上传用户个人信息

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 代码规范
- 遵循 Swift 官方代码风格
- 添加适当的注释和文档
- 确保所有测试通过
- 更新相关文档

## 📝 更新日志

### v2.0.0 (2025-01-27)
- ✨ 全新 AI 增强功能
- 🤖 智能物品识别和照片识别
- 🧳 AI 驱动的装箱优化
- 🌍 个性化旅行建议
- ⚡ 智能缓存和性能优化
- 🔧 完善的用户体验系统
- 📱 简化的界面设计

### v1.0.0 (2025-07-17)
- 🎉 初始版本发布
- 📦 基础行李管理功能
- 📋 物品和清单管理
- 📊 统计和分析功能

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 支持

如有问题或建议，请：
- 创建 [Issue](https://github.com/your-username/LuggageHelper/issues)
- 发送邮件至 support@luggagehelper.com
- 查看 [Wiki](https://github.com/your-username/LuggageHelper/wiki) 获取更多信息

## 🙏 致谢

- [硅基流动](https://siliconflow.cn) - 提供强大的 AI 服务支持
- Swift 社区 - 优秀的开发工具和资源
- 所有贡献者和用户的支持

---

**LuggageHelper** - 让旅行更智能，让装箱更简单！ 🧳✨