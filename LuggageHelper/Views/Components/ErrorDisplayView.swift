import SwiftUI

// MARK: - 错误显示组件
struct ErrorDisplayView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 错误标题和图标
            HStack {
                Image(systemName: error.type.icon)
                    .foregroundColor(error.type.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("关闭") {
                    onDismiss()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // 错误消息
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // 建议操作
            if !error.suggestedActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("建议操作：")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(error.suggestedActions.enumerated()), id: \.offset) { index, action in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(action)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // 操作按钮
            HStack {
                if error.canRetry, let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(error.retryDelay != nil)
                }
                
                Spacer()
                
                Button("详细信息") {
                    isExpanded.toggle()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // 详细信息（可展开）
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    DetailRow(title: "错误类型", value: error.type.rawValue)
                    DetailRow(title: "发生时间", value: formatDate(error.timestamp))
                    
                    if !error.context.isEmpty {
                        DetailRow(title: "上下文", value: error.context)
                    }
                    
                    if let originalError = error.originalError {
                        DetailRow(title: "原始错误", value: originalError.localizedDescription)
                    }
                }
                .font(.caption)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - 详细信息行组件
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("\(title):")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - 错误横幅组件
struct ErrorBannerView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack {
                Image(systemName: error.type.icon)
                    .foregroundColor(error.type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if error.canRetry, let onRetry = onRetry {
                    Button("重试") {
                        onRetry()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(error.type.color.opacity(0.1))
            .cornerRadius(8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - 错误卡片组件
struct ErrorCardView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: error.type.icon)
                    .foregroundColor(error.type.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.headline)
                    
                    Text(error.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if error.canRetry, let onRetry = onRetry {
                HStack {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    if let retryDelay = error.retryDelay {
                        Text("请等待 \(Int(retryDelay)) 秒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 错误列表组件
struct ErrorHistoryView: View {
    @StateObject private var errorHandler = ErrorHandlingService.shared
    @State private var selectedError: AppError?
    
    var body: some View {
        NavigationView {
            List {
                if errorHandler.errorHistory.isEmpty {
                    ContentUnavailableView(
                        "暂无错误记录",
                        systemImage: "checkmark.circle",
                        description: Text("应用运行正常，没有错误记录")
                    )
                } else {
                    ForEach(errorHandler.errorHistory) { record in
                        ErrorHistoryRowView(record: record) {
                            selectedError = record.error
                        }
                    }
                }
            }
            .navigationTitle("错误历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        errorHandler.clearErrorHistory()
                    }
                    .disabled(errorHandler.errorHistory.isEmpty)
                }
            }
        }
        .sheet(item: $selectedError) { error in
            ErrorDetailView(error: error)
        }
    }
}

// MARK: - 错误历史行组件
struct ErrorHistoryRowView: View {
    let record: ErrorRecord
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: record.error.type.icon)
                    .foregroundColor(record.error.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.error.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(record.error.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(formatTimestamp(record.timestamp))
                        .font(.caption2)
                        .foregroundColor(Color.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 错误详情视图
struct ErrorDetailView: View {
    let error: AppError
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 错误概览
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: error.type.icon)
                                .foregroundColor(error.type.color)
                                .font(.title)
                            
                            VStack(alignment: .leading) {
                                Text(error.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(error.type.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Text(error.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 详细信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("详细信息")
                            .font(.headline)
                        
                        DetailRow(title: "错误类型", value: error.type.rawValue)
                        DetailRow(title: "发生时间", value: formatFullDate(error.timestamp))
                        DetailRow(title: "可重试", value: error.canRetry ? "是" : "否")
                        
                        if !error.context.isEmpty {
                            DetailRow(title: "上下文", value: error.context)
                        }
                        
                        if let retryDelay = error.retryDelay {
                            DetailRow(title: "重试延迟", value: "\(Int(retryDelay)) 秒")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 建议操作
                    if !error.suggestedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("建议操作")
                                .font(.headline)
                            
                            ForEach(Array(error.suggestedActions.enumerated()), id: \.offset) { index, action in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .frame(width: 20, alignment: .leading)
                                    
                                    Text(action)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("错误详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    let sampleError = AppError(
        type: .network,
        title: "网络连接失败",
        message: "无法连接到AI服务，请检查网络连接后重试。",
        context: "物品识别",
        canRetry: true,
        suggestedActions: [
            "检查网络连接",
            "稍后重试",
            "切换到其他网络"
        ]
    )
    
    return ErrorDisplayView(
        error: sampleError,
        onRetry: { print("重试") },
        onDismiss: { print("关闭") }
    )
}