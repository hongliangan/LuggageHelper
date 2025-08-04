//
//  UserFeedbackView.swift
//  LuggageHelper
//
//  Created by Kiro on 2025/7/28.
//

import SwiftUI

/// 用户反馈界面组件
struct UserFeedbackView: View {
    
    // MARK: - Properties
    
    let recognitionResult: PhotoRecognitionResult
    @ObservedObject var feedbackManager: UserFeedbackManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var isCorrect: Bool = true
    @State private var correctedName: String = ""
    @State private var selectedCategory: ItemCategory = .other
    @State private var rating: Int = 3
    @State private var comments: String = ""
    @State private var showingCategoryPicker = false
    @State private var isSubmitting = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 识别结果展示
                    recognitionResultCard
                    
                    // 反馈表单
                    feedbackForm
                    
                    // 提交按钮
                    submitButton
                }
                .padding()
            }
            .navigationTitle("识别反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    // MARK: - View Components
    
    private var recognitionResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("识别结果")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recognitionResult.itemInfo.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(recognitionResult.itemInfo.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("置信度:")
                        Text("\(Int(recognitionResult.confidence * 100))%")
                            .fontWeight(.medium)
                            .foregroundColor(confidenceColor)
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                Text(recognitionResult.itemInfo.category.icon)
                    .font(.system(size: 40))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("您的反馈")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 正确性选择
            correctnessSection
            
            // 修正信息（如果不正确）
            if !isCorrect {
                correctionSection
            }
            
            // 评分
            ratingSection
            
            // 评论
            commentsSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var correctnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("识别结果是否正确？")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                Button(action: { isCorrect = true }) {
                    HStack {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCorrect ? .green : .gray)
                        Text("正确")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { isCorrect = false }) {
                    HStack {
                        Image(systemName: !isCorrect ? "xmark.circle.fill" : "circle")
                            .foregroundColor(!isCorrect ? .red : .gray)
                        Text("不正确")
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("请提供正确信息")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            // 修正名称
            VStack(alignment: .leading, spacing: 4) {
                Text("正确名称")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("请输入正确的物品名称", text: $correctedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // 修正类别
            VStack(alignment: .leading, spacing: 4) {
                Text("正确类别")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { showingCategoryPicker = true }) {
                    HStack {
                        Text(selectedCategory.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            categoryPickerSheet
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("整体满意度")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: { rating = star }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundColor(star <= rating ? .yellow : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                Text(ratingDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("其他建议（可选）")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextEditor(text: $comments)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private var submitButton: some View {
        Button(action: submitFeedback) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isSubmitting ? "提交中..." : "提交反馈")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSubmitting ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isSubmitting || (!isCorrect && correctedName.isEmpty))
    }
    
    private var categoryPickerSheet: some View {
        NavigationView {
            List(ItemCategory.allCases, id: \.self) { category in
                Button(action: {
                    selectedCategory = category
                    showingCategoryPicker = false
                }) {
                    HStack {
                        Text(category.icon)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text(category.displayName)
                                .foregroundColor(.primary)
                            Text(category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedCategory == category {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("选择类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingCategoryPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var confidenceColor: Color {
        switch recognitionResult.confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private var ratingDescription: String {
        switch rating {
        case 1:
            return "很不满意"
        case 2:
            return "不满意"
        case 3:
            return "一般"
        case 4:
            return "满意"
        case 5:
            return "非常满意"
        default:
            return ""
        }
    }
    
    // MARK: - Methods
    
    private func setupInitialValues() {
        correctedName = recognitionResult.itemInfo.name
        selectedCategory = recognitionResult.itemInfo.category
        
        // 根据置信度设置初始正确性
        isCorrect = recognitionResult.confidence > 0.7
    }
    
    private func submitFeedback() {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        
        Task {
            let feedback = UserFeedback(
                recognitionResultId: recognitionResult.id,
                isCorrect: isCorrect,
                correctedName: isCorrect ? nil : correctedName,
                correctedCategory: isCorrect ? nil : selectedCategory,
                rating: rating,
                comments: comments.isEmpty ? nil : comments
            )
            
            await feedbackManager.submitFeedback(feedback)
            
            // 如果有修正信息，创建学习数据
            if !isCorrect {
                // TODO: 需要从imageMetadata或其他地方获取图像标识符
                // await feedbackManager.createLearningData(
                //     imageHash: imageHash,
                //     originalResult: recognitionResult,
                //     userFeedback: feedback
                // )
            }
            
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}

// MARK: - Preview

struct UserFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleResult = PhotoRecognitionResult(
            itemInfo: ItemInfo(
                name: "iPhone 15",
                category: .electronics,
                weight: 171.0,
                volume: 100.0,
                confidence: 0.85
            ),
            confidence: 0.85,
            recognitionMethod: .cloudAPI,
            processingTime: 2.3,
            imageMetadata: ImageMetadata.mock
        )
        
        UserFeedbackView(
            recognitionResult: sampleResult,
            feedbackManager: UserFeedbackManager()
        )
    }
}