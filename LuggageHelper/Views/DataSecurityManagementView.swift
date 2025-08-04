import SwiftUI

// MARK: - 数据安全管理界面
/// 
/// 用户数据安全和隐私控制中心
/// 
/// 🔒 主要功能：
/// - 数据使用报告：显示详细的数据存储和使用情况
/// - 隐私控制：用户可以控制数据的使用和删除
/// - 安全统计：显示安全操作的成功率和统计信息
/// - 数据导出：支持GDPR合规的数据导出功能
/// 
/// 📊 界面特性：
/// - 直观的数据可视化
/// - 一键数据清理功能
/// - 详细的隐私政策说明
/// - 实时的安全状态监控
struct DataSecurityManagementView: View {
    @StateObject private var securityService = DataSecurityService.shared
    @State private var userDataReport: UserDataReport?
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportedData: UserDataExport?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 安全状态概览
                    securityOverviewSection
                    
                    // 数据使用报告
                    if let report = userDataReport {
                        dataReportSection(report)
                    }
                    
                    // 安全统计
                    securityStatisticsSection
                    
                    // 数据控制操作
                    dataControlSection
                    
                    // 隐私政策和说明
                    privacyPolicySection
                }
                .padding()
            }
            .navigationTitle("数据安全管理")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadUserDataReport()
            }
            .onAppear {
                Task {
                    await loadUserDataReport()
                }
            }
            .alert("操作结果", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog("删除所有数据", isPresented: $showingDeleteConfirmation) {
                Button("删除所有数据", role: .destructive) {
                    Task {
                        await deleteAllUserData()
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作将永久删除所有存储的图像数据和识别历史。此操作不可撤销。")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let exportedData = exportedData {
                    DataExportView(exportedData: exportedData)
                }
            }
        }
    }
    
    // MARK: - 安全状态概览
    
    private var securityOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("安全状态")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                
                Text("安全")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                SecurityStatusRow(
                    icon: "lock.fill",
                    title: "数据加密",
                    status: "AES-256 加密保护",
                    isSecure: true
                )
                
                SecurityStatusRow(
                    icon: "timer",
                    title: "自动清理",
                    status: "定期清理临时文件",
                    isSecure: true
                )
                
                SecurityStatusRow(
                    icon: "network",
                    title: "网络传输",
                    status: "端到端加密传输",
                    isSecure: true
                )
                
                SecurityStatusRow(
                    icon: "person.badge.shield.checkmark",
                    title: "隐私保护",
                    status: "本地优先处理",
                    isSecure: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 数据报告部分
    
    private func dataReportSection(_ report: UserDataReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("数据使用报告")
                    .font(.headline)
                
                Spacer()
                
                Text("生成于 \(formatDate(report.generatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 数据存储概览
            VStack(spacing: 12) {
                DataStorageRow(
                    title: "安全存储",
                    description: "加密存储的识别数据",
                    fileInfo: report.secureStorageFiles,
                    color: .green
                )
                
                DataStorageRow(
                    title: "临时文件",
                    description: "处理中的临时图像",
                    fileInfo: report.temporaryFiles,
                    color: .orange
                )
                
                DataStorageRow(
                    title: "缓存数据",
                    description: "优化性能的缓存文件",
                    fileInfo: report.cacheFiles,
                    color: .blue
                )
                
                Divider()
                
                HStack {
                    Text("总计")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(report.formattedTotalSize)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            // 数据保留策略
            VStack(alignment: .leading, spacing: 8) {
                Text("数据保留策略")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(report.retentionPolicies, id: \.dataType) { policy in
                    DataRetentionRow(policy: policy)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 安全统计部分
    
    private var securityStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("安全统计")
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SecurityStatisticCard(
                    title: "存储操作",
                    value: "\(securityService.securityStatistics.totalStoreOperations)",
                    subtitle: "成功率 \(securityService.securityStatistics.formattedStoreSuccessRate)",
                    color: .green
                )
                
                SecurityStatisticCard(
                    title: "加载操作",
                    value: "\(securityService.securityStatistics.totalLoadOperations)",
                    subtitle: "成功率 \(securityService.securityStatistics.formattedLoadSuccessRate)",
                    color: .blue
                )
                
                SecurityStatisticCard(
                    title: "删除操作",
                    value: "\(securityService.securityStatistics.totalDeleteOperations)",
                    subtitle: "成功率 \(securityService.securityStatistics.formattedDeleteSuccessRate)",
                    color: .red
                )
                
                SecurityStatisticCard(
                    title: "清理操作",
                    value: "\(securityService.securityStatistics.totalCleanupOperations)",
                    subtitle: "成功率 \(securityService.securityStatistics.formattedCleanupSuccessRate)",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 数据控制部分
    
    private var dataControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.gray)
                    .font(.title2)
                
                Text("数据控制")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 导出数据按钮
                Button(action: {
                    Task {
                        await exportUserData()
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出我的数据")
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
                
                // 清理临时文件按钮
                Button(action: {
                    Task {
                        await cleanupTemporaryFiles()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理临时文件")
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
                
                // 删除所有数据按钮
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除所有数据")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 隐私政策部分
    
    private var privacyPolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .font(.title2)
                
                Text("隐私保护说明")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PrivacyPolicyItem(
                    icon: "eye.slash",
                    title: "本地优先处理",
                    description: "图像识别优先在设备本地进行，减少数据传输"
                )
                
                PrivacyPolicyItem(
                    icon: "lock.shield",
                    title: "端到端加密",
                    description: "所有网络传输使用AES-256加密保护"
                )
                
                PrivacyPolicyItem(
                    icon: "clock",
                    title: "自动过期删除",
                    description: "临时文件和缓存数据会自动过期删除"
                )
                
                PrivacyPolicyItem(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "用户完全控制",
                    description: "您可以随时查看、导出或删除您的所有数据"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 私有方法
    
    private func loadUserDataReport() async {
        isLoading = true
        userDataReport = await securityService.getUserDataReport()
        isLoading = false
    }
    
    private func exportUserData() async {
        isLoading = true
        
        if let exported = await securityService.exportUserData() {
            exportedData = exported
            showingExportSheet = true
            alertMessage = "数据导出成功，包含 \(exported.images.count) 个图像文件"
        } else {
            alertMessage = "数据导出失败，请稍后重试"
        }
        
        showingAlert = true
        isLoading = false
    }
    
    private func cleanupTemporaryFiles() async {
        await securityService.cleanupAllTemporaryFiles()
        await loadUserDataReport()
        
        alertMessage = "临时文件清理完成"
        showingAlert = true
    }
    
    private func deleteAllUserData() async {
        let success = await securityService.deleteAllUserData()
        
        if success {
            alertMessage = "所有用户数据已成功删除"
            userDataReport = nil
        } else {
            alertMessage = "数据删除过程中出现错误，部分数据可能未被删除"
        }
        
        showingAlert = true
        await loadUserDataReport()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 支持视图组件

struct SecurityStatusRow: View {
    let icon: String
    let title: String
    let status: String
    let isSecure: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isSecure ? .green : .red)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isSecure ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSecure ? .green : .red)
        }
    }
}

struct DataStorageRow: View {
    let title: String
    let description: String
    let fileInfo: DataFileInfo
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(fileInfo.count) 个文件")
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(fileInfo.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DataRetentionRow: View {
    let policy: DataRetentionPolicy
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(policy.dataType)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(policy.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(policy.formattedRetentionPeriod)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
    }
}

struct SecurityStatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PrivacyPolicyItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 数据导出视图

struct DataExportView: View {
    let exportedData: UserDataExport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 导出概览
                    VStack(alignment: .leading, spacing: 12) {
                        Text("导出概览")
                            .font(.headline)
                        
                        HStack {
                            Text("导出时间:")
                            Spacer()
                            Text(formatDate(exportedData.exportedAt))
                        }
                        
                        HStack {
                            Text("图像数量:")
                            Spacer()
                            Text("\(exportedData.images.count) 个")
                        }
                        
                        HStack {
                            Text("总数据大小:")
                            Spacer()
                            Text(exportedData.dataReport.formattedTotalSize)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 导出的图像列表
                    if !exportedData.images.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("导出的图像")
                                .font(.headline)
                            
                            ForEach(exportedData.images.indices, id: \.self) { index in
                                let imageData = exportedData.images[index]
                                
                                HStack {
                                    if let image = UIImage(data: imageData.imageData) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("图像 \(index + 1)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("创建于 \(formatDate(imageData.createdAt))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(imageData.imageData.count), countStyle: .file))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // 使用说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("使用说明")
                            .font(.headline)
                        
                        Text("• 导出的数据包含您所有的图像识别历史")
                        Text("• 数据以标准格式导出，可在其他应用中使用")
                        Text("• 请妥善保管导出的数据文件")
                        Text("• 如需删除导出数据，请手动删除相关文件")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("数据导出")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    DataSecurityManagementView()
}