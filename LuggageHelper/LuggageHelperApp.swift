//
//  LuggageHelperApp.swift
//  LuggageHelper
//
//  Created by ahti on 2025/7/17.
//

import SwiftUI

@main
struct LuggageHelperApp: App {
    
    init() {
        // 初始化API服务配置
        setupAPIService()
        // 同步LLM配置
        LLMAPIService.shared.syncConfiguration()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
