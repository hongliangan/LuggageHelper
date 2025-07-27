//
//  ContentView.swift
//  LuggageHelper
//
//  Created by ahti on 2025/7/17.
//

import SwiftUI

/// 应用主界面 - LuggageHelper v2.0
/// 
/// 提供完整的智能行李管理功能入口，包括：
/// - 行李管理：创建和管理多个行李箱
/// - 物品管理：详细的物品信息记录和分类
/// - 出行清单：智能生成和管理旅行清单
/// - 统计分析：全面的使用数据统计
/// - AI功能：集成先进的人工智能增强功能
/// 
/// 架构特点：
/// - 采用 SwiftUI + MVVM 架构模式
/// - 响应式数据绑定和状态管理
/// - 模块化设计，功能独立可扩展
struct ContentView: View {
    @StateObject private var viewModel = LuggageViewModel()
    
    var body: some View {
        TabView {
            // 行李管理
            LuggageListView()
                .tabItem {
                    Image(systemName: "suitcase")
                    Text("行李")
                }
            
            // 物品管理
            ItemListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("物品")
                }
            
            // 出行清单
            TravelChecklistView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("清单")
                }
            
            // 统计概览
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("统计")
                }
            
            // AI功能
            AdvancedFeaturesView()
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("AI功能")
                }
        }
        .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}
