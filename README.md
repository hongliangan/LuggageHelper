# LuggageHelper 项目说明

## 项目简介
LuggageHelper 是一款面向 iPhone 用户的行李管理 App，帮助用户高效管理箱包、物品及出行清单，避免行李超重和物品遗漏。

## 目录结构

```
LuggageHelper/
├── PRD.md                  # 需求规格说明书
├── README.md               # 项目说明（本文件）
├── LuggageHelper/       # 主App工程目录
│   ├── ContentView.swift
│   ├── LuggageHelperApp.swift
│   ├── Assets.xcassets
│   ├── Info.plist
│   ├── Models/             # 数据模型
│   ├── Views/              # SwiftUI界面
│   ├── ViewModels/         # 业务逻辑与状态
│   ├── Services/           # 网络/数据/第三方服务
│   ├── Utils/              # 工具类
│   └── Resources/          # 本地化、图片等资源
├── Tests/                  # 单元测试
│   ├── ModelsTests/
│   ├── ViewModelsTests/
│   └── ServicesTests/
└── Docs/                   # 设计文档、接口文档等
```

## 架构模式
- 采用 MVVM（Model-View-ViewModel）+ SwiftUI 架构
- 业务逻辑与界面分离，便于测试和维护
- Service 层负责数据持久化、网络、第三方集成

## 开发规范
- 代码注释用中文，解释每个类、方法、关键逻辑
- 每个目录下建议有 README.md 说明用途
- 统一使用 Swift 语言和 SwiftUI 框架

## 测试
- 每个 Model、ViewModel、Service 都要有对应的单元测试
- 测试代码与业务代码分离，便于持续集成

## 贡献与协作
- 详细开发流程、分支管理、代码规范见 Docs/ 目录

---
如有问题请查阅 PRD.md 或联系项目负责人。 

---

