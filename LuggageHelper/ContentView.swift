//
//  ContentView.swift
//  LuggageHelper
//
//  Created by ahti on 2025/7/17.
//

import SwiftUI

/// 应用主界面
/// 提供行李管理、物品管理和出行清单的入口
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
            
            // 高级功能
            AdvancedFeaturesView()
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("AI功能")
                }
            
            // 设置
            NavigationView {
                APIConfigurationView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("设置")
            }
        }
        .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}
