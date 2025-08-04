import SwiftUI

/// 离线模型管理视图
/// 
/// 提供离线识别模型的下载、管理和删除功能
struct OfflineModelManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var offlineService = OfflineRecognitionService.shared
    
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: OfflineModel?
    @State private var showingClearAllAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // 概览信息
                overviewSection
                
                // 模型列表
                modelsSection
                
                // 管理操作
                managementSection
            }
            .navigationTitle("离线模型管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        // 刷新模型列表
                        offlineService.objectWillChange.send()
                    }
                }
            }
            .alert("删除模型", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let model = modelToDelete {
                        deleteModel(model)
                    }
                }
            } message: {
                if let model = modelToDelete {
                    Text("确定要删除 \(model.name) 模型吗？删除后需要重新下载才能使用离线识别功能。")
                }
            }
            .alert("清理所有模型", isPresented: $showingClearAllAlert) {
                Button("取消", role: .cancel) { }
                Button("清理", role: .destructive) {
                    clearAllModels()
                }
            } message: {
                Text("确定要清理所有离线模型吗？这将释放存储空间，但需要重新下载才能使用离线识别功能。")
            }
        }
    }
    
    // MARK: - View Sections
    
    private var overviewSection: some View {
        Section("概览") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("可用模型")
                    Spacer()
                    Text("\(offlineService.availableModels.filter { $0.isAvailable }.count) / \(offlineService.availableModels.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.green)
                    Text("存储占用")
                    Spacer()
                    Text(formatBytes(offlineService.getTotalModelSize()))
                        .foregroundColor(.secondary)
                }
                
                if offlineService.isDownloadingModel {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在下载模型...")
                        Spacer()
                        Text("\(Int(offlineService.downloadProgress * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var modelsSection: some View {
        Section("模型列表") {
            ForEach(offlineService.availableModels) { model in
                ModelRowView(
                    model: model,
                    onDownload: {
                        downloadModel(model)
                    },
                    onDelete: {
                        modelToDelete = model
                        showingDeleteAlert = true
                    }
                )
            }
        }
    }
    
    private var managementSection: some View {
        Section("管理操作") {
            Button(action: {
                showingClearAllAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("清理所有模型")
                        .foregroundColor(.red)
                }
            }
            .disabled(offlineService.getTotalModelSize() == 0)
            
            Button(action: {
                downloadAllModels()
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                    Text("下载所有模型")
                        .foregroundColor(.blue)
                }
            }
            .disabled(offlineService.isDownloadingModel || allModelsDownloaded())
        }
    }
    
    // MARK: - Helper Methods
    
    private func downloadModel(_ model: OfflineModel) {
        Task {
            do {
                try await offlineService.downloadModel(for: model.category)
            } catch {
                // 错误处理已在服务中完成
            }
        }
    }
    
    private func deleteModel(_ model: OfflineModel) {
        do {
            try offlineService.deleteModel(for: model.category)
        } catch {
            // 可以添加错误提示
        }
    }
    
    private func clearAllModels() {
        do {
            try offlineService.clearAllModels()
        } catch {
            // 可以添加错误提示
        }
    }
    
    private func downloadAllModels() {
        Task {
            for model in offlineService.availableModels where !model.isAvailable {
                do {
                    try await offlineService.downloadModel(for: model.category)
                } catch {
                    // 继续下载其他模型
                    continue
                }
            }
        }
    }
    
    private func allModelsDownloaded() -> Bool {
        return offlineService.availableModels.allSatisfy { $0.isAvailable }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Model Row View

private struct ModelRowView: View {
    let model: OfflineModel
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.category.icon)
                            .font(.title2)
                        Text(model.category.displayName)
                            .font(.headline)
                        Spacer()
                        statusBadge
                    }
                    
                    HStack {
                        Text("版本: \(model.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("准确率: \(model.formattedAccuracy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if model.isAvailable {
                        Text("大小: \(model.formattedFileSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("预计大小: \(formatExpectedSize(model))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                if model.isAvailable {
                    Button("删除", action: onDelete)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                } else {
                    Button("下载", action: onDownload)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusBadge: some View {
        Group {
            if model.isAvailable {
                Text("已安装")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            } else {
                Text("未安装")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
            }
        }
    }
    
    private func formatExpectedSize(_ model: OfflineModel) -> String {
        // 这里可以根据模型配置返回预期大小
        // 暂时使用固定值
        let expectedSizes: [ItemCategory: Int64] = [
            .clothing: 25 * 1024 * 1024,
            .electronics: 30 * 1024 * 1024,
            .toiletries: 20 * 1024 * 1024,
            .accessories: 22 * 1024 * 1024,
            .shoes: 18 * 1024 * 1024
        ]
        
        let size = expectedSizes[model.category] ?? 25 * 1024 * 1024
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Preview

#Preview {
    OfflineModelManagementView()
}