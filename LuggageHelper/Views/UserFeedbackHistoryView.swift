//
//  UserFeedbackHistoryView.swift
//  LuggageHelper
//
//  Created by Kiro on 2025/7/28.
//

import SwiftUI

/// 用户反馈历史界面
struct UserFeedbackHistoryView: View {
    
    // MARK: - Properties
    
    @ObservedObject var feedbackManager: UserFeedbackManager
    @State private var showingClearAlert = false
    @State private var selectedFeedback: UserFeedback?
    @State private var showingFeedbackDetail = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                if feedbackManager.feedbackHistory.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // 统计信息
                        statisticsHeader
                        
                        // 反馈列表
                        feedbackList
                    }
                }
            }
            .navigationTitle("反馈历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("清除历史", role: .destructive) {
                            showingClearAlert = true
                        }
                        
                        Button("导出数据") {
                            exportFeedbackData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(feedbackManager.feedbackHistory.isEmpty)
                }
            }
            .alert("清除反馈历史", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    feedbackManager.clearFeedbackHistory()
                }
            } message: {
                Text("此操作将清除所有反馈历史和学习数据，无法撤销。")
            }
            .sheet(item: $selectedFeedback) { feedback in
                FeedbackDetailView(feedback: feedback)
            }
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无反馈记录")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("当您对识别结果进行反馈时，记录将显示在这里")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var statisticsHeader: some View {
        let stats = feedbackManager.getFeedbackStatistics()
        
        return VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatisticCard(
                    title: "总反馈",
                    value: "\(stats.totalFeedbacks)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                
                StatisticCard(
                    title: "准确率",
                    value: "\(Int(stats.accuracyRate * 100))%",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                StatisticCard(
                    title: "平均评分",
                    value: String(format: "%.1f", stats.averageRating),
                    icon: "star.fill",
                    color: .yellow
                )
            }
            .padding(.horizontal)
            
            Divider()
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    private var feedbackList: some View {
        List {
            ForEach(groupedFeedbacks.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(formatSectionDate(date))) {
                    ForEach(groupedFeedbacks[date] ?? []) { feedback in
                        FeedbackRowView(feedback: feedback) {
                            selectedFeedback = feedback
                            showingFeedbackDetail = true
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var groupedFeedbacks: [String: [UserFeedback]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return Dictionary(grouping: feedbackManager.feedbackHistory.sorted { $0.timestamp > $1.timestamp }) { feedback in
            dateFormatter.string(from: feedback.timestamp)
        }
    }
    
    // MARK: - Methods
    
    private func formatSectionDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M月d日"
        
        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else {
            return displayFormatter.string(from: date)
        }
    }
    
    private func exportFeedbackData() {
        // 实现数据导出功能
        print("导出反馈数据功能待实现")
    }
}

// MARK: - Supporting Views

/// 统计卡片
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

/// 反馈行视图
struct FeedbackRowView: View {
    let feedback: UserFeedback
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 状态图标
                Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(feedback.isCorrect ? .green : .red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 修正信息或原始信息
                    if let correctedName = feedback.correctedName {
                        Text("修正为: \(correctedName)")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } else {
                        Text("确认正确")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    // 类别信息
                    if let correctedCategory = feedback.correctedCategory {
                        Text("类别: \(correctedCategory.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 时间
                    Text(formatTime(feedback.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 评分
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= feedback.rating ? "star.fill" : "star")
                            .foregroundColor(star <= feedback.rating ? .yellow : .gray)
                            .font(.caption)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 反馈详情视图
struct FeedbackDetailView: View {
    let feedback: UserFeedback
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 基本信息
                    basicInfoSection
                    
                    // 修正信息
                    if !feedback.isCorrect {
                        correctionInfoSection
                    }
                    
                    // 评分和评论
                    ratingAndCommentsSection
                }
                .padding()
            }
            .navigationTitle("反馈详情")
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
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
            
            InfoRow(title: "反馈时间", value: formatDateTime(feedback.timestamp))
            InfoRow(title: "识别结果", value: feedback.isCorrect ? "正确" : "不正确")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var correctionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("修正信息")
                .font(.headline)
                .foregroundColor(.orange)
            
            if let correctedName = feedback.correctedName {
                InfoRow(title: "修正名称", value: correctedName)
            }
            
            if let correctedCategory = feedback.correctedCategory {
                InfoRow(title: "修正类别", value: correctedCategory.displayName)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var ratingAndCommentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("评价")
                .font(.headline)
            
            HStack {
                Text("满意度:")
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= feedback.rating ? "star.fill" : "star")
                            .foregroundColor(star <= feedback.rating ? .yellow : .gray)
                    }
                }
                
                Spacer()
            }
            
            if let comments = feedback.comments, !comments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("评论:")
                        .foregroundColor(.secondary)
                    
                    Text(comments)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// InfoRow 已在 ImagePreviewView 中定义

// MARK: - Preview

struct UserFeedbackHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = UserFeedbackManager()
        
        // 添加一些示例数据
        Task {
            let feedback1 = UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: true,
                rating: 5,
                comments: "识别很准确！"
            )
            
            let feedback2 = UserFeedback(
                recognitionResultId: UUID(),
                isCorrect: false,
                correctedName: "MacBook Pro",
                correctedCategory: .electronics,
                rating: 3,
                comments: "识别成了iPad，实际是MacBook"
            )
            
            await manager.submitFeedback(feedback1)
            await manager.submitFeedback(feedback2)
        }
        
        return UserFeedbackHistoryView(feedbackManager: manager)
    }
}