import SwiftUI

/// 替换设置视图
struct ReplacementSettingsView: View {
    @StateObject private var replacementService = ItemReplacementService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: ItemReplacementService.AutoReplacementSettings
    
    init() {
        _settings = State(initialValue: ItemReplacementService.shared.autoReplacementSettings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 基本设置
                Section("基本设置") {
                    Toggle("启用自动替换", isOn: $settings.isEnabled)
                        .onChange(of: settings.isEnabled) { _ in
                            saveSettings()
                        }
                    
                    Toggle("需要确认", isOn: $settings.requireConfirmation)
                        .onChange(of: settings.requireConfirmation) { _ in
                            saveSettings()
                        }
                    
                    Toggle("启用通知", isOn: $settings.notificationEnabled)
                        .onChange(of: settings.notificationEnabled) { _ in
                            saveSettings()
                        }
                }
                
                // 自动应用设置
                Section("自动应用") {
                    Toggle("高优先级自动应用", isOn: $settings.autoApplyHighPriority)
                        .disabled(!settings.isEnabled)
                        .onChange(of: settings.autoApplyHighPriority) { _ in
                            saveSettings()
                        }
                    
                    Toggle("中优先级自动应用", isOn: $settings.autoApplyMediumPriority)
                        .disabled(!settings.isEnabled)
                        .onChange(of: settings.autoApplyMediumPriority) { _ in
                            saveSettings()
                        }
                    
                    Text("低优先级建议始终需要手动确认")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 约束设置
                Section("约束条件") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最大重量增加：\(formatWeight(settings.maxWeightIncrease))")
                        
                        Slider(value: $settings.maxWeightIncrease, in: 0...1000, step: 50) {
                            Text("最大重量增加")
                        }
                        .onChange(of: settings.maxWeightIncrease) { _ in
                            saveSettings()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最大体积增加：\(formatVolume(settings.maxVolumeIncrease))")
                        
                        Slider(value: $settings.maxVolumeIncrease, in: 0...2000, step: 100) {
                            Text("最大体积增加")
                        }
                        .onChange(of: settings.maxVolumeIncrease) { _ in
                            saveSettings()
                        }
                    }
                }
                
                // 类别设置
                Section("启用的类别") {
                    ForEach(ItemCategory.allCases, id: \.self) { category in
                        HStack {
                            Text(category.icon)
                                .font(.title2)
                            
                            Text(category.displayName)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { settings.enabledCategories.contains(category) },
                                set: { isEnabled in
                                    if isEnabled {
                                        settings.enabledCategories.insert(category)
                                    } else {
                                        settings.enabledCategories.remove(category)
                                    }
                                    saveSettings()
                                }
                            ))
                        }
                    }
                }
                
                // 高级设置
                Section("高级设置") {
                    Button("重置所有设置") {
                        resetSettings()
                    }
                    .foregroundColor(.red)
                    
                    Button("清理所有建议") {
                        clearAllSuggestions()
                    }
                    .foregroundColor(.orange)
                    
                    Button("清理历史记录") {
                        clearHistory()
                    }
                    .foregroundColor(.orange)
                }
                
                // 统计信息
                Section("统计信息") {
                    let stats = replacementService.getReplacementStatistics()
                    
                    HStack {
                        Text("总替换次数")
                        Spacer()
                        Text("\(stats.totalReplacements)")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("待处理建议")
                        Spacer()
                        Text("\(replacementService.pendingReplacements.count)")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("总重量节省")
                        Spacer()
                        Text(formatWeight(stats.totalWeightSavings))
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("总体积节省")
                        Spacer()
                        Text(formatVolume(stats.totalVolumeSavings))
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("替换设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        // 恢复原始设置
                        settings = replacementService.autoReplacementSettings
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 方法
    
    private func saveSettings() {
        replacementService.autoReplacementSettings = settings
        
        // 这里可以添加持久化逻辑
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: "AutoReplacementSettings")
    }
    
    private func resetSettings() {
        settings = ItemReplacementService.AutoReplacementSettings()
        saveSettings()
    }
    
    private func clearAllSuggestions() {
        replacementService.pendingReplacements.removeAll()
    }
    
    private func clearHistory() {
        replacementService.replacementHistory.removeAll()
    }
    
    // MARK: - 格式化方法
    
    private func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1fkg", grams / 1000.0)
        } else {
            return String(format: "%.0fg", grams)
        }
    }
    
    private func formatVolume(_ cm3: Double) -> String {
        if cm3 >= 1000 {
            return String(format: "%.1fL", cm3 / 1000.0)
        } else {
            return String(format: "%.0fcm³", cm3)
        }
    }
}

// MARK: - 预览

struct ReplacementSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ReplacementSettingsView()
    }
}