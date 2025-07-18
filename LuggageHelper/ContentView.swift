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
            LuggageListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "suitcase")
                    Text("行李")
                }
            
            // 物品管理
            ItemListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("物品")
                }
            
            // 出行清单
            TravelChecklistView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "checklist")
                    Text("清单")
                }
        }
    }
}

#Preview {
    ContentView()
}
